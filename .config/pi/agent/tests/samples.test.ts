/**
 * A fresh clone starts from the `*.sample` files, so an unresolvable tier stops a
 * new machine from working and a leak is unrecoverable once pushed. Those two are
 * failures. Which providers and models a machine has is machine specific, so a
 * difference between a sample and the real file is only reported.
 */

import assert from "node:assert/strict";
import test from "node:test";
import { agentModels, leaves, type ModelsConfig, modelEntries, readJson, readText, substringMatches } from "./lib.ts";

const PLACEHOLDER = /^<<<.*>>>$/;
const SECRET_KEY = /(key|token|secret|password|credential)$/i;
const RUNTIME_KEYS = ["lastChangelogVersion", "defaultThinkingLevel"];
const SAMPLES = ["models.json", "settings.json", "auth.json", "mcporter.json"];

for (const name of SAMPLES) {
	test(`${name}.sample is valid JSON`, () => {
		assert.notEqual(readJson<unknown>(`${name}.sample`), undefined, `${name}.sample missing or not valid JSON`);
	});
}

test("no sample carries an ARN or the AWS account id", () => {
	const realModels = readJson<ModelsConfig>("models.json");
	const accounts = new Set(JSON.stringify(realModels ?? {}).match(/\b\d{12}\b/g) ?? []);
	for (const name of SAMPLES) {
		const raw = readText(`${name}.sample`);
		if (raw === undefined) continue;
		assert.ok(!raw.includes("arn:aws"), `${name}.sample contains a literal arn:aws`);
		for (const account of accounts) {
			assert.ok(!raw.includes(account), `${name}.sample contains account id ${account}`);
		}
	}
});

test("models.json.sample placeholders every real ARN", (t) => {
	const sample = readJson<ModelsConfig>("models.json.sample");
	const real = readJson<ModelsConfig>("models.json");
	if (!sample) return t.skip("models.json.sample unreadable");

	for (const entry of modelEntries(sample)) {
		assert.ok(!entry.id.startsWith("arn:"), `models.json.sample: ${entry.name} id is a literal ARN`);
	}
	if (!real) return t.diagnostic("models.json absent; placeholder shapes not cross-checked");

	const sampleByKey = new Map(modelEntries(sample).map((entry) => [`${entry.provider}\u0000${entry.name}`, entry]));
	for (const entry of modelEntries(real)) {
		const counterpart = sampleByKey.get(`${entry.provider}\u0000${entry.name}`);
		if (!entry.id.startsWith("arn:") || !counterpart || counterpart.id.startsWith("arn:")) continue;
		assert.match(
			counterpart.id,
			PLACEHOLDER,
			`models.json.sample: ${entry.name} id is not a <<<placeholder>>>`,
		);
	}

	// machine specific, so a difference is a note
	const realNames = new Set(modelEntries(real).map((entry) => entry.name));
	const sampleNames = new Set(modelEntries(sample).map((entry) => entry.name));
	for (const name of [...realNames].filter((n) => !sampleNames.has(n)).sort()) {
		t.diagnostic(`models.json.sample has no ${name} (fine if machine specific)`);
	}
	for (const name of [...sampleNames].filter((n) => !realNames.has(n)).sort()) {
		t.diagnostic(`models.json has no ${name} (fine if machine specific)`);
	}
});

test("models.json.sample resolves every tier an agent asks for", (t) => {
	const sample = readJson<ModelsConfig>("models.json.sample");
	if (!sample) return t.skip("models.json.sample unreadable");

	const entries = modelEntries(sample);
	const patterns = [...new Set(agentModels().map((agent) => agent.pattern))].filter(Boolean).sort();
	for (const pattern of patterns) {
		const hits = substringMatches(entries, pattern);
		assert.equal(hits.length, 1, `models.json.sample matches ${pattern} ${hits.length} times; agents cannot bootstrap`);
	}
	t.diagnostic(`models.json.sample resolves ${patterns.length} agent tier(s)`);
});

test("defaultModel is a model id, not a name or a tier", (t) => {
	// pi resolves defaultModel through Models.getModel, an `id === value` lookup with
	// no name, substring or tier handling, unlike enabledModels. A tier there is a
	// silent no-op: findInitialModel falls through to the next candidate.
	const sample = readJson<Record<string, unknown>>("settings.json.sample");
	const sampleModels = readJson<ModelsConfig>("models.json.sample");
	if (!sample || !sampleModels) return t.skip("settings.json.sample or models.json.sample unreadable");

	const sampleDefault = sample.defaultModel;
	if (typeof sampleDefault === "string") {
		const ids = new Set(modelEntries(sampleModels).map((entry) => entry.id));
		assert.ok(
			PLACEHOLDER.test(sampleDefault) || ids.has(sampleDefault),
			`settings.json.sample: defaultModel "${sampleDefault}" is neither a <<<placeholder>>> nor an id in models.json.sample`,
		);
	}

	// The lookup is getModel(defaultProvider, defaultModel), so a placeholder left in
	// either one makes the pair inert. The sample must not invite filling in one half.
	const sampleProvider = sample.defaultProvider;
	if (typeof sampleDefault === "string" && typeof sampleProvider === "string") {
		assert.equal(
			PLACEHOLDER.test(sampleProvider),
			PLACEHOLDER.test(sampleDefault),
			"settings.json.sample: defaultProvider and defaultModel must both be <<<placeholders>>> or both be real",
		);
	}

	const real = readJson<Record<string, unknown>>("settings.json");
	const realModels = readJson<ModelsConfig>("models.json");
	if (!real || !realModels) return t.diagnostic("settings.json or models.json absent; real default not cross-checked");

	const realDefault = real.defaultModel;
	if (typeof realDefault !== "string") return t.diagnostic("settings.json has no defaultModel");
	const provider = real.defaultProvider;
	assert.ok(
		typeof provider === "string" && !PLACEHOLDER.test(provider),
		"settings.json: defaultProvider is missing or still a placeholder, so defaultModel cannot resolve",
	);
	const entries = modelEntries(realModels).filter((entry) => entry.provider === provider);
	if (entries.length === 0) {
		// A built-in catalog model, which models.json does not describe.
		return t.diagnostic(`settings.json: defaultProvider "${String(provider)}" is not in models.json`);
	}
	assert.ok(
		entries.some((entry) => entry.id === realDefault),
		`settings.json: defaultModel "${realDefault}" is not an id of ${String(provider)} in models.json`,
	);
	t.diagnostic(`settings.json: defaultModel resolves to ${entries.find((entry) => entry.id === realDefault)?.name}`);
});

test("settings.json.sample tracks settings.json", (t) => {
	const sample = readJson<Record<string, unknown>>("settings.json.sample");
	if (!sample) return t.skip("settings.json.sample unreadable");
	assert.ok(!("lastChangelogVersion" in sample), "settings.json.sample should not carry lastChangelogVersion");

	const real = readJson<Record<string, unknown>>("settings.json");
	if (!real) return t.diagnostic("settings.json absent; nothing to compare");

	const strip = (value: Record<string, unknown>) =>
		Object.fromEntries(Object.entries(value).filter(([key]) => !RUNTIME_KEYS.includes(key)));
	const [a, b] = [strip(real), strip(sample)];
	const onlyOneSide = [...new Set([...Object.keys(a), ...Object.keys(b)])]
		.filter((key) => key in a !== key in b)
		.sort();
	const different = Object.keys(a)
		.filter((key) => key in b && JSON.stringify(a[key]) !== JSON.stringify(b[key]))
		.sort();
	const diff = [...onlyOneSide, ...different];
	t.diagnostic(
		diff.length
			? `settings.json.sample differs on ${diff.join(", ")} (sync if not machine specific)`
			: "settings.json.sample matches settings.json",
	);
});

test("auth.json.sample holds no real credentials", (t) => {
	const sample = readJson<unknown>("auth.json.sample");
	if (!sample) return t.skip("auth.json.sample unreadable");

	// Long strings from the real file are the values that must never appear.
	const secrets = new Set(
		leaves(readJson<unknown>("auth.json") ?? {})
			.map(([, value]) => value)
			.filter((value): value is string => typeof value === "string" && value.length > 8),
	);
	const leaked = leaves(sample)
		.filter(([path, value]) => {
			if (typeof value !== "string") return false;
			return secrets.has(value) || (SECRET_KEY.test(path) && !PLACEHOLDER.test(value));
		})
		.map(([path, value]) => `${path} (${secrets.has(value as string) ? "real value" : "not a placeholder"})`);

	assert.deepEqual(leaked, [], `auth.json.sample leaks: ${leaked.join(", ")}`);
	t.diagnostic("auth.json.sample has no real credentials");
});
