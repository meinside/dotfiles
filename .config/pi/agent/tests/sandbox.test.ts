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
 * computes from it. It used to make one exception, `wildcardCoversLiteral`, a
 * two-line reimplementation of a "redundancy rule" that turned out not to exist
 * at the layer that matters: `pi-sandbox`'s own `domainMatchesPattern` does treat
 * `*.example.com` as covering the bare `example.com`
 * (`domain === base || endsWith("." + base)`), but that function only decides
 * whether to *prompt*. Enforcement is `matchesDomainPattern` in
 * `@carderne/sandbox-runtime`, which requires a strict subdomain
 * (`h.endsWith("." + base)`), so a bare domain covered only by a wildcard is
 * hard-blocked by the runtime proxy with no prompt at all. The old invariant
 * therefore pushed the config into blocking `git clone`; it is replaced below by
 * `BARE_DOMAINS_TOOLS_NEED`, measured under a real sandbox (see README.md).
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

/** Bare domains that a wildcard entry does *not* cover at the enforcement
 * layer. Each was measured under a real `@carderne/sandbox-runtime` sandbox
 * generated from this `sandbox.json`: with only `*.github.com` present,
 * `https://github.com/` returned `000` and `git clone` failed with `CONNECT
 * tunnel failed, response 403`; same for `pypi.org` (pip's index), `crates.io`,
 * `rubygems.org`, `nodejs.org` (asdf-nodejs), `pub.dev` and `luarocks.org`. The
 * wildcards stay in the config too, for
 * the subdomains that actually serve the artifacts. */
const BARE_DOMAINS_TOOLS_NEED = [
	"crates.io",
	"github.com",
	"luarocks.org",
	"nodejs.org",
	"pub.dev",
	"pypi.org",
	"rubygems.org",
];

/** Whether a `*.literal` wildcard is present. No longer a redundancy check —
 * both forms are needed, and this now backs the assertion that the wildcard was
 * not dropped once the literal exists. */
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

test("bare domains a wildcard cannot cover are listed literally", () => {
	// Inverse of the invariant this file used to carry: `*.github.com` does not
	// match `github.com` in the runtime that enforces the policy, so dropping the
	// literal as "redundant" silently breaks `git clone https://github.com/...`.
	const domains = config?.network?.allowedDomains ?? [];
	for (const domain of BARE_DOMAINS_TOOLS_NEED) {
		assert.ok(
			domains.includes(domain),
			`${domain} must be listed literally: a *.${domain} wildcard only matches strict subdomains in @carderne/sandbox-runtime`,
		);
	}
});

test("the wildcard is kept alongside the literal where subdomains serve artifacts", () => {
	const domains = config?.network?.allowedDomains ?? [];
	for (const domain of ["crates.io", "github.com", "nodejs.org", "pypi.org", "rubygems.org"]) {
		assert.ok(
			wildcardCoversLiteral(domain, domains),
			`*.${domain} should stay in allowedDomains: index/CDN hosts are subdomains`,
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
