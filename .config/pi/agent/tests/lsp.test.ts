/**
 * `pi-lsp.json` replaces pi-lsp's built-in catalog, so a configured command that
 * cannot start aborts a whole `lsp_diagnostics` call instead of being skipped.
 *
 * The file is deliberately a superset of what any single machine installs, so a
 * server missing from PATH is skipped rather than failed. A server that is on
 * PATH but cannot exec *is* a failure: mason wrappers hardcode the asdf
 * interpreter present at install time, so an asdf upgrade leaves them installed
 * but dead with exit 126, in neovim too. Reinstall those through mason.
 */

import assert from "node:assert/strict";
import { spawnSync } from "node:child_process";
import test from "node:test";
import { readJson } from "./lib.ts";

const EXEC_FAILURE_MARKERS = ["bad interpreter", "cannot execute", "No such file or directory"];

interface ServerSpec {
	command?: string[];
	extensions?: string[];
}

const config = readJson<Record<string, unknown>>("pi-lsp.json");
// pi-lsp accepts both shapes: a bare server map, or { "servers": { ... } }
const nested = config?.servers;
const servers: Record<string, unknown> =
	nested && typeof nested === "object" ? (nested as Record<string, unknown>) : (config ?? {});

test("pi-lsp.json is present and valid", (t) => {
	if (config === undefined) return t.diagnostic("pi-lsp.json absent; pi-lsp would use its built-in catalog");
	assert.ok(Object.keys(servers).length > 0, "pi-lsp.json defines no servers");
});

for (const name of Object.keys(servers).sort()) {
	test(`${name} is usable`, (t) => {
		const spec = servers[name] as ServerSpec | null;
		if (typeof spec !== "object" || spec === null) return t.skip("not a server entry");

		const argv = spec.command ?? [];
		assert.ok(argv.length > 0, `${name}: no command`);
		assert.ok(spec.extensions?.length, `${name}: no extensions, so nothing routes to it`);

		const found = spawnSync("sh", ["-c", `command -v "$1"`, "_", argv[0]], { encoding: "utf8" });
		const path = found.stdout.trim();
		if (!path) {
			// expected: the file is shared across machines
			return t.skip(`${name}: not installed here; install it or drop the entry`);
		}

		// exit 126/127 is the exec failure that matters. A probe that hangs until the
		// timeout has started successfully, so only a real spawn error counts: jdtls
		// never answers `--version` and must not be reported as broken.
		const probe = spawnSync(path, ["--version"], { encoding: "utf8", timeout: 5000 });
		const timedOut = (probe.error as NodeJS.ErrnoException | undefined)?.code === "ETIMEDOUT" || probe.signal !== null;
		const output = `${probe.stderr ?? ""}${probe.stdout ?? ""}`;
		const broken =
			!timedOut &&
			(probe.error !== undefined ||
				probe.status === 126 ||
				probe.status === 127 ||
				EXEC_FAILURE_MARKERS.some((marker) => output.includes(marker)));
		assert.ok(
			!broken,
			`${name}: on PATH but does not exec (${output.split("\n").find((line) => line.trim()) ?? `exit ${probe.status}`})`,
		);
		t.diagnostic(`${name} -> ${path}${timedOut ? " (no --version; started and was killed)" : ""}`);
	});
}
