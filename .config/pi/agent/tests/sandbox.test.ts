/**
 * sandbox.json is real policy, not decoration: pi-sandbox enforces it at the OS
 * level, and README.md's Sandbox extension section makes specific claims about
 * what it does and doesn't allow. Those claims deserve the same pinning
 * guard.test.ts gives extensions/guard.ts.
 *
 * What this file can't do: import pi-sandbox's own matching functions
 * (`matchesPattern`, `domainMatchesPattern` in `pi-sandbox/src/policy.ts`) the
 * way guard.test.ts imports `../extensions/guard.ts` directly. Node's built-in
 * TypeScript loader refuses to strip types for anything under `node_modules`
 * (`ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING`), and `loadConfig()` there also
 * imports `getAgentDir` from `@earendil-works/pi-coding-agent`, which only
 * resolves inside a running pi process, not a bare `node --test` run. So this
 * checks the committed JSON directly rather than the effective policy pi-sandbox
 * computes from it. The one exception is `wildcardCoversLiteral` below, a
 * two-line reimplementation of the redundancy rule in `domainMatchesPattern`
 * (`*.example.com` also matches the bare `example.com`) — simple and stable
 * enough that pinning it locally beats not checking it at all.
 *
 * `denyWrite` gets the strictest treatment: `GENERIC_SECRET_GLOBS` and
 * `CREDENTIAL_PATHS` below are asserted to union to exactly `denyWrite`, not
 * just be contained in it. A plain "each expected path is present" check only
 * catches removals; this also catches additions left uncategorized, which is
 * the direction that actually matters here — a new credential-bearing path
 * added to `sandbox.json` without a matching entry in this file would
 * otherwise pass silently. `allowRead`/`allowWrite`/`allowedDomains` stay on
 * the weaker per-invariant style below since they are open-ended by design
 * (`/sandbox-allow` is exactly how they are meant to grow), so a fixed
 * expected set would fight normal usage rather than catch drift.
 */

import assert from "node:assert/strict";
import test from "node:test";
import { readJson } from "./lib.ts";

interface SandboxConfig {
	enabled?: boolean;
	allowBrowserProcess?: boolean;
	network?: {
		allowedDomains?: string[];
		deniedDomains?: string[];
	};
	filesystem?: {
		denyRead?: string[];
		allowRead?: string[];
		allowWrite?: string[];
		denyWrite?: string[];
	};
}

const config = readJson<SandboxConfig>("sandbox.json");

/** Filename globs in `denyWrite` that aren't tied to a specific tool or path —
 * these plus `CREDENTIAL_PATHS` below should be the exhaustive contents of
 * `filesystem.denyWrite`. Keeping the two lists separate from a single
 * `credential paths are hard-blocked` check means adding a path to
 * `sandbox.json` without touching this file breaks the union-equality test
 * below, rather than passing silently. */
const GENERIC_SECRET_GLOBS = [".env", ".env.*", "*.pem", "*.key", "*.p12", "*.pfx"];

/** Paths that hold live credentials, even though a cache directory around them
 * (`~/.local/share/cargo`, `~/.gem`, `~/.bundle`) is otherwise allow-listed for
 * toolchain writes. `denyWrite` always wins over `allowWrite` in pi-sandbox, so
 * listing these here is what keeps the surrounding cache directories safe to
 * open up at all. */
const CREDENTIAL_PATHS = [
	"~/.ssh",
	"~/.aws",
	"~/.gnupg",
	"~/.netrc",
	"~/.npmrc",
	"~/.config/gcloud",
	"~/.config/rclone",
	"~/.config/gh",
	"~/.ollama/id_ed25519",
	"~/.claude/settings.json",
	"~/.config/claude/settings.json",
	"~/.config/pi/agent/auth.json",
	"~/.pi/agent/auth.json",
	"~/.local/share/cargo/credentials.toml",
	"~/.local/share/cargo/credentials",
	"~/.gem/credentials",
	"~/.bundle/config",
];

/** `~/.pi/cost-tracker` is a sibling of the agent directory, not a path under
 * it, so it needs its own allow entries; this is the EPERM regression found
 * while writing this policy (see README.md, Sandbox extension). Both sides of
 * the `~/.pi -> .config/pi` symlink are listed since a still-missing target
 * directory can defeat canonicalization depending on which layer resolves it. */
const COST_TRACKER_PATHS = ["~/.pi/cost-tracker", "~/.config/pi/cost-tracker"];

/** Two-line reimplementation of the redundancy half of
 * `domainMatchesPattern` in `pi-sandbox/src/policy.ts`: a `*.base` entry
 * already matches the bare `base` domain, so listing both is dead weight. */
function wildcardCoversLiteral(literal: string, wildcards: string[]): boolean {
	return wildcards.some((pattern) => pattern.startsWith("*.") && pattern.slice(2) === literal);
}

test("sandbox.json is valid JSON with the documented top-level shape", () => {
	assert.notEqual(config, undefined, "sandbox.json missing or not valid JSON");
	assert.equal(config?.enabled, true);
	assert.equal(config?.allowBrowserProcess, false, "no browser workflow here; see README.md");
});

test("denyWrite is exactly the generic secret globs plus the credential paths", () => {
	// Union-equality, not subset: this fails on a removal (weakened policy) same
	// as an addition (new entry left uncategorized here) instead of only the
	// former, so sandbox.json and this file can't drift apart silently.
	const denyWrite = config?.filesystem?.denyWrite ?? [];
	const expected = [...GENERIC_SECRET_GLOBS, ...CREDENTIAL_PATHS].sort();
	assert.deepEqual(
		[...denyWrite].sort(),
		expected,
		"filesystem.denyWrite drifted from GENERIC_SECRET_GLOBS + CREDENTIAL_PATHS in this file — update whichever one is stale",
	);
});

test("credential paths are hard-blocked even though their parent cache dirs are writable", () => {
	const denyWrite = config?.filesystem?.denyWrite ?? [];
	for (const path of CREDENTIAL_PATHS) {
		assert.ok(denyWrite.includes(path), `${path} should be in filesystem.denyWrite`);
	}
});

test("credential paths never appear as their own allowWrite entry", () => {
	const allowWrite = config?.filesystem?.allowWrite ?? [];
	for (const path of CREDENTIAL_PATHS) {
		assert.ok(!allowWrite.includes(path), `${path} should not be directly in filesystem.allowWrite`);
	}
});

test("cost-tracker paths are allowed for read and write on both sides of the symlink", () => {
	const allowRead = config?.filesystem?.allowRead ?? [];
	const allowWrite = config?.filesystem?.allowWrite ?? [];
	for (const path of COST_TRACKER_PATHS) {
		assert.ok(allowRead.includes(path), `${path} should be in filesystem.allowRead`);
		assert.ok(allowWrite.includes(path), `${path} should be in filesystem.allowWrite`);
	}
});

test("denyRead covers both the macOS and Linux home-directory root", () => {
	const denyRead = config?.filesystem?.denyRead ?? [];
	assert.ok(denyRead.includes("/Users"), "denyRead should list /Users (macOS)");
	assert.ok(denyRead.includes("/home"), "denyRead should list /home (Linux)");
});

test("no allowedDomains entry is redundant with a wildcard already in the list", () => {
	const domains = config?.network?.allowedDomains ?? [];
	for (const domain of domains) {
		if (domain.startsWith("*.") || domain === "*") continue;
		assert.ok(
			!wildcardCoversLiteral(domain, domains),
			`${domain} is redundant: a *.${domain} wildcard already covers it`,
		);
	}
});

test("filesystem path arrays stay alphabetically sorted", () => {
	for (const key of ["denyRead", "allowRead", "allowWrite", "denyWrite"] as const) {
		const list = config?.filesystem?.[key] ?? [];
		const sorted = [...list].sort();
		assert.deepEqual(list, sorted, `filesystem.${key} should be sorted alphabetically`);
	}
});
