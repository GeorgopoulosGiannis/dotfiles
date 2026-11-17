/**
 * Custom Header Extension
 *
 * Replaces pi's startup header with a "binary π" logo: a π glyph whose filled
 * cells are the actual bits of π's binary expansion, surrounded by sparse,
 * dim random-bit "rain". Followed by a `> pi vX.Y.Z █` prompt line.
 *
 * Started from the custom header in amosblomqvist/pi-config
 * (https://github.com/amosblomqvist/pi-config); the binary-π logo is new.
 *
 * Usage: edit this file and run /reload in pi.
 * To restore the built-in header: /builtin-header, or delete this file and /reload.
 */

import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { VERSION } from "@earendil-works/pi-coding-agent";

// The glyph SHAPE below is filled with the binary expansion of π
// (11.00100100001111110110101010001000...), read left→right, top→bottom.
// Empty space gets sparse random binary "rain" (regenerated each render).
const PI_BLUE = [80, 180, 230];
const RAIN_BLUE = [35, 70, 95];
const RAIN_DENSITY = 0.1;
const rgb = ([r, g, b]: number[], text: string) => `\x1b[38;2;${r};${g};${b}m${text}\x1b[39m`;
const bit = () => (Math.random() < 0.5 ? "0" : "1");

// π in hex: 3.243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89...
// BigInt drops the leading zeros of "3" (0011), leaving "11" + fractional bits.
const PI_BITS = BigInt(
	"0x3243F6A8885A308D313198A2E03707344A4093822299F31D0082EFA98EC4E6C89",
).toString(2);

const SHAPE = [
	"                                    ",
	"   ██████████████████████████████   ",
	"   ██████████████████████████████   ",
	"      ██████          ██████        ",
	"      ██████          ██████        ",
	"      ██████          ██████        ",
	"      ██████          ██████        ",
	"      ██████          ██████        ",
	"    ██████████      ██████████      ",
	"                                    ",
];

const binaryPi = (theme: Theme) => {
	let n = 0;
	return SHAPE.map(line =>
		[...line]
			.map(ch => {
				if (ch === "█") return theme.bold(rgb(PI_BLUE, PI_BITS[n++ % PI_BITS.length]));
				return Math.random() < RAIN_DENSITY ? rgb(RAIN_BLUE, bit()) : " ";
			})
			.join(""),
	).join("\n");
};

function buildHeader(theme: Theme): string {
	return (
		binaryPi(theme) + "\n" +
		theme.fg("dim", "   > ") +
		theme.bold(rgb(PI_BLUE, "pi")) +
		theme.fg("dim", ` v${VERSION}`) +
		theme.bold(rgb(PI_BLUE, " █"))
	);
}

export default function (pi: ExtensionAPI) {
	pi.on("session_start", async (_event, ctx) => {
		if (!ctx.hasUI) return;

		ctx.ui.setHeader((_tui, theme) => {
			// Generate once so the random bits don't flicker on re-render
			let lines = buildHeader(theme).split("\n");
			return {
				render(_width: number): string[] {
					return lines;
				},
				invalidate() {
					lines = buildHeader(theme).split("\n");
				},
			};
		});
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
