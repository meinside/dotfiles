/**
 * Shared helpers for the checks in this directory.
 *
 * `check.sh` is the entry point, but every file here also runs on its own
 * (`node --test tests/samples.test.ts`), so nothing depends on variables the
 * script exports beyond an optional cache of `brew --prefix`.
 */

import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

/** This config directory: the parent of `tests/`. */
export const CONFIG_DIR = resolve(dirname(fileURLToPath(import.meta.url)), "..");

/**
 * `brew --prefix` resolves to a version-independent symlink, so the path holds
 * across pi upgrades. `check.sh` exports it to save the subprocess.
 */
export function piPrefix(): string {
	const cached = process.env.PI_CHECK_PREFIX;
	if (cached) return cached;
	return execFileSync("brew", ["--prefix", "pi-coding-agent"], { encoding: "utf8" }).trim();
}

const PI_PACKAGE = "libexec/lib/node_modules/@earendil-works/pi-coding-agent";

/** Upstream copy of the vendored examples. */
export const upstreamExamples = (): string => join(piPrefix(), PI_PACKAGE, "examples/extensions");

/** pi's own build, imported to reuse its model resolver rather than copy it. */
export const piDist = (): string => join(piPrefix(), PI_PACKAGE, "dist");

export function readText(name: string): string | undefined {
	try {
		return readFileSync(join(CONFIG_DIR, name), "utf8");
	} catch {
		return undefined;
	}
}

export function readJson<T>(name: string): T | undefined {
	const raw = readText(name);
	if (raw === undefined) return undefined;
	try {
		return JSON.parse(raw) as T;
	} catch {
		return undefined;
	}
}

/** The parts of a `models.json`-shaped config these checks look at. */
export interface ModelDefinition {
	id?: unknown;
	name?: unknown;
	cost?: Record<string, unknown>;
}

export interface ModelsConfig {
	providers?: Record<string, { models?: ModelDefinition[] } | undefined>;
}

/** The one pi export these checks borrow, rather than reimplementing it. */
export interface PiModule {
	resolveCliModel: (options: {
		cliModel: string;
		cliProvider?: string;
		modelRuntime: unknown;
	}) => { model?: { name?: string }; thinkingLevel?: string; error?: string; warning?: string };
}

/** Thinking levels pi consumes from a trailing `:<suffix>` on a model pattern. */
export const THINKING_LEVELS = ["off", "minimal", "low", "medium", "high", "xhigh", "max"] as const;

/** Split `tier:fast:low` into the pattern pi looks up and the level it consumes. */
export function splitThinkingLevel(token: string): { pattern: string; level?: string } {
	const index = token.lastIndexOf(":");
	if (index === -1) return { pattern: token };
	const suffix = token.slice(index + 1);
	return (THINKING_LEVELS as readonly string[]).includes(suffix)
		? { pattern: token.slice(0, index), level: suffix }
		: { pattern: token };
}

export interface AgentModel {
	agent: string;
	token: string;
	pattern: string;
	level?: string;
}

/** The `model:` line of every agent definition, as pi would parse it. */
export function agentModels(): AgentModel[] {
	const dir = join(CONFIG_DIR, "agents");
	return readdirSync(dir)
		.filter((name) => name.endsWith(".md"))
		.sort()
		.map((agent) => {
			const line = readFileSync(join(dir, agent), "utf8")
				.split("\n")
				.find((candidate) => candidate.startsWith("model:"));
			const token = line ? line.slice("model:".length).trim() : "";
			return { agent, token, ...splitThinkingLevel(token) };
		});
}

export interface ModelEntry {
	provider: string;
	id: string;
	name: string;
}

/** Every named model in a `models.json`-shaped config, flattened. */
export function modelEntries(config: ModelsConfig | undefined): ModelEntry[] {
	const out: ModelEntry[] = [];
	for (const [provider, value] of Object.entries(config?.providers ?? {})) {
		for (const model of value?.models ?? []) {
			out.push({ provider, id: String(model?.id ?? ""), name: String(model?.name ?? "") });
		}
	}
	return out;
}

/** How pi matches `--model`: case-insensitive substring over id and name. */
export function substringMatches(entries: ModelEntry[], pattern: string): ModelEntry[] {
	const needle = pattern.toLowerCase();
	return entries.filter(
		(entry) => entry.id.toLowerCase().includes(needle) || entry.name.toLowerCase().includes(needle),
	);
}

/** Flatten to `[dotted.path, value]` pairs, for scanning samples leaf by leaf. */
export function leaves(value: unknown, prefix = ""): Array<[string, unknown]> {
	if (Array.isArray(value)) {
		return value.flatMap((item, index) => leaves(item, `${prefix}${index}.`));
	}
	if (value && typeof value === "object") {
		return Object.entries(value).flatMap(([key, item]) => leaves(item, `${prefix}${key}.`));
	}
	return [[prefix.replace(/\.$/, ""), value]];
}

/** pi's own modules, so the checks reuse its logic instead of approximating it. */
export async function importPi(): Promise<PiModule> {
	return (await import(pathToFileURL(join(piDist(), "index.js")).href)) as PiModule;
}
