/**
 * guard.ts - narrow safety gate for the built-in tools
 *
 * pi has no tool permission system by design (docs/security.md, "No Built-in
 * Sandbox") and its answer for risky work is to isolate the process, which is no
 * use for a config that edits the home directory. So this blocks writes to
 * credential files, confirms machine-changing or irreversible commands, and
 * leaves everything else unprompted. Rationale in README.md.
 */

import { homedir } from "node:os";
import { isAbsolute, resolve, sep } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// ---------------------------------------------------------------- policy

/**
 * Never writable by a tool. Matched against the resolved absolute path, either
 * exactly or as a directory prefix, so `~/.ssh` also covers `~/.ssh/id_ed25519`.
 */
const PROTECTED_PATHS = [
	"~/.ssh",
	"~/.gnupg",
	"~/.aws/credentials",
	"~/.aws/config",
	"~/.netrc",
	"~/.npmrc",
	"~/.config/pi/agent/auth.json",
	"~/.pi/agent/auth.json",
];

/**
 * Shell commands that change the machine outside the workspace, or that cannot
 * be undone. Each one costs the user a prompt, so read-only and reversible forms
 * are excluded on purpose: a noisy gate trains people to accept blindly.
 */
const CONFIRM_PATTERNS: Array<{ pattern: RegExp; label: string }> = [
	// package managers, system wide
	{ pattern: /\bbrew\s+(install|uninstall|remove|upgrade|tap|untap)\b/, label: "homebrew change" },
	{ pattern: /\bnpm\s+(i|install|uninstall|remove|rm)\b[^|;]*\s(-g|--global)\b/, label: "global npm change" },
	{ pattern: /\b(pnpm|yarn|bun)\s+(add|remove)\b[^|;]*\s(-g|--global)\b/, label: "global package change" },
	{ pattern: /\buv\s+tool\s+(install|uninstall|upgrade)\b/, label: "uv tool change" },
	{ pattern: /\b(pip|pip3|pipx)\s+(install|uninstall)\b/, label: "python package change" },
	{ pattern: /\bgem\s+(install|uninstall)\b/, label: "gem change" },
	{ pattern: /\bcargo\s+(install|uninstall)\b/, label: "cargo change" },
	{ pattern: /\bgo\s+install\b/, label: "go install" },
	{ pattern: /\basdf\s+(install|uninstall|global)\b/, label: "asdf change" },
	{ pattern: /\bmason(-tool)?-?install\b|:MasonInstall\b/, label: "mason change" },
	// privilege escalation
	{ pattern: /\bsudo\b/, label: "sudo" },
	// irreversible file and history operations
	{ pattern: /\brm\s+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)\b/, label: "recursive delete" },
	{ pattern: /\bgit\s+(push)\b[^|;]*(--force\b(?!-with-lease)|(^|\s)-f(\s|$))/, label: "force push" },
	{ pattern: /\bgit\s+reset\s+[^|;]*--hard\b/, label: "hard reset" },
	{ pattern: /\bgit\s+clean\b[^|;]*-[a-zA-Z]*f/, label: "git clean" },
	{ pattern: /\bgit\s+(filter-branch|filter-repo)\b/, label: "history rewrite" },
];

// ---------------------------------------------------------------- helpers

/** Expand a leading `~` and normalise, so comparisons are path-shape agnostic. */
function expand(path: string): string {
	if (path === "~") return homedir();
	if (path.startsWith(`~${sep}`) || path.startsWith("~/")) return resolve(homedir(), path.slice(2));
	return path;
}

const protectedAbsolute = PROTECTED_PATHS.map(expand);

/** `true` when `target` is a protected file or lives inside a protected directory. */
function isProtected(target: string, cwd: string): boolean {
	const expanded = expand(target);
	const absolute = isAbsolute(expanded) ? resolve(expanded) : resolve(cwd, expanded);
	return protectedAbsolute.some((guarded) => absolute === guarded || absolute.startsWith(guarded + sep));
}

/** First policy a command trips, if any. */
function matchCommand(command: string): string | undefined {
	return CONFIRM_PATTERNS.find(({ pattern }) => pattern.test(command))?.label;
}

/**
 * Ask before running. Blocks without asking when no UI can answer: headless runs
 * (`-p`, `--mode json`) should fail loudly rather than install something.
 */
async function allow(ctx: ExtensionContext, label: string, command: string): Promise<boolean> {
	if (!ctx.hasUI) return false;
	const choice = await ctx.ui.select(`Allow this ${label}?\n\n  ${command.trim()}`, ["Allow once", "Block"]);
	return choice === "Allow once";
}

// ---------------------------------------------------------------- extension

export default function (pi: ExtensionAPI) {
	pi.on("tool_call", async (event, ctx) => {
		if (event.toolName === "write" || event.toolName === "edit") {
			const path = event.input.path;
			if (typeof path === "string" && isProtected(path, ctx.cwd)) {
				if (ctx.hasUI) ctx.ui.notify(`Blocked write to protected path: ${path}`, "warning");
				return { block: true, reason: `"${path}" is protected by guard.ts and must be edited by hand` };
			}
			return undefined;
		}

		if (event.toolName !== "bash") return undefined;

		const command = event.input.command;
		if (typeof command !== "string") return undefined;
		const label = matchCommand(command);
		if (!label) return undefined;

		if (await allow(ctx, label, command)) return undefined;
		return { block: true, reason: `Blocked by guard.ts (${label}); ask the user to run it themselves` };
	});

	// `!command` typed by the user never goes through tool_call. The user asked
	// for it explicitly, so only the no-UI case is worth blocking; otherwise this
	// would prompt for a command that was just typed by hand.
	pi.on("user_bash", async (event, ctx) => {
		const label = matchCommand(event.command);
		if (!label || ctx.hasUI) return undefined;
		return {
			result: {
				output: `Blocked by guard.ts (${label}): no UI to confirm`,
				exitCode: 1,
				cancelled: false,
				truncated: false,
			},
		};
	});
}
