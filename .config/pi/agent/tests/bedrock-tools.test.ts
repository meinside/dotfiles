/**
 * Claude on Bedrock Converse rejects a strict tool schema, so this config must not
 * claim it does. pi asks for strict sampling on its built-in tools, and the Bedrock
 * adapter then adds `strict: true` to each `toolSpec`, which newer Claude models
 * reject before any tool runs:
 *
 *   Validation error: The model returned the following errors:
 *   tools.0.custom.strict: Extra inputs are not permitted
 *
 * Support splits by model, not family, and an application inference profile ARN hides
 * which model answers (and can be repointed without this file changing), so it is off
 * for every Claude here. pi's catalog marks these models strict-capable, so the config
 * says `supportsStrictMode: false` explicitly instead of relying on the adapter's
 * `?? false` default: an absent key would silently turn true if that default moved,
 * and fail every turn. This test asserts the part that breaks and reports the rest.
 *
 * Scoped to Claude, matched the way pi's adapter decides Anthropic-ness, because the
 * flag is honest for other families on Bedrock (Nova, the OpenAI models).
 */

import assert from "node:assert/strict";
import test from "node:test";
import { type ModelsConfig, readJson } from "./lib.ts";

const BEDROCK_CONVERSE = "bedrock-converse-stream";

/** `isAnthropicClaudeModel` in pi's Bedrock adapter, applied to a config entry. */
function isClaude(model: { id?: unknown; name?: unknown }): boolean {
	const id = String(model.id ?? "").toLowerCase();
	const name = String(model.name ?? "").toLowerCase();
	return id.includes("anthropic.claude") || id.includes("anthropic/claude") || name.includes("claude");
}

for (const file of ["models.json", "models.json.sample"]) {
	test(`${file}: no Claude on Bedrock claims strict tool support`, (t) => {
		const config = readJson<ModelsConfig>(file);
		if (!config) return t.skip(`${file} unreadable`);

		const offenders: string[] = [];
		const implicit: string[] = [];
		let checked = 0;
		for (const [providerId, provider] of Object.entries(config.providers ?? {})) {
			// A provider-level compat reaches every model under it, so it counts too.
			const providerStrict = (provider as { compat?: { supportsStrictMode?: unknown } }).compat?.supportsStrictMode;
			for (const model of (provider as { models?: Record<string, unknown>[] }).models ?? []) {
				const api = String(model.api ?? (provider as { api?: unknown }).api ?? "");
				if (api !== BEDROCK_CONVERSE || !isClaude(model)) continue;
				checked++;
				const strict = (model.compat as { supportsStrictMode?: unknown } | undefined)?.supportsStrictMode ?? providerStrict;
				const label = `${providerId}/${String(model.name ?? model.id)}`;
				if (strict === true) offenders.push(label);
				else if (strict === undefined) implicit.push(label);
			}
		}

		assert.deepEqual(
			offenders,
			[],
			`${file}: supportsStrictMode is true for Claude on ${BEDROCK_CONVERSE}, which fails every turn with "tools.0.custom.strict: Extra inputs are not permitted": ${offenders.join(", ")}`,
		);
		t.diagnostic(
			`${checked} Claude model(s) on ${BEDROCK_CONVERSE} leave strict tools off` +
				(implicit.length ? `; relying on the adapter default: ${implicit.join(", ")}` : "; all say so explicitly"),
		);
	});
}
