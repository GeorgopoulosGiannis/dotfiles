/**
 * Custom Header Extension
 *
 * Replaces pi's startup header with a true-colour ASCII portrait of my dog,
 * generated from a photo with ascii_magic (see generate_art.py), followed by a
 * `> pi vX.Y.Z █` prompt line. The portrait is skipped when the terminal is
 * narrower than the art.
 *
 * Started from the custom header in amosblomqvist/pi-config
 * (https://github.com/amosblomqvist/pi-config).
 *
 * Usage: regenerate art.ts with `python3 generate_art.py PHOTO`, then run /reload in pi.
 * To restore the built-in header: /builtin-header, or delete this folder and /reload.
 */

import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { VERSION } from "@earendil-works/pi-coding-agent";
import { ART, ART_WIDTH } from "./art.ts";

const ACCENT = [230, 150, 80];
const rgb = ([r, g, b]: number[], text: string) => `\x1b[38;2;${r};${g};${b}m${text}\x1b[39m`;

const promptLine = (theme: Theme) =>
	theme.fg("dim", "> ") +
	theme.bold(rgb(ACCENT, "pi")) +
	theme.fg("dim", ` v${VERSION}`) +
	theme.bold(rgb(ACCENT, " █"));

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;

		ctx.ui.setHeader((_tui, theme) => ({
			render(width: number): string[] {
				const prompt = promptLine(theme);
				return width >= ART_WIDTH ? [...ART, prompt] : [prompt];
			},
			invalidate() {},
		}));
	});

	// Command to restore the built-in header
	pi.registerCommand("builtin-header", {
		description: "Restore the built-in startup header",
		handler: async (_args, ctx) => {
			ctx.ui.setHeader(undefined);
			ctx.ui.notify("Built-in header restored", "info");
		},
	});
}
