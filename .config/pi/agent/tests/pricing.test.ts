/**
 * `cost` is USD per 1M tokens on the us-east-1 on-demand basis (see README,
 * "Pricing"). An application inference profile ARN hides which model it resolves
 * to, so the tier's parenthesised slug is matched against pi's own catalog
 * instead. Prices drive nothing but the footer's readout, so a difference is
 * reported and never fails: the AWS pricing page, not the catalog, is the source.
 */

import test from "node:test";
import { type ModelsConfig, readJson } from "./lib.ts";

const FIELDS = ["input", "output", "cacheRead", "cacheWrite"] as const;
/** us-east-1 is served by the bare and the us./global. prefixed catalog ids. */
const PREFIXES = ["anthropic.", "us.anthropic.", "global.anthropic."];

type Cost = Record<string, unknown>;

/** Every `{ id, cost }` pair anywhere in pi's generated catalog. */
function catalogCosts(node: unknown, out = new Map<string, Cost>()): Map<string, Cost> {
	if (Array.isArray(node)) {
		for (const value of node) catalogCosts(value, out);
	} else if (node && typeof node === "object") {
		const record = node as Record<string, unknown>;
		const cost = record.cost;
		if (record.id && cost && typeof cost === "object" && !out.has(String(record.id))) {
			out.set(String(record.id), cost as Cost);
		}
		for (const value of Object.values(record)) catalogCosts(value, out);
	}
	return out;
}

const number = (value: unknown): number => Number(value ?? 0);

test("bedrock prices agree with pi's catalog", (t) => {
	const catalog = readJson<unknown>("models-store.json");
	const real = readJson<ModelsConfig>("models.json");
	if (!catalog || !real) return t.skip("models-store.json or models.json unreadable");

	const costs = catalogCosts(catalog);
	const models = real.providers?.["amazon-bedrock"]?.models ?? [];
	for (const model of models) {
		const slug = /\(([^)]+)\)/.exec(String(model?.name ?? ""))?.[1];
		const mine = model?.cost;
		if (!slug || !mine) continue;

		const hit = [...costs.keys()].sort().find((id) => PREFIXES.some((prefix) => id.startsWith(prefix + slug)));
		if (!hit) {
			t.diagnostic(`${slug}: not in pi's catalog; verify against the AWS pricing page`);
			continue;
		}
		const theirs = costs.get(hit) ?? {};
		const off = FIELDS.filter((field) => Math.abs(number(mine[field]) - number(theirs[field])) > 1e-9);
		t.diagnostic(
			off.length
				? `${slug}: differs from catalog on ${off.map((f) => `${f} ${mine[f]} vs ${theirs[f]}`).join(", ")}`
				: `${slug} ${FIELDS.map((f) => mine[f]).join("/")} per 1M`,
		);
	}
});
