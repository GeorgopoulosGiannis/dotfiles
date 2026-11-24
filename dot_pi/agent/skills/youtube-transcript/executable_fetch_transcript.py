#!/usr/bin/env python3
"""Fetch a YouTube video's title and transcript.

Strategy (to avoid HTTP 429 from YouTube's /api/timedtext endpoint):
  1. youtube-transcript-api (innertube-based; much less rate-limited).
     If not importable, the script re-execs itself via `uv run --with ...`.
     Title comes from the lightweight oEmbed endpoint.
  2. Fallback: yt-dlp metadata (single call) + direct download of the json3
     caption URL with exponential backoff on 429.

Prefers manual English captions, falls back to auto-generated.
"""
import json
import os
import re
import shutil
import ssl
import subprocess
import sys
import time
import urllib.parse
import urllib.request

LANGS = ["en", "en-US", "en-GB"]
UA = {"User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"}


def log(msg):
    print(msg, file=sys.stderr)


def video_id(url):
    m = re.search(r"(?:v=|youtu\.be/|shorts/|embed/|live/)([A-Za-z0-9_-]{11})", url)
    if m:
        return m.group(1)
    if re.fullmatch(r"[A-Za-z0-9_-]{11}", url):
        return url
    return None


def _ssl_ctx():
    try:
        import certifi  # noqa
        return ssl.create_default_context(cafile=certifi.where())
    except Exception:
        return ssl.create_default_context()


def http_get(url, retries=4, timeout=20):
    """GET with exponential backoff on 429/5xx."""
    delay = 2
    for attempt in range(retries + 1):
        try:
            req = urllib.request.Request(url, headers=UA)
            with urllib.request.urlopen(req, timeout=timeout, context=_ssl_ctx()) as r:
                return r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503) and attempt < retries:
                log(f"HTTP {e.code}, retrying in {delay}s...")
                time.sleep(delay)
                delay *= 2
                continue
            raise


def oembed_title(vid):
    try:
        u = "https://www.youtube.com/oembed?format=json&url=" + urllib.parse.quote(
            f"https://www.youtube.com/watch?v={vid}"
        )
        return json.loads(http_get(u, retries=1)).get("title")
    except Exception:
        return None


# ---------- Strategy 1: youtube-transcript-api ----------

def via_transcript_api(vid):
    from youtube_transcript_api import YouTubeTranscriptApi

    api = YouTubeTranscriptApi()
    tlist = api.list(vid)
    try:
        t = tlist.find_manually_created_transcript(LANGS)
    except Exception:
        try:
            t = tlist.find_generated_transcript(LANGS)
        except Exception:
            # any en* variant
            t = next((x for x in tlist if x.language_code.startswith("en")), None)
            if t is None:
                raise RuntimeError("No English transcript available")
    log(f"Using {'auto' if t.is_generated else 'manual'} captions ({t.language_code}) via youtube-transcript-api")
    snippets = t.fetch()
    return " ".join(s.text.replace("\n", " ").strip() for s in snippets if s.text.strip())


# ---------- Strategy 2: yt-dlp (single pass) ----------

def pick_english_track(info):
    subs = info.get("subtitles") or {}
    auto = info.get("automatic_captions") or {}
    order = (
        [(l, subs) for l in LANGS]
        + [(l, subs) for l in subs if l.startswith("en")]
        + [(l, auto) for l in LANGS]
        + [(l, auto) for l in auto if l.startswith("en")]
    )
    for lang, src in order:
        for fmt in src.get(lang) or []:
            if fmt.get("ext") == "json3":
                return lang, src is auto, fmt["url"]
    return None


def via_ytdlp(url):
    if not shutil.which("yt-dlp"):
        raise RuntimeError("yt-dlp not on PATH")
    res = subprocess.run(
        ["yt-dlp", "--dump-json", "--no-warnings", "--skip-download", url],
        capture_output=True, text=True,
    )
    if res.returncode != 0:
        raise RuntimeError(f"yt-dlp metadata failed: {res.stderr.strip()}")
    info = json.loads(res.stdout)
    pick = pick_english_track(info)
    if not pick:
        raise RuntimeError("No English subtitles found")
    lang, is_auto, sub_url = pick
    log(f"Downloading {'auto ' if is_auto else ''}captions ({lang}) via yt-dlp URL...")
    data = json.loads(http_get(sub_url, retries=5))
    parts = []
    for ev in data.get("events", []):
        for seg in ev.get("segs") or []:
            txt = seg.get("utf8", "")
            if txt.strip():
                parts.append(txt.strip())
    return info.get("title"), " ".join(parts)


def main():
    if len(sys.argv) < 2:
        log("Usage: fetch_transcript.py <youtube_url>")
        sys.exit(1)
    url = sys.argv[1]
    vid = video_id(url)
    if not vid:
        log(f"Could not parse video id from: {url}")
        sys.exit(1)

    # Ensure youtube-transcript-api is available; re-exec under uv if not.
    try:
        import youtube_transcript_api  # noqa
        have_api = True
    except ImportError:
        have_api = False
        if not os.environ.get("_YT_TRANSCRIPT_REEXEC") and shutil.which("uv"):
            os.environ["_YT_TRANSCRIPT_REEXEC"] = "1"
            os.execvp("uv", ["uv", "run", "--quiet", "--with", "youtube-transcript-api",
                             "--with", "certifi", "python3", os.path.abspath(__file__), url])

    errors = []
    title, transcript = None, None

    if have_api:
        try:
            transcript = via_transcript_api(vid)
            title = oembed_title(vid)
        except Exception as e:
            errors.append(f"youtube-transcript-api: {e}")
            log(f"youtube-transcript-api failed ({type(e).__name__}); falling back to yt-dlp")

    if transcript is None:
        try:
            title, transcript = via_ytdlp(url)
        except Exception as e:
            errors.append(f"yt-dlp: {e}")

    if not transcript:
        log("Failed to fetch transcript:\n  " + "\n  ".join(errors))
        sys.exit(1)

    print(json.dumps({"title": title or "Unknown_Title", "transcript": transcript}, indent=2))


if __name__ == "__main__":
    main()
