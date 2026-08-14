/**
 * pi-sandbox needs OS-level helpers to actually enforce sandbox.json: without
 * them the extension either fails to initialize (ripgrep on both platforms,
 * bubblewrap/socat on Linux) or silently can't create the namespaces it needs
 * (Ubuntu 24.04+'s AppArmor restriction on unprivileged user namespaces, or
 * the older kernel.unprivileged_userns_clone some distros still gate on).
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
 * Diagnostic only for the AppArmor-specific knob ("= 1" can be compensated
 * for by a profile this check has no way to see), but a real failure for the
 * older, more universal one: kernel.unprivileged_userns_clone = 0 blocks
 * unprivileged user namespaces outright, with no AppArmor-profile escape
 * hatch, so a machine stuck there needs the sysctl flipped, full stop. Falls
 * back to the legacy knob only when the AppArmor one is absent, since a
 * kernel new enough to carry that one restricts through it instead.
 */
test("Linux: unprivileged user namespaces are available to bubblewrap", (t) => {
	if (process.platform !== "linux") return t.skip("this AppArmor restriction is Linux-only");

	const apparmorPath = "/proc/sys/kernel/apparmor_restrict_unprivileged_userns";
	try {
		const value = readFileSync(apparmorPath, "utf8").trim();
		t.diagnostic(`${apparmorPath} = ${value}`);
		if (value === "1") {
			t.diagnostic(
				"restricted: bubblewrap's own unprivileged user namespace is blocked unless " +
					"something already compensates for it. Fixes, roughly safest-to-quickest:",
			);
			t.diagnostic(
				"  1. Give bubblewrap its own AppArmor profile (see pi-sandbox's README on " +
					"Linux requirements) - keeps the restriction in place for everything else",
			);
			t.diagnostic(
				"  2. Persistent: echo 'kernel.apparmor_restrict_unprivileged_userns=0' | " +
					"sudo tee /etc/sysctl.d/99-bubblewrap.conf && sudo sysctl --system",
			);
			t.diagnostic("  3. Until reboot only: sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=0");
			t.diagnostic(
				"(if one of these is already in place and pi-sandbox works, this diagnostic " +
					"is just noise -- it can't tell that from here)",
			);
		}
		return;
	} catch {
		// Absent, not restricted through this knob: fall through to the legacy one.
	}

	const legacyPath = "/proc/sys/kernel/unprivileged_userns_clone";
	let legacyValue: string | undefined;
	try {
		legacyValue = readFileSync(legacyPath, "utf8").trim();
	} catch {
		return t.skip(`neither ${apparmorPath} nor ${legacyPath} exist; this kernel restricts through neither`);
	}

	t.diagnostic(`${apparmorPath} absent; falling back to ${legacyPath} = ${legacyValue}`);
	assert.notEqual(
		legacyValue,
		"0",
		`${legacyPath} is 0: unprivileged user namespaces are blocked outright, no AppArmor-profile ` +
			`escape hatch. Fix: echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-bubblewrap.conf ` +
			`&& sudo sysctl --system (or sudo sysctl -w kernel.unprivileged_userns_clone=1 until reboot)`,
	);
});
