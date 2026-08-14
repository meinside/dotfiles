/**
 * pi-sandbox needs OS-level helpers to actually enforce sandbox.json: without
 * them the extension either fails to initialize (ripgrep on both platforms,
 * bubblewrap/socat on Linux) or silently can't create the namespaces it needs
 * (Ubuntu 24.04+'s AppArmor restriction on unprivileged user namespaces).
 *
 * These are real go/no-go checks, not "which language servers happen to be
 * installed" notes like lsp.test.ts: `sandbox.json`'s `enabled: true` is
 * committed and machine-wide, so a machine missing a dependency is *not*
 * sandboxed despite the config saying it should be, and that gap is silent
 * until someone notices bash running unsandboxed.
 */

import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import { resolveCommand } from "./lib.ts";

test("ripgrep is installed (pi-sandbox requires it on both macOS and Linux)", () => {
	assert.ok(resolveCommand("rg"), "ripgrep (rg) not found on PATH; pi-sandbox fails to initialize without it");
});

test("Linux: bubblewrap and socat are installed", (t) => {
	if (process.platform !== "linux") return t.skip("bubblewrap/socat are Linux-only; macOS sandboxes via Seatbelt");
	for (const name of ["bwrap", "socat"]) {
		assert.ok(resolveCommand(name), `${name} not found on PATH; required for pi-sandbox's Linux backend`);
	}
});

/**
 * Diagnostic only, not a failure: `= 1` means bubblewrap's own unprivileged
 * user namespace is blocked unless an AppArmor profile already compensates
 * for it, which this check has no way to verify from here. The diagnostic
 * lists three fixes in safest-to-quickest order (AppArmor profile, persistent
 * sysctl.d, one-off sysctl -w) rather than picking one, since which one is
 * appropriate depends on whether this machine's AppArmor restriction is load-
 * bearing for anything else — see pi-sandbox's README on Linux requirements.
 */
test("Linux: unprivileged user namespaces are available to bubblewrap", (t) => {
	if (process.platform !== "linux") return t.skip("this AppArmor restriction is Linux-only");

	const sysctlPath = "/proc/sys/kernel/apparmor_restrict_unprivileged_userns";
	let value: string | undefined;
	try {
		value = readFileSync(sysctlPath, "utf8").trim();
	} catch {
		return t.skip(`${sysctlPath} absent; this kernel predates the restriction or doesn't carry it`);
	}

	t.diagnostic(`${sysctlPath} = ${value}`);
	if (value === "1") {
		t.diagnostic(
			"restricted: bubblewrap's own unprivileged user namespace is blocked unless " +
				"something already compensates for it. Fixes, roughly safest-to-quickest:",
		);
		t.diagnostic(
			"  1. Give bubblewrap its own AppArmor profile (see pi-sandbox's README on " +
				"Linux requirements) \u2014 keeps the restriction in place for everything else",
		);
		t.diagnostic(
			"  2. Persistent: echo 'kernel.apparmor_restrict_unprivileged_userns=0' | " +
				"sudo tee /etc/sysctl.d/99-bubblewrap.conf && sudo sysctl --system",
		);
		t.diagnostic("  3. Until reboot only: sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0");
		t.diagnostic(
			"(if one of these is already in place and pi-sandbox works, this diagnostic " +
				"is just noise \u2014 it can't tell that from here)",
		);
	}
});
