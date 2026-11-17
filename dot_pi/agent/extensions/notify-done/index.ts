/**
 * notify-done: macOS notification + tmux bell when a pi agent finishes.
 *
 * - Fires on `agent_settled` (after retries/compaction/queued follow-ups are done).
 * - Title includes tmux session:window so you know which agent finished.
 * - Rings the terminal bell -> tmux flags the window in the status bar.
 * - Skips the popup if you're already looking at this pane.
 * - pi-interactive-subagents aware: while sub-agents are still running, an
 *   orchestrator turn ending is NOT "done" (no popup/bell, timer keeps running).
 *   If a sub-agent asked a question the orchestrator didn't answer itself and
 *   it handed control back to you, that's a "waiting" notification instead.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile, spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { basename, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const QUEUE_SH = join(dirname(fileURLToPath(import.meta.url)), "queue.sh");

function run(cmd: string, args: string[]): Promise<string> {
	return new Promise((resolve) => {
		execFile(cmd, args, { timeout: 2000 }, (err, stdout) => resolve(err ? "" : stdout.trim()));
	});
}

// ---- Config: change these (or set env vars) and /reload ----
// Sounds: Basso Blow Bottle Frog Funk Glass Hero Morse Ping Pop Purr Sosumi Submarine Tink
// (or any .aiff you drop into ~/Library/Sounds)
const SOUND = process.env.PI_NOTIFY_SOUND ?? "Funk"; // agent finished
const WAITING_SOUND = process.env.PI_NOTIFY_WAITING_SOUND ?? "Sosumi"; // blocked on you (bash-guard etc.)
// Image shown on the right of the notification (path or URL). "" = none.
const IMAGE = process.env.PI_NOTIFY_IMAGE ?? "";
// -------------------------------------------------------------

const TERMINAL_NOTIFIER = ["/opt/homebrew/bin/terminal-notifier", "/usr/local/bin/terminal-notifier"].find((p) => existsSync(p));
// Bundle id of the terminal app hosting tmux; used to focus it on click and to detect whether it's frontmost.
// macOS GUI apps export __CFBundleIdentifier to their children, so this is usually auto-detected;
// otherwise it falls back to Ghostty.
const TERMINAL_BUNDLE = process.env.__CFBundleIdentifier || "com.mitchellh.ghostty";

function which(bin: string): string {
	for (const dir of (process.env.PATH ?? "").split(":")) {
		const p = `${dir}/${bin}`;
		if (existsSync(p)) return p;
	}
	return bin;
}

const shq = (s: string) => `'${s.replace(/'/g, `'\\''`)}'`;

/** Shell command that, when the notification is clicked, jumps the most recent tmux client to this pane. */
function tmuxJumpCommand(pane: string): string {
	const tmux = which("tmux");
	const socket = (process.env.TMUX ?? "").split(",")[0];
	const t = `${shq(tmux)}${socket ? ` -S ${shq(socket)}` : ""}`;
	const client = `$(${t} list-clients -F '#{client_activity} #{client_name}' | sort -rn | head -1 | cut -d' ' -f2)`;
	return `c=${client}; ${t} switch-client -c "$c" -t ${shq(pane)} && ${t} select-window -t ${shq(pane)} && ${t} select-pane -t ${shq(pane)}`;
}

/** Is the terminal app hosting tmux the frontmost macOS app? (true on non-macOS / if unknown) */
async function terminalFrontmost(): Promise<boolean> {
	if (process.platform !== "darwin") return true;
	const asn = await run("lsappinfo", ["front"]);
	if (!asn) return false; // unknown -> prefer notifying over silently skipping
	const info = await run("lsappinfo", ["info", "-only", "bundleid", asn]);
	return info.includes(`"${TERMINAL_BUNDLE}"`);
}

async function tmuxInfo(): Promise<{ label: string; focused: boolean } | null> {
	const pane = process.env.TMUX_PANE;
	if (!process.env.TMUX || !pane) return null;
	const out = await run("tmux", [
		"display-message", "-p", "-t", pane,
		"#{session_name}\t#{window_index}:#{window_name}\t#{window_active}\t#{pane_active}\t#{pane_mode}",
	]);
	if (!out) return null;
	const [session, win, winActive, paneActive, paneMode] = out.split("\t");
	// choose-tree (prefix w/s), choose-client, choose-buffer cover the pane: you're browsing, not watching pi.
	const covered = /^(tree|client|buffer)-mode$/.test(paneMode ?? "");
	const clients = (await run("tmux", ["list-clients", "-F", "#{client_session}"])).split("\n");
	// Only "focused" if tmux shows this pane AND the terminal app is in front;
	// otherwise you're in another app (browser, Slack…) and would miss the bell.
	const focused =
		winActive === "1" && paneActive === "1" && !covered && clients.includes(session) && (await terminalFrontmost());
	return { label: `${session} › ${win}`, focused };
}

const esc = (s: string) => s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');

function lastAssistantText(messages: any[] | undefined): string {
	for (const m of [...(messages ?? [])].reverse()) {
		if (m?.role !== "assistant") continue;
		const c = m.content;
		const text = typeof c === "string" ? c : Array.isArray(c) ? c.filter((p: any) => p.type === "text").map((p: any) => p.text).join(" ") : "";
		if (text.trim()) return text.replace(/\s+/g, " ").trim().slice(0, 140);
	}
	return "";
}

type Notice = { title: string; subtitle: string; body: string; icon: string; sound: string };

/** Bell + (if this pane isn't focused) macOS notification + tmux status message. */
async function notify(n: Notice): Promise<void> {
	const { title, subtitle, body, icon, sound } = n;
	const osascript = () =>
		run("osascript", [
			"-e",
			`display notification "${esc(body)}" with title "${esc(title)}" subtitle "${esc(subtitle)}" sound name "${esc(sound)}"`,
		]);

	if (TERMINAL_NOTIFIER) {
		const args = [
			"-title", title,
			"-subtitle", subtitle,
			"-message", body,
			"-sound", sound,
			"-group", `pi-${process.env.TMUX_PANE ?? process.pid}`, // replaces stale notif from same pane
			"-activate", TERMINAL_BUNDLE,
		];
		if (IMAGE) args.push("-contentImage", IMAGE);
		if (process.env.TMUX_PANE) args.push("-execute", tmuxJumpCommand(process.env.TMUX_PANE));
		// Blocks until clicked/dismissed, so run it detached with no timeout.
		// If notifications are disabled for it, it prints a warning and exits -> fall back.
		const child = spawn(TERMINAL_NOTIFIER, args, { detached: true, stdio: ["ignore", "pipe", "pipe"] });
		let out = "";
		child.stdout?.on("data", (d) => (out += d));
		child.stderr?.on("data", (d) => (out += d));
		child.on("error", osascript);
		child.on("exit", () => {
			if (/turned off|not allowed|denied/i.test(out)) osascript();
		});
		(child.stdout as any)?.unref?.();
		(child.stderr as any)?.unref?.();
		child.unref();
	} else if (process.platform === "darwin") {
		osascript();
	}
	if (process.env.TMUX) {
		run("tmux", ["display-message", "-d", "4000", `${icon} ${title}`]);
	}
}

// ---- Jump queue (read by queue.sh / tmux `prefix N`, `prefix Q`) ----
type Queue = "@pi_waiting" | "@pi_done";

async function queueRemove(pane: string, queues: Queue[] = ["@pi_waiting", "@pi_done"]): Promise<void> {
	for (const q of queues) {
		const list = (await run("tmux", ["show", "-gqv", q])).split(/\s+/).filter(Boolean);
		if (!list.includes(pane)) continue;
		await run("tmux", ["set", "-g", q, list.filter((p) => p !== pane).join(" ")]);
	}
}

async function queueAdd(q: Queue, pane: string, meta: { task: string; note: string }): Promise<void> {
	await queueRemove(pane);
	// Per-pane metadata shown by `queue.sh list|menu` and /queue.
	await run("tmux", ["set", "-p", "-t", pane, "@pi_q_since", String(Math.floor(Date.now() / 1000))]);
	await run("tmux", ["set", "-p", "-t", pane, "@pi_q_task", meta.task]);
	await run("tmux", ["set", "-p", "-t", pane, "@pi_q_note", oneLine(meta.note, 100)]);
	const list = (await run("tmux", ["show", "-gqv", q])).split(/\s+/).filter(Boolean);
	await run("tmux", ["set", "-g", q, [...list, pane].join(" ")]);
}

const PANE = process.env.TMUX ? process.env.TMUX_PANE : undefined;

// ---- pi-interactive-subagents integration ----
// That extension exposes a live count of running sub-agents via a process-global symbol.
const RUNNING_SUBAGENTS_KEY = Symbol.for("pi-subagents/running-children-count");
function runningSubagents(): number {
	try {
		const fn = (globalThis as any)[RUNNING_SUBAGENTS_KEY];
		return typeof fn === "function" ? Number(fn()) || 0 : 0;
	} catch {
		return 0;
	}
}

const oneLine = (s: string, max: number) => {
	const t = s.replace(/\s+/g, " ").trim();
	return t.length > max ? `${t.slice(0, max - 1)}…` : t;
};

function ago(s: number): string {
	if (s < 60) return `${s}s`;
	if (s < 3600) return `${Math.floor(s / 60)}m`;
	if (s < 86400) return `${Math.floor(s / 3600)}h`;
	return `${Math.floor(s / 86400)}d`;
}

export default function (pi: ExtensionAPI) {
	let lastMessages: any[] | undefined;
	let startedAt = 0;
	let task = "";
	let cwd = process.cwd();
	// Sub-agent questions (name -> question) not yet answered via subagent_message.
	const pendingQuestions = new Map<string, string>();

	async function notifyWaiting(what: string, message: string): Promise<void> {
		const tmux = await tmuxInfo();
		process.stdout.write("\x07");
		if (tmux?.focused) return;

		if (PANE) await queueAdd("@pi_waiting", PANE, { task, note: `${what}: ${message}` });
		const where = tmux?.label ?? basename(cwd);
		await notify({
			title: `pi waiting — ${where}`,
			subtitle: task ? `${what} · "${task}"` : what,
			body: oneLine(message || "Needs your attention", 140),
			icon: "⏳",
			sound: WAITING_SOUND,
		});
	}

	// Track sub-agent questions / results delivered into this (orchestrator) session.
	pi.on("message_end", async (event) => {
		const m: any = (event as any).message;
		if (m?.role !== "custom") return;
		const name = m.details?.name;
		if (!name) return;
		if (m.customType === "subagent_question") pendingQuestions.set(String(name), String(m.details?.question ?? ""));
		else if (m.customType === "subagent_result") pendingQuestions.delete(String(name));
	});

	// Orchestrator replied to a sub-agent -> that question is answered.
	pi.on("tool_call", async (event) => {
		const e: any = event;
		if (e.toolName === "subagent_message" && e.input?.name) pendingQuestions.delete(String(e.input.name));
	});

	// Remember the prompt that started the task (ignore steering / queued follow-ups mid-run).
	pi.on("input", async (event) => {
		if (PANE) queueRemove(PANE); // you're interacting here -> no longer needs you
		if (event.streamingBehavior) return;
		const text = oneLine(event.text ?? "", 60);
		if (text) task = text;
	});

	pi.on("agent_start", async (_event, ctx) => {
		cwd = ctx.cwd;
		if (!startedAt) startedAt = Date.now();
	});

	pi.on("agent_end", async (event) => {
		lastMessages = (event as any).messages;
	});

	pi.on("agent_settled", async (event, ctx) => {
		const aborted = Boolean((event as any).aborted);
		const running = runningSubagents();

		if (running > 0 && !aborted) {
			// Orchestrator paused but sub-agents are still working -> not done.
			if (pendingQuestions.size > 0) {
				// It ended its turn without answering a sub-agent's question -> it's on you.
				const [name, q] = [...pendingQuestions.entries()][0];
				const body = lastAssistantText(lastMessages) || q;
				await notifyWaiting(`subagent "${name}" question`, body);
			} else if (process.env.TMUX) {
				run("tmux", ["display-message", "-d", "2500", `⏳ pi: ${running} subagent(s) still running`]);
			}
			return; // keep startedAt so the final "done" reports total time
		}

		const secs = Math.round((Date.now() - startedAt) / 1000);
		startedAt = 0;

		const tmux = await tmuxInfo();
		// Bell: tmux marks the window (status bar) even if we skip the popup.
		process.stdout.write("\x07");
		if (tmux?.focused) return;

		const body = lastAssistantText(lastMessages) || "Ready for input";
		if (PANE) await queueAdd("@pi_done", PANE, { task, note: body });
		const where = tmux?.label ?? basename(ctx.cwd);
		await notify({
			title: aborted ? `pi aborted — ${where}` : `pi done — ${where}`,
			subtitle: task ? `"${task}" · ${secs}s` : `${basename(ctx.cwd)} · ${secs}s`,
			body,
			icon: "✅",
			sound: SOUND,
		});
	});

	// A prompt was answered (e.g. bash-guard Run/Abort) -> no longer blocked on you.
	pi.on("ui_prompt_end", async () => {
		if (PANE) await queueRemove(PANE, ["@pi_waiting"]);
	});

	pi.on("session_shutdown", async () => {
		if (PANE) await queueRemove(PANE);
	});

	// /queue: ordered list of panes needing attention (waiting first, then done; oldest first).
	pi.registerCommand("queue", {
		description: "Show pending pi notifications in order and jump to one",
		handler: async (_args, ctx) => {
			if (!process.env.TMUX) return ctx.ui.notify("queue: not running inside tmux", "warning");
			const out = await run("sh", [QUEUE_SH, "list"]);
			const items = out
				.split("\n")
				.filter(Boolean)
				.map((l) => {
					const [kind, pane, where, t, age, note] = l.split("\t");
					return { kind, pane, where, task: t, age: Number(age) || 0, note };
				})
				.filter((i) => i.pane !== PANE);
			if (!items.length) return ctx.ui.notify("queue: nothing waiting", "info");

			const labels = items.map((i, n) => {
				const icon = i.kind === "waiting" ? "⏳" : "✅";
				const t = i.task ? `  "${i.task}"` : "";
				const note = i.note ? `  — ${oneLine(i.note, 60)}` : "";
				return `${n + 1}. ${icon} ${i.where}${t}  · ${ago(i.age)}${note}`;
			});
			const choice = await ctx.ui.select(`pi queue (${items.length}) — pick to jump`, labels);
			if (!choice) return;
			const item = items[labels.indexOf(choice)];
			if (item) await run("sh", [QUEUE_SH, "jump", item.pane]);
		},
	});

	// Other extensions (e.g. bash-guard) can ask for a "waiting on you" notification:
	//   pi.events.emit("notify:waiting", { title: "bash-guard approval", message: "rm -rf build" })
	pi.events.on("notify:waiting", async (data: any) => {
		const what = data?.title ? String(data.title) : "input";
		await notifyWaiting(what, String(data?.message ?? ""));
	});
}
