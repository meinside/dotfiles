/**
 * Claude on Bedrock Converse rejects a strict tool schema, so this config must not
 * claim it does.
 *
 * Observed on this machine after updating to pi 0.86.1, on the first tool call of
 * every turn:
 *
 *   Validation error: The model returned the following errors:
 *   tools.0.custom.strict: Extra inputs are not permitted
 *
 * The path names the mechanism. pi 0.86.0 turned on strict-prefer JSON-schema
 * sampling for the built-in `read`, `bash`, `edit` and `write` tools, which had
 * needed `PI_EXPERIMENTAL` before (0.84.2), to stop newer Claude models inventing
 * fields in `edit` arguments (pi#6278). The flag below had been here since 0.82.0
 * doing nothing, because nothing asked for strict; once something did, the Bedrock
 * adapter started adding `strict: true` to each `toolSpec` (`convertToolConfig`).
 *
 * Anthropic's own API does accept `strict`, as a top-level sibling of `input_schema`.
 * Bedrock Converse carries it on `toolSpec` instead, and when it maps that onto the
 * native `custom` tool shape the newer models' validator rejects the extra key - so
 * the turn fails before any tool runs. This is not pi-specific: LiteLLM has it from
 * three reporters (BerriAI/litellm#31582, #33193, #38799), including for a
 * cross-region inference profile id, which is the shape used here.
 *
 * Per those reports the capability splits by model, not by family: Opus 4.5 and
 * Sonnet 4.5/4.6 accept `toolSpec.strict` while Opus 4.7/4.8, Sonnet 5 and Fable
 * reject it. This config turns it off for every Claude here anyway, because an
 * application inference profile ARN hides which model answers and can be repointed
 * without this file changing. Re-enabling one would need a live call to prove it.
 *
 * pi fixed the same class of bug for Cerebras in 0.86.1 (pi#9804) by dropping the
 * unsupported claim; this is that, for Bedrock.
 *
 * pi's generated catalog does mark `anthropic.claude-*` on Bedrock as strict-capable,
 * and `pi-ai/README.md` says custom Bedrock models may override that. An application
 * inference profile ARN is such a model, and `strict: "prefer"` degrades to an ordinary
 * function tool rather than failing, so turning it off costs nothing observable.
 *
 * The config says `supportsStrictMode: false` rather than dropping `compat`, which the
 * adapter treats identically today (`?? false`). The difference is what happens when
 * that default moves: `docs/models.md` says strict defaults "depend on the API", and the
 * catalog already claims true for these models, so an absent key could silently become
 * true again and fail every turn, while a stale `false` only forgoes an optimisation.
 * This test asserts the part that breaks and reports the rest.
 *
 * Scoped to Claude rather than to Bedrock as a whole because the flag is honest for
 * other families there (Nova, the OpenAI models), and pi decides Anthropic-ness the
 * same way: an id or name containing `anthropic.claude` or a name containing `claude`.
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
