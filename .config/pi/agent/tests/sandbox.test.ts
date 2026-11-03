/**
 * sandbox.json is real policy, not decoration: pi-sandbox enforces it at the OS
 * level, and README.md's Sandbox extension section makes specific claims about
 * what it does and doesn't allow. Those claims deserve the same pinning
 * guard.test.ts gives extensions/guard.ts.
 *
 * This checks the committed JSON, not the effective policy pi-sandbox computes from
 * it: Node refuses to strip types under `node_modules`
 * (`ERR_UNSUPPORTED_NODE_MODULES_TYPE_STRIPPING`), and pi-sandbox's `loadConfig()`
 * imports pi's package, which resolves only inside a running pi.
 *
 * `denyWrite` gets the strictest treatment: `GENERIC_SECRET_GLOBS`,
 * `CREDENTIAL_PATHS` and `READ_ONLY_DATA` below must union to exactly `denyWrite`,
 * so a removal (weakened policy) and an addition left uncategorized here both fail.
 * `allowRead`/`allowWrite`/`allowedDomains` are open-ended by design
 * (`/sandbox-allow` is how they grow), so they get per-invariant checks instead.
 */

import assert from "node:assert/strict";
import { basename } from "node:path";
import test from "node:test";
import { PROTECTED_PATHS, SECRET_PATHS } from "../extensions/guard.ts";
import { readJson } from "./lib.ts";

/** The agent-dir files guard.ts protects, so a file added there is demanded here too. */
const agentDirFiles = (paths: readonly string[]): string[] => paths.filter((path) => /^~\/(\.config\/pi|\.pi)\/agent\/[^/]+\.json$/.test(path));

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

/** Filename globs in `denyWrite` that aren't tied to a specific tool or path. */
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
	// auth.json, mcp-auth.json (built-in MCP client's OAuth tokens), telegram.json
	...agentDirFiles(PROTECTED_PATHS),
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

/** Data that in-process tools write and `bash` must only read. MagPi's cache is
 * the agent dir's `magpi-cache` symlink into XDG cache, where `~/.cache` is
 * otherwise `allowWrite`: a command able to write it could plant a page that a
 * later `magpi_fetch` serves as fetched. */
const READ_ONLY_DATA = ["~/.cache/pi/magpi-cache"];

/** Credential files that `bash` must not read even when pi runs in the agent
 * directory, where `allowRead: "."` re-allows everything under the `/Users`
 * deny. On macOS sandbox-runtime re-emits a literal `denyRead` path nested in an
 * `allowRead` subpath after it, so the more specific deny wins.
 *
 * `auth.json` is deliberately absent: `llama.test.ts`, `quota-rotate.test.ts`
 * and `samples.test.ts` read it to cross-check the samples, and they run under
 * this sandbox when `check.sh` is started from inside pi. */
const AGENT_DIR_SECRETS = agentDirFiles(SECRET_PATHS).filter((path) => basename(path) !== "auth.json");

/** Bare domains tools need, which a wildcard does *not* cover where it is enforced:
 * pi-sandbox's own `domainMatchesPattern` lets `*.github.com` cover `github.com`, but
 * that only decides whether to prompt. `@carderne/sandbox-runtime`'s proxy matches
 * strict subdomains only, so with just the wildcard `git clone https://github.com/...`
 * fails with `CONNECT tunnel failed, response 403` and no prompt. */
const BARE_DOMAINS_TOOLS_NEED = [
	"crates.io",
	"github.com",
	"luarocks.org",
	"nodejs.org",
	"pub.dev",
	"pypi.org",
	"rubygems.org",
];

/** Whether a `*.literal` wildcard is present. */
function wildcardCoversLiteral(literal: string, wildcards: string[]): boolean {
	return wildcards.some((pattern) => pattern.startsWith("*.") && pattern.slice(2) === literal);
}

test("sandbox.json is valid JSON with the documented top-level shape", () => {
	assert.notEqual(config, undefined, "sandbox.json missing or not valid JSON");
	assert.equal(config?.enabled, true);
	assert.equal(config?.allowBrowserProcess, false, "no browser workflow here; see README.md");
});

test("denyWrite is exactly the generic secret globs, the credential paths and the read-only data", () => {
	const denyWrite = config?.filesystem?.denyWrite ?? [];
	const expected = [...GENERIC_SECRET_GLOBS, ...CREDENTIAL_PATHS, ...READ_ONLY_DATA].sort();
	assert.deepEqual(
		[...denyWrite].sort(),
		expected,
		"filesystem.denyWrite drifted from GENERIC_SECRET_GLOBS + CREDENTIAL_PATHS + READ_ONLY_DATA in this file — update whichever one is stale",
	);
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

test("agent-dir credential files stay unreadable when pi runs in the agent dir", () => {
	const denyRead = config?.filesystem?.denyRead ?? [];
	for (const path of AGENT_DIR_SECRETS) {
		assert.ok(denyRead.includes(path), `${path} should be in filesystem.denyRead`);
	}
});

test("bare domains a wildcard cannot cover are listed literally", () => {
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
