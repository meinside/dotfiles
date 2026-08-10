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
	});
}
