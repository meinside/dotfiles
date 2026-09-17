/**
 * `quota-rotate.json`'s `chain` is a list of model ids that other people own, and it
 * is the one external-fact list in this directory with no drift check — which is why
 * it is the one that went stale: `openrouter/z-ai/glm-5.2:free` sat in the chain after
 * OpenRouter withdrew the free endpoint, and it was found by hand rather than by
 * `check.sh`.
 *
 * A withdrawn id does not fail loudly. `pi-quota-rotate`'s `resolveChain()` drops any
 * pattern that matches no model, deliberately ("a chain is a preference list and a
 * missing model is not fatal"), so the only symptom is rotation stopping earlier than
 * the configured chain suggests. It reports unresolved patterns once at startup; this
 * moves that signal into the checks, where it is not missed.
 *
 * The matching rule below mirrors `pi-quota-rotate`'s `src/chain.ts` rather than
 * importing it, for the reason `tests/sandbox.test.ts` gives about `pi-sandbox`: Node
 * refuses type stripping under `node_modules`. The mirrored rule is small and its
 * source is named, so a divergence is visible.
 *
 * The model universe is `models-store.json` (pi's generated catalog, which is where
 * the OpenRouter, Google and NVIDIA ids in the chain live) plus `models.json`. That is
 * an approximation of the live `getModels()` the extension actually resolves against:
 * scoped-model filtering and provider auth are session facts a check cannot see, so
 * anything auth-shaped below is a diagnostic and not a failure.
 *
 * Both halves are checked: the local `quota-rotate.json` this machine runs, and
 * `quota-rotate.json.sample`, which is what a fresh clone starts from and the only half
 * that is tracked.
 */

import assert from "node:assert/strict";
import test from "node:test";
import { type ModelsConfig, modelEntries, readJson } from "./lib.ts";

interface QuotaRotateConfig {
	chain?: string[];
	maxRotationsPerRun?: number;
	quotaRotate?: { chain?: string[]; maxRotationsPerRun?: number };
}

/** Both shapes the extension accepts: bare object, or wrapped in `quotaRotate`. */
function settings(config: QuotaRotateConfig | undefined): { chain: string[]; maxRotationsPerRun?: number } {
	const inner = config?.quotaRotate ?? config ?? {};
	return { chain: inner.chain ?? [], maxRotationsPerRun: inner.maxRotationsPerRun };
}

/** `{ provider, id }` for every model in pi's generated catalog and in `models.json`. */
function catalogModels(): Array<{ provider: string; id: string }> {
	const out: Array<{ provider: string; id: string }> = [];
	const store = readJson<Record<string, unknown>>("models-store.json") ?? {};
	for (const [provider, value] of Object.entries(store)) {
		const models = Array.isArray(value) ? value : ((value as { models?: unknown[] })?.models ?? []);
		for (const model of models) {
			const id = (model as { id?: unknown })?.id;
			if (typeof id === "string" && id) out.push({ provider, id });
		}
	}
	for (const entry of modelEntries(readJson<ModelsConfig>("models.json"))) {
		out.push({ provider: entry.provider, id: entry.id });
	}
	return out;
}

/** Mirrors `matchesModelId()` in pi-quota-rotate's `src/chain.ts`: exact, or a trailing `*` prefix. */
function matchesModelId(id: string, pattern: string): boolean {
	if (pattern === "*") return true;
	if (pattern.endsWith("*")) return id.startsWith(pattern.slice(0, -1));
	return id === pattern;
}

/** Mirrors `resolveChain()`: split on the *first* slash, and ignore a pattern without one. */
function splitPattern(pattern: string): { provider: string; modelPattern: string } | null {
	const trimmed = pattern.trim();
	const slash = trimmed.indexOf("/");
	if (slash <= 0 || slash === trimmed.length - 1) return null;
	return { provider: trimmed.slice(0, slash), modelPattern: trimmed.slice(slash + 1) };
}

const config = readJson<QuotaRotateConfig>("quota-rotate.json");
const sample = readJson<QuotaRotateConfig>("quota-rotate.json.sample");
const { chain, maxRotationsPerRun } = settings(config);
const models = catalogModels();

test("quota-rotate.json holds a usable chain", (t) => {
	if (!config) return t.skip("quota-rotate.json unreadable (a fresh clone has only the sample)");
	assert.ok(chain.length > 0, "chain is empty; rotation would fall back to the session's scoped models");
	assert.deepEqual(
		chain.filter((pattern) => splitPattern(pattern) === null),
		[],
		"a chain entry needs the provider/modelId shape; resolveChain() ignores anything else",
	);
	assert.deepEqual(
		chain.filter((pattern, index) => chain.indexOf(pattern) !== index),
		[],
		"duplicate chain entries; resolveChain() keeps the first position and drops the rest",
	);
});

test("every chain entry still resolves to a model pi knows", (t) => {
	if (!config) return t.skip("quota-rotate.json unreadable");
	if (models.length === 0) return t.skip("models-store.json unreadable; nothing to resolve against");

	const unresolved: string[] = [];
	for (const pattern of chain) {
		const split = splitPattern(pattern);
		if (!split) continue; // shape is the other test's business
		const hits = models.filter(
			(model) => model.provider === split.provider && matchesModelId(model.id, split.modelPattern),
		);
		if (hits.length === 0) unresolved.push(pattern);
		else t.diagnostic(`${pattern} -> ${hits.length} model${hits.length === 1 ? "" : "s"}`);
	}

	assert.deepEqual(
		unresolved,
		[],
		`no model matches ${unresolved.join(", ")}; the chain is shorter than it looks. ` +
			"Withdrawn or renamed ids are dropped silently by resolveChain(), so fix or remove the entry",
	);
});

test("the chain's providers are ones this machine can authenticate", (t) => {
	if (!config) return t.skip("quota-rotate.json unreadable");
	// Machine-specific, so a note: pickNext() skips a candidate whose provider has no
	// auth, which shortens the chain exactly like an unresolved id does.
	const auth = readJson<Record<string, unknown>>("auth.json");
	if (!auth) return t.skip("auth.json unreadable");
	const providers = [...new Set(chain.map((pattern) => splitPattern(pattern)?.provider).filter(Boolean))].filter(
		(provider): provider is string => typeof provider === "string",
	);
	for (const provider of providers) {
		t.diagnostic(`${provider}: ${provider in auth ? "authenticated" : "NO auth entry; pickNext() will skip it"}`);
	}
});

test("maxRotationsPerRun can reach the end of the chain", (t) => {
	if (!config) return t.skip("quota-rotate.json unreadable");
	// Not a failure: a short budget is a legitimate choice (each rotation costs a
	// request), and the extension says so when it runs out. Worth stating, because a
	// chain longer than the budget is only walked across several prompts.
	const budget = maxRotationsPerRun ?? 4;
	t.diagnostic(
		budget >= chain.length - 1
			? `${budget} rotations covers the ${chain.length}-entry chain in one prompt`
			: `${budget} rotations of a ${chain.length}-entry chain: the last ${chain.length - 1 - budget} entr${chain.length - budget === 2 ? "y is" : "ies are"} only reachable in a later prompt`,
	);
});

test("the sample a fresh clone starts from resolves too", (t) => {
	// The real file is local, so the sample is what a new machine gets. A withdrawn id in
	// there is the same silent shortening, except nobody is watching for it: this is the
	// half that ships.
	if (!sample) return t.skip("quota-rotate.json.sample unreadable");
	if (models.length === 0) return t.skip("models-store.json unreadable; nothing to resolve against");
	const sampleChain = settings(sample).chain;
	assert.ok(sampleChain.length > 0, "the sample must carry a chain; it is the starting point");
	const unresolved = sampleChain.filter((pattern) => {
		const split = splitPattern(pattern);
		return !split || !models.some((m) => m.provider === split.provider && matchesModelId(m.id, split.modelPattern));
	});
	assert.deepEqual(unresolved, [], `the sample chain cannot resolve ${unresolved.join(", ")} on this machine`);

	// Drift between the two is expected and only reported: the sample is a starting point,
	// not a copy of one machine's preferences.
	const onlyReal = chain.filter((entry) => !sampleChain.includes(entry));
	const onlySample = sampleChain.filter((entry) => !chain.includes(entry));
	if (onlyReal.length) t.diagnostic(`only in the local file: ${onlyReal.join(", ")}`);
	if (onlySample.length) t.diagnostic(`only in the sample: ${onlySample.join(", ")}`);
});
