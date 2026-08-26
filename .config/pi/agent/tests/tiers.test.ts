/**
 * Every agent must pin a tier token that pi resolves to exactly one model.
 *
 * pi matches `--model` as a case-insensitive substring over id and name, and an
 * ambiguous match is *not* an error: it sorts the matches by id and silently
 * takes the highest one. So this checks uniqueness itself, then asks pi's own
 * resolver what it would pick and asserts the two agree. That way the local
 * matching rule cannot rot away from `dist/core/model-resolver.js` unnoticed:
 * a disagreement fails instead of passing quietly.
 */

import assert from "node:assert/strict";
import test from "node:test";
import { agentModels, importPi, type ModelsConfig, modelEntries, readJson, substringMatches } from "./lib.ts";

const real = readJson<ModelsConfig>("models.json");
const entries = modelEntries(real);

test("models.json defines named models", () => {
	assert.ok(entries.length > 0, "models.json unreadable or defines no named models");
	assert.ok(
		entries.every((entry) => entry.name.length > 0),
		"every model needs a name; the tier token lives in it",
	);
});

/** pi's resolver only needs these members of the runtime. */
function modelRuntime() {
	const models = entries.map((entry) => ({ ...entry, reasoning: true }));
	return {
		getModel: (provider: string, id: string) => models.find((m) => m.provider === provider && m.id === id),
		getModels: () => models,
		getAvailableSnapshot: () => models,
		getAllSnapshot: () => models,
		hasConfiguredAuth: () => true,
		getProviders: () => [...new Set(models.map((m) => m.provider))].map((id) => ({ id })),
	};
}

for (const { agent, token, pattern, level } of agentModels()) {
	test(`${agent} -> ${pattern}${level ? ` (thinking ${level})` : ""}`, async (t) => {
		assert.notEqual(token, "", `${agent} has no model: line (would fall back to defaultModel)`);

		const hits = substringMatches(entries, pattern);
		assert.equal(
			hits.length,
			1,
			hits.length === 0
				? `${pattern} is not defined in models.json`
				: `${pattern} matches ${hits.length} models (${hits.map((h) => h.name).join(", ")}); pi would silently take the highest id`,
		);

		const { resolveCliModel } = await importPi();
		const resolved = resolveCliModel({ cliModel: token, modelRuntime: modelRuntime() });
		assert.equal(resolved.error, undefined, `pi rejected ${token}: ${resolved.error}`);
		assert.equal(
			resolved.model?.name,
			hits[0].name,
			`pi resolves ${token} to ${resolved.model?.name}, not the single match ${hits[0].name}`,
		);
		assert.equal(resolved.thinkingLevel, level, `pi reads a thinking level of ${resolved.thinkingLevel}`);
		if (!level) t.diagnostic(`${agent} inherits settings.json defaultThinkingLevel`);
		t.diagnostic(`${pattern} -> ${hits[0].provider}/${hits[0].id}`);
	});
}

/**
 * What a tier token resolves to is machine specific, so this reports rather than
 * asserts — but reporting it here is what keeps it out of README.md, where it would
 * be a copy that silently rots the next time a tier points at a different model.
 */
test("tier tokens and their models", (t) => {
	const tokens = [...new Set(entries.map((entry) => entry.name.split(" ")[0]).filter((name) => name.startsWith("tier:")))]
		.sort();
	for (const token of tokens) {
		const hits = substringMatches(entries, token);
		const shown = hits.map((hit) => `${hit.provider}/${hit.id}`).join(", ");
		t.diagnostic(hits.length === 1 ? `${token} -> ${shown}` : `${token} -> AMBIGUOUS: ${shown}`);
	}

	// Every mistyped tier ends up here: a trailing thinking level is stripped off, so
	// `tier:high` degrades to the pattern `tier`, which matches every entry. pi then
	// sorts by id and takes the highest, with no warning.
	const all = substringMatches(entries, "tier");
	const winner = [...all].sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0)).at(-1);
	t.diagnostic(
		`a mistyped tier (pattern "tier", ${all.length} matches) silently resolves to ${winner?.provider}/${winner?.id}`,
	);

	// Tokens that share a prefix can never be pinned by that prefix: the shorter form
	// substring-matches both and pi again takes the higher id. The dangerous form is
	// usually one nobody defined (`tier:local` behind `tier:local-fast`/`-strong`), so
	// derive the candidates from the tokens' own `-` boundaries.
	const reported = new Set<string>();
	for (const token of tokens) {
		for (let cut = token.indexOf("-"); cut !== -1; cut = token.indexOf("-", cut + 1)) {
			const prefix = token.slice(0, cut);
			if (reported.has(prefix)) continue;
			const hits = substringMatches(entries, prefix);
			if (hits.length > 1) {
				reported.add(prefix);
				t.diagnostic(
					`"${prefix}" is a shared prefix of ${hits.length} models (${hits.map((h) => h.name).join(", ")}): never pin it`,
				);
			}
		}
	}
});
