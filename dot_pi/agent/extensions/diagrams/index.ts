/**
 * diagrams: interactive Archify diagrams inside the conversation.
 *
 * - `diagram` tool: the agent passes Archify JSON; the extension runs `archify finalize`,
 *   screenshots the result with headless Chrome and shows the PNG inline (kitty/iTerm2 graphics).
 * - Live viewer: a loopback web page lists the session's diagrams and switches to each new one
 *   over SSE, so one browser tab next to pi always shows the latest interactive diagram.
 * - `/diagram auto|always|off` controls when the agent draws; `/diagrams` opens the viewer.
 *
 * Artifacts live in ~/.cache/pi-diagrams/<session-id>/ (never in the project repo).
 */

import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";
import { StringEnum } from "@earendil-works/pi-ai";
import { Container, Image, Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";
import { execFile } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { mkdir, readFile, rm, writeFile } from "node:fs/promises";
import http from "node:http";
import { homedir } from "node:os";
import { join } from "node:path";

const ARCHIFY_DIR = process.env.ARCHIFY_DIR ?? join(homedir(), ".agents/skills/archify");
const ARCHIFY_BIN = join(ARCHIFY_DIR, "bin/archify.mjs");
const CACHE_ROOT = process.env.PI_DIAGRAMS_DIR ?? join(homedir(), ".cache/pi-diagrams");
const TYPES = ["architecture", "workflow", "sequence", "dataflow", "lifecycle", "erd", "class", "tree", "timeline", "waterfall"] as const;
type Mode = "auto" | "always" | "off";

interface DiagramRecord {
	id: string;
	title: string;
	type: string;
	createdAt: string;
	html: string; // absolute path
	png?: string; // absolute path
}

interface ToolDetails {
	ok: boolean;
	diagram?: DiagramRecord;
	url?: string;
	failedStage?: string;
	diagnostics?: string[];
}

// ---------------------------------------------------------------- helpers

function run(cmd: string, args: string[], opts: { cwd?: string; timeout?: number; signal?: AbortSignal } = {}) {
	return new Promise<{ code: number; stdout: string; stderr: string }>((resolve) => {
		execFile(cmd, args, { ...opts, maxBuffer: 32 * 1024 * 1024 }, (err, stdout, stderr) => {
			const code = err ? (typeof (err as any).code === "number" ? (err as any).code : 1) : 0;
			resolve({ code, stdout: String(stdout), stderr: String(stderr) });
		});
	});
}

function slugify(s: string): string {
	return s.toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "").slice(0, 40) || "diagram";
}

function findChrome(): string | undefined {
	const candidates = [
		process.env.ARCHIFY_CHROME,
		"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
		"/Applications/Chromium.app/Contents/MacOS/Chromium",
		"/Applications/Brave Browser.app/Contents/MacOS/Brave Browser",
		"/usr/bin/google-chrome",
		"/usr/bin/chromium",
		"/usr/bin/chromium-browser",
	];
	return candidates.find((p) => p && existsSync(p));
}

async function screenshot(html: string, png: string, signal?: AbortSignal): Promise<boolean> {
	const chrome = findChrome();
	if (!chrome) return false;
	const res = await run(
		chrome,
		[
			"--headless=new",
			"--disable-gpu",
			"--hide-scrollbars",
			"--no-first-run",
			"--force-device-scale-factor=1",
			"--window-size=1400,860",
			"--virtual-time-budget=3000",
			`--screenshot=${png}`,
			`file://${html}`,
		],
		{ timeout: 30_000, signal },
	);
	return res.code === 0 && existsSync(png);
}

function openUrl(url: string) {
	const cmd = process.platform === "darwin" ? "open" : "xdg-open";
	execFile(cmd, [url], () => {});
}

// ---------------------------------------------------------------- viewer server

interface Store {
	sessionId: string;
	diagrams: DiagramRecord[];
}

interface Viewer {
	server: http.Server;
	port: number;
	clients: Set<http.ServerResponse>;
	store: Store;
}

const G = globalThis as unknown as { __piDiagramsViewer?: Viewer };

function broadcast(v: Viewer, event: string, data: unknown) {
	const payload = `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
	for (const c of v.clients) c.write(payload);
}

function publicList(store: Store) {
	return store.diagrams.map(({ id, title, type, createdAt, png }) => ({ id, title, type, createdAt, hasPng: !!png }));
}

async function ensureViewer(store: Store): Promise<Viewer> {
	const existing = G.__piDiagramsViewer;
	if (existing) {
		if (existing.store !== store) {
			existing.store = store;
			broadcast(existing, "reset", publicList(store));
		}
		return existing;
	}
	const clients = new Set<http.ServerResponse>();
	const viewer = { clients, store } as Viewer;
	const server = http.createServer((req, res) => {
		const url = new URL(req.url ?? "/", "http://localhost");
		const p = url.pathname;
		if (p === "/") {
			res.writeHead(200, { "content-type": "text/html; charset=utf-8", "cache-control": "no-store" });
			res.end(VIEWER_HTML);
		} else if (p === "/api/diagrams") {
			res.writeHead(200, { "content-type": "application/json", "cache-control": "no-store" });
			res.end(JSON.stringify(publicList(viewer.store)));
		} else if (p === "/events") {
			res.writeHead(200, { "content-type": "text/event-stream", "cache-control": "no-store", connection: "keep-alive" });
			res.write(": hi\n\n");
			clients.add(res);
			const ping = setInterval(() => res.write(": ping\n\n"), 25_000);
			req.on("close", () => {
				clearInterval(ping);
				clients.delete(res);
			});
		} else {
			const m = p.match(/^\/d\/([\w-]+)\/(diagram\.html|preview\.png)$/);
			const rec = m && viewer.store.diagrams.find((d) => d.id === m[1]);
			const file = rec && (m![2] === "preview.png" ? rec.png : rec.html);
			if (!file || !existsSync(file)) {
				res.writeHead(404).end("not found");
				return;
			}
			res.writeHead(200, {
				"content-type": file.endsWith(".png") ? "image/png" : "text/html; charset=utf-8",
				"cache-control": "no-store",
			});
			res.end(readFileSync(file));
		}
	});
	await new Promise<void>((resolve) => server.listen(0, "127.0.0.1", resolve));
	server.unref();
	viewer.server = server;
	viewer.port = (server.address() as { port: number }).port;
	G.__piDiagramsViewer = viewer;
	return viewer;
}

function closeViewer() {
	const v = G.__piDiagramsViewer;
	if (!v) return;
	for (const c of v.clients) c.end();
	v.server.close();
	G.__piDiagramsViewer = undefined;
}

// ---------------------------------------------------------------- extension

export default function (pi: ExtensionAPI) {
	let store: Store = { sessionId: "none", diagrams: [] };
	let mode: Mode = "auto";

	const sessionDir = () => join(CACHE_ROOT, store.sessionId);
	const manifestPath = () => join(sessionDir(), "manifest.json");

	async function loadStore(ctx: ExtensionContext) {
		const sessionId = ctx.sessionManager.getSessionId();
		store = { sessionId, diagrams: [] };
		try {
			store.diagrams = JSON.parse(await readFile(manifestPath(), "utf8"));
		} catch {}
		if (G.__piDiagramsViewer) await ensureViewer(store);
	}

	function applyMode(ctx: ExtensionContext) {
		const active = new Set(pi.getActiveTools());
		if (mode === "off") active.delete("diagram");
		else active.add("diagram");
		pi.setActiveTools([...active]);
		ctx.ui.setStatus("diagram", mode === "auto" ? undefined : `diagrams: ${mode}`);
	}

	pi.on("session_start", async (_event, ctx) => {
		await loadStore(ctx);
		mode = "auto";
		for (const e of ctx.sessionManager.getBranch()) {
			if (e.type === "custom" && (e as any).customType === "diagram-mode") mode = (e as any).data?.mode ?? mode;
		}
		applyMode(ctx);
	});

	pi.on("session_shutdown", async (event) => {
		// Keep the server (and the open browser tab) across /new, /resume and /fork.
		if (event.reason === "quit" || event.reason === "reload") closeViewer();
	});

	pi.on("before_agent_start", async (event) => {
		if (mode !== "always") return;
		event.systemPromptOptions.promptGuidelines.push(
			"Diagram mode is 'always': accompany every substantive answer about a system, process, codebase or concept with a diagram tool call. Skip it only for trivial replies.",
		);
	});

	async function viewerUrl(id?: string) {
		const v = await ensureViewer(store);
		return `http://127.0.0.1:${v.port}/${id ? `#${id}` : ""}`;
	}

	pi.registerTool({
		name: "diagram",
		label: "Diagram",
		description:
			"Render an interactive Archify diagram from typed JSON and show it to the user: an inline preview image in the terminal plus a live browser viewer. " +
			"`spec` is a complete Archify candidate for `type` (see the archify skill schemas). meta.output is set automatically. " +
			"Returns validation diagnostics on failure; fix the spec and call again.",
		promptSnippet: "Show the user an interactive diagram (architecture, workflow, sequence, dataflow, lifecycle, erd, class, tree, timeline, waterfall) alongside an answer",
		promptGuidelines: [
			"Use diagram when a picture of structure, flow, call sequence, states, data model, hierarchy or timing would help the user understand a system or concept; skip diagram for simple factual answers.",
			`Before the first diagram call in a session, read ${ARCHIFY_DIR}/references/authoring-defaults.md and, for the chosen type, the schema and example listed in the Type router of ${ARCHIFY_DIR}/SKILL.md (plus schemas/common.schema.json for non-architecture types). Base repository diagrams on code you actually traced.`,
			"Deliver Archify diagrams through the diagram tool, not by running archify finalize via bash; the diagram tool already displays the result, so do not paste file paths or links unless asked.",
			"When diagram fails, fix the spec from its diagnostics and call diagram again (at most 3 attempts); if it still fails, answer in text.",
			"After diagram succeeds, still answer the question in prose: give the key takeaways and anything the diagram omits, without narrating every node.",
		],
		parameters: Type.Object({
			type: StringEnum(TYPES),
			title: Type.String({ description: "Short human title for the viewer gallery" }),
			spec: Type.Object({}, { additionalProperties: true, description: "Complete Archify JSON candidate for this type" }),
			quality: Type.Optional(StringEnum(["showcase", "standard"] as const, { description: "Default showcase; standard for dense ERDs" })),
		}),
		executionMode: "sequential",
		prepareArguments(args: any) {
			if (args && typeof args.spec === "string") {
				try {
					return { ...args, spec: JSON.parse(args.spec) };
				} catch {}
			}
			return args;
		},

		async execute(_id, params, signal, onUpdate, ctx) {
			const quality = String(params.quality ?? "showcase");
			const stamp = new Date().toISOString().replace(/[-:]/g, "").replace(/\..+/, "").replace("T", "-");
			const id = `${stamp}-${String(params.type)}-${slugify(params.title)}`;
			const dir = join(sessionDir(), id);
			await mkdir(dir, { recursive: true });

			const spec: any = structuredClone(params.spec);
			spec.meta = { ...(spec.meta ?? {}), output: "diagram.html", quality_profile: quality };
			await writeFile(join(dir, "candidate.json"), JSON.stringify(spec, null, 2));

			onUpdate?.({ content: [{ type: "text", text: "Validating and rendering…" }], details: { ok: false } });
			const res = await run(
				process.execPath,
				[ARCHIFY_BIN, "finalize", String(params.type), "candidate.json", "diagram.html", "--quality", quality, "--repo-root", ctx.cwd, "--json"],
				{ cwd: dir, timeout: 180_000, signal },
			);

			let receipt: any;
			try {
				receipt = JSON.parse(res.stdout);
			} catch {}

			if (!receipt?.ok) {
				await rm(dir, { recursive: true, force: true });
				const diags: string[] = (receipt?.diagnostics ?? []).slice(0, 25).map((d: any) => {
					const where = d.subject?.path ?? d.subject?.id ?? "";
					const fixes = d.supportedFixes?.length ? ` | fixes: ${d.supportedFixes.join("; ")}` : "";
					return `[${d.code}] ${where ? where + ": " : ""}${d.message}${fixes}`;
				});
				const stage = receipt?.failedStage ?? "run";
				const raw = receipt ? "" : `\n${(res.stderr || res.stdout).slice(0, 4000)}`;
				return {
					content: [
						{
							type: "text",
							text: `Archify finalize failed at stage "${stage}"${receipt?.diagnosticSummary?.truncated ? " (diagnostics truncated)" : ""}:\n${diags.join("\n")}${raw}`,
						},
					],
					details: { ok: false, failedStage: stage, diagnostics: diags } satisfies ToolDetails,
					isError: true,
				};
			}

			onUpdate?.({ content: [{ type: "text", text: "Capturing preview…" }], details: { ok: false } });
			const html = join(dir, "diagram.html");
			const pngPath = join(dir, "preview.png");
			const hasPng = await screenshot(html, pngPath, signal);

			const rec: DiagramRecord = {
				id,
				title: params.title,
				type: String(params.type),
				createdAt: new Date().toISOString(),
				html,
				png: hasPng ? pngPath : undefined,
			};
			store.diagrams.push(rec);
			await writeFile(manifestPath(), JSON.stringify(store.diagrams, null, 2));

			const v = await ensureViewer(store);
			const url = `http://127.0.0.1:${v.port}/#${id}`;
			if (v.clients.size === 0) openUrl(url);
			else broadcast(v, "diagram", publicList(store));

			const crossings = receipt.visualReviewRecommendation?.signals?.resolvedCrossovers;
			return {
				content: [
					{
						type: "text",
						text:
							`Diagram "${params.title}" rendered (automated checks passed) and is now visible to the user inline and in the live viewer (${url}). ` +
							`HTML: ${html}` +
							(crossings ? `\nLayout note: the receipt reports resolvable edge crossings; consider repositioning nodes if the user asks for a cleaner layout.` : ""),
					},
				],
				details: { ok: true, diagram: rec, url } satisfies ToolDetails,
			};
		},

		renderCall(args, theme) {
			let s = theme.fg("toolTitle", theme.bold("diagram "));
			if (args?.type) s += theme.fg("accent", String(args.type)) + " ";
			if (args?.title) s += theme.fg("muted", args.title);
			return new Text(s, 0, 0);
		},

		renderResult(result, { expanded, isPartial }, theme, context) {
			const d = result.details as ToolDetails | undefined;
			if (isPartial) {
				const msg = (result.content?.[0] as any)?.text ?? "Rendering…";
				return new Text(theme.fg("warning", msg), 0, 0);
			}
			if (!d?.ok || !d.diagram) {
				const lines = [theme.fg("error", `✗ archify failed at ${d?.failedStage ?? "?"}`)];
				const diags = d?.diagnostics ?? [];
				for (const l of expanded ? diags : diags.slice(0, 2)) lines.push(theme.fg("dim", "  " + l));
				if (!expanded && diags.length > 2) lines.push(theme.fg("dim", `  … ${diags.length - 2} more`));
				return new Text(lines.join("\n"), 0, 0);
			}
			const rec = d.diagram;
			const link = (url: string, label: string) => `\x1b]8;;${url}\x1b\\${label}\x1b]8;;\x1b\\`;
			const header =
				theme.fg("success", "✓ ") +
				theme.bold(rec.title) +
				theme.fg("dim", "  ") +
				theme.fg("accent", link(d.url ?? `file://${rec.html}`, "open live viewer")) +
				theme.fg("dim", " · ") +
				theme.fg("accent", link(`file://${rec.html}`, "html")) +
				theme.fg("dim", " · /diagrams");
			const box = new Container();
			box.addChild(new Text(header, 0, 0));
			if (context.showImages && rec.png && existsSync(rec.png)) {
				const state = context.state as { png?: string };
				state.png ??= readFileSync(rec.png).toString("base64");
				box.addChild(
					new Image(state.png, "image/png", { fallbackColor: (s) => theme.fg("dim", s) }, {
						maxWidthCells: expanded ? 160 : 110,
						maxHeightCells: expanded ? 45 : 24,
						filename: "preview.png",
					}),
				);
			}
			return box;
		},
	});

	pi.registerCommand("diagram", {
		description: "Diagram mode: auto (agent decides), always, off",
		getArgumentCompletions: (prefix: string) =>
			["auto", "always", "off"].filter((m) => m.startsWith(prefix)).map((m) => ({ value: m, label: m })),
		handler: async (args, ctx) => {
			const next = args.trim() as Mode;
			if (!next) {
				ctx.ui.notify(`Diagram mode: ${mode} (use /diagram auto|always|off)`, "info");
				return;
			}
			if (!["auto", "always", "off"].includes(next)) {
				ctx.ui.notify("Usage: /diagram auto|always|off", "error");
				return;
			}
			mode = next;
			pi.appendEntry("diagram-mode", { mode });
			applyMode(ctx);
			ctx.ui.notify(`Diagram mode: ${mode}`, "info");
		},
	});

	pi.registerCommand("diagrams", {
		description: "Open the live diagram viewer, or pick one of this session's diagrams",
		handler: async (_args, ctx) => {
			if (store.diagrams.length === 0) {
				openUrl(await viewerUrl());
				ctx.ui.notify("No diagrams in this session yet; viewer opened and will update live.", "info");
				return;
			}
			const items = ["Open live viewer (latest)", ...[...store.diagrams].reverse().map((d) => `${d.title}  [${d.type}]`)];
			const choice = await ctx.ui.select("Diagrams", items);
			if (choice === undefined) return;
			const idx = items.indexOf(choice);
			const rec = idx > 0 ? [...store.diagrams].reverse()[idx - 1] : undefined;
			openUrl(await viewerUrl(rec?.id));
		},
	});
}

// ---------------------------------------------------------------- viewer page

const VIEWER_HTML = /* html */ `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>pi diagrams</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<style>
  :root { color-scheme: dark; --bg:#0b0f19; --panel:#111827; --line:#1f2937; --fg:#e5e7eb; --dim:#9ca3af; --acc:#22d3ee; }
  * { box-sizing: border-box; }
  body { margin:0; height:100vh; display:flex; background:var(--bg); color:var(--fg); font:13px/1.4 ui-sans-serif,system-ui,-apple-system,sans-serif; }
  aside { width:260px; flex:none; border-right:1px solid var(--line); display:flex; flex-direction:column; background:var(--panel); transition: margin .15s; }
  body.collapsed aside { margin-left:-260px; }
  header { padding:12px 14px; border-bottom:1px solid var(--line); display:flex; align-items:center; gap:8px; }
  header b { flex:1; } .dot { width:8px; height:8px; border-radius:50%; background:#ef4444; } .dot.on { background:#22c55e; }
  label { color:var(--dim); font-size:12px; display:flex; gap:4px; align-items:center; cursor:pointer; }
  ul { list-style:none; margin:0; padding:6px; overflow:auto; flex:1; }
  li { padding:8px 10px; border-radius:8px; cursor:pointer; margin-bottom:4px; border:1px solid transparent; }
  li:hover { background:#1f2937; } li.sel { border-color:var(--acc); background:#0e2a33; }
  li small { display:block; color:var(--dim); font-size:11px; }
  li img { width:100%; border-radius:4px; margin-top:6px; opacity:.85; }
  main { flex:1; display:flex; flex-direction:column; min-width:0; }
  .bar { padding:8px 12px; border-bottom:1px solid var(--line); display:flex; gap:12px; align-items:center; }
  .bar span { flex:1; font-weight:600; overflow:hidden; text-overflow:ellipsis; white-space:nowrap; }
  .bar a, .bar button { color:var(--acc); background:none; border:0; cursor:pointer; font:inherit; text-decoration:none; }
  iframe { flex:1; border:0; width:100%; background:var(--bg); }
  .empty { margin:auto; color:var(--dim); text-align:center; }
</style></head>
<body>
<aside>
  <header><span class="dot" id="dot" title="connection to pi"></span><b>pi diagrams</b>
    <label><input type="checkbox" id="follow" checked>follow</label></header>
  <ul id="list"></ul>
</aside>
<main>
  <div class="bar"><button id="toggle" title="toggle sidebar">☰</button><span id="title">Waiting for diagrams…</span>
    <a id="newtab" target="_blank" hidden>open in tab ↗</a></div>
  <div class="empty" id="empty">Ask pi something; diagrams appear here as the agent draws them.</div>
  <iframe id="frame" hidden></iframe>
</main>
<script>
  let items = [], current = null;
  const $ = (id) => document.getElementById(id);
  $("toggle").onclick = () => document.body.classList.toggle("collapsed");
  function render() {
    $("list").innerHTML = "";
    [...items].reverse().forEach((d) => {
      const li = document.createElement("li");
      if (d.id === current) li.className = "sel";
      li.innerHTML = "<div></div><small></small>" + (d.hasPng ? '<img loading="lazy">' : "");
      li.firstChild.textContent = d.title;
      li.children[1].textContent = d.type + " · " + new Date(d.createdAt).toLocaleTimeString();
      if (d.hasPng) li.querySelector("img").src = "/d/" + d.id + "/preview.png";
      li.onclick = () => { $("follow").checked = d.id === items.at(-1)?.id; show(d.id); };
      $("list").appendChild(li);
    });
  }
  function show(id) {
    const d = items.find((x) => x.id === id) || items.at(-1);
    if (!d) { current = null; $("frame").hidden = true; $("empty").hidden = false; $("title").textContent = "Waiting for diagrams…"; $("newtab").hidden = true; render(); return; }
    current = d.id; history.replaceState(null, "", "#" + d.id);
    const src = "/d/" + d.id + "/diagram.html";
    if ($("frame").getAttribute("src") !== src) $("frame").src = src;
    $("frame").hidden = false; $("empty").hidden = true;
    $("title").textContent = d.title + "  ·  " + d.type; document.title = d.title + " · pi diagrams";
    $("newtab").href = src; $("newtab").hidden = false;
    render();
  }
  async function load(target) { items = await (await fetch("/api/diagrams")).json(); show(target); }
  load(location.hash.slice(1));
  function connect() {
    const es = new EventSource("/events");
    es.onopen = () => $("dot").classList.add("on");
    es.onerror = () => $("dot").classList.remove("on");
    es.addEventListener("diagram", (e) => { items = JSON.parse(e.data); $("follow").checked ? show(items.at(-1).id) : render(); });
    es.addEventListener("reset", (e) => { items = JSON.parse(e.data); show(); });
  }
  connect();
</script>
</body></html>`;
