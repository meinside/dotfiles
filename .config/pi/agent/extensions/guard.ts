/**
 * guard.ts - narrow safety gate for the built-in tools
 *
 * pi has no tool permission system by design (docs/security.md, "No Built-in
 * Sandbox") and its answer for risky work is to isolate the process, which is no
 * use for a config that edits the home directory. So this blocks writes to
 * credential files, blocks the file-reading tools from returning their contents,
 * confirms machine-changing or irreversible commands, and leaves everything else
 * unprompted. Rationale and the limits of the read block in README.md.
 */

import { homedir } from "node:os";
import { isAbsolute, resolve, sep } from "node:path";
import type { ExtensionAPI, ExtensionContext } from "@earendil-works/pi-coding-agent";

// ---------------------------------------------------------------- policy

/**
 * Never writable by a tool. Matched against the resolved absolute path, either
 * exactly or as a directory prefix, so `~/.ssh` also covers `~/.ssh/id_ed25519`.
 *
 * Whole directories rather than single files wherever a vendor keeps adding
 * state: `~/.aws` was two files until `sso/cache` and `cli/cache` turned up
 * holding live tokens, and prefix matching covers whatever the next CLI version
 * writes there. Claude's `settings.json` is here because its hooks run commands.
 */
const PROTECTED_PATHS = [
	"~/.aws",
	"~/.claude/settings.json",
	"~/.config/claude/settings.json",
	"~/.config/gcloud",
	"~/.config/pi/agent/auth.json",
	"~/.config/rclone",
	"~/.gnupg",
	"~/.netrc",
	"~/.npmrc",
	"~/.ollama/id_ed25519",
	"~/.pi/agent/auth.json",
	"~/.ssh",
];

/**
 * Never readable by `read` or `grep`, which return file contents: a secret the
 * agent reads is sent to the provider and written to `sessions/*.jsonl` in the
 * clear, whether or not anyone tries to exfiltrate it.
 *
 * Not derived from the write list, because the two differ on purpose:
 *
 * - `~/.aws/config` is worth reading (profiles and regions, no secrets) while the
 *   rest of `~/.aws` is not, so this names the secret-bearing subpaths instead.
 * - Transcripts are read-blocked but not write-blocked: a secret read once lives
 *   on in them, which makes an agent's own history a second credential store.
 *   Sessions are written under XDG state (`PI_CODING_AGENT_SESSION_DIR`,
 *   `~/.local/state/pi/sessions` by default), not under the agent config dir,
 *   so both locations are listed.
 * - Claude's `settings.json` is writable-blocked for its hooks, not for secrets,
 *   so it stays readable.
 *
 * `bash` is deliberately not gated here; see README.md for why this is a guard
 * against accidents rather than a security boundary.
 */
const SECRET_PATHS = [
	"~/.aws/cli/cache",
	"~/.aws/credentials",
	"~/.aws/sso",
	"~/.bash_history",
	"~/.claude/sessions",
	"~/.config/claude/history.jsonl",
	"~/.config/claude/sessions",
	"~/.config/gcloud",
	"~/.config/pi/agent/auth.json",
	"~/.config/pi/agent/sessions",
	"~/.config/rclone",
	"~/.gnupg",
	"~/.local/state/pi/sessions",
	"~/.netrc",
	"~/.npmrc",
	"~/.ollama/id_ed25519",
	"~/.pi/agent/auth.json",
	"~/.pi/agent/sessions",
	"~/.python_history",
	"~/.ssh",
	"~/.zsh_history",
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
const secretAbsolute = SECRET_PATHS.map(expand);

/** `true` when `target` is one of `guarded` or lives inside one of them. */
function isCovered(guarded: string[], target: string, cwd: string): boolean {
	const expanded = expand(target);
	const absolute = isAbsolute(expanded) ? resolve(expanded) : resolve(cwd, expanded);
	return guarded.some((entry) => absolute === entry || absolute.startsWith(entry + sep));
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
			if (typeof path === "string" && isCovered(protectedAbsolute, path, ctx.cwd)) {
				if (ctx.hasUI) ctx.ui.notify(`Blocked write to protected path: ${path}`, "warning");
				return { block: true, reason: `"${path}" is protected by guard.ts and must be edited by hand` };
			}
			return undefined;
		}

		// `read` always takes a path; `grep`'s is optional and defaults to cwd, which
		// is never a secret path, so an absent path is left alone.
		if (event.toolName === "read" || event.toolName === "grep") {
			const path = event.input.path;
			if (typeof path === "string" && isCovered(secretAbsolute, path, ctx.cwd)) {
				if (ctx.hasUI) ctx.ui.notify(`Blocked read of secret path: ${path}`, "warning");
				return {
					block: true,
					reason: `"${path}" holds credentials and is blocked by guard.ts; ask the user for what you need from it`,
				};
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

	/**
	 * The `tool_call` check asks whether the target sits inside a guarded path, so
	 * `grep` pointed at an ancestor (`~`, `~/.config`) still walks into the secrets
	 * underneath it. Blocking every ancestor would block `grep` on this directory,
	 * which holds `auth.json`, so the matches are dropped from the result instead.
	 *
	 * `dist/core/tools/grep.js` prefixes every line with the file path relative to
	 * the search root: `path:line: text` for a match, `path-line- text` for a
	 * context line. A line whose path cannot be read is left alone, since a secret
	 * always arrives with one.
	 */
	pi.on("tool_result", async (event, ctx) => {
		if (event.toolName !== "grep" || event.isError) return undefined;
		const root = typeof event.input.path === "string" ? event.input.path : ctx.cwd;
		const rootAbsolute = expand(root);
		let dropped = 0;

		const content = event.content.map((block) => {
			if (block.type !== "text" || typeof block.text !== "string") return block;
			const kept = block.text.split("\n").filter((line) => {
				const match = /^(.+?)[:-]\d+[:-]/.exec(line);
				if (!match) return true;
				if (!isCovered(secretAbsolute, resolve(rootAbsolute, match[1]), ctx.cwd)) return true;
				dropped++;
				return false;
			});
			if (dropped === 0) return block;
			// The model has to know the result is partial, or it reasons from a gap.
			kept.push(`(guard.ts removed ${dropped} line(s) matched in credential files)`);
			return { ...block, text: kept.join("\n") };
		});

		if (dropped === 0) return undefined;
		if (ctx.hasUI) ctx.ui.notify(`Removed ${dropped} grep match(es) from secret paths`, "warning");
		return { content };
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
