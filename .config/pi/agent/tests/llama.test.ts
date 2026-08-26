/**
 * The llama.cpp router config lives outside this directory
 * (`${XDG_CONFIG_HOME:-~/.config}/llama.cpp/`, which is where every llama.cpp
 * binary looks by itself), but three of its invariants are only checkable
 * together with `models.json` and `settings.json`, and all three fail silently:
 *
 * - a `modelOverrides` key that does not match a router model id is *ignored*, so
 *   the thinking/sampling config for that model quietly disappears;
 * - a preset section with no model source is listed by `GET /models` and only
 *   fails when something tries to load it;
 * - an `enabledModels` pattern that matches nothing simply hides the model from
 *   `/model`, which looks like a broken server rather than a bad glob. `*` does
 *   not cross `/` in minimatch, and llama.cpp model ids are `<repo>/<name>:<quant>`,
 *   so `llama.cpp/*` matches nothing while `llama.cpp/**` matches everything.
 *
 * Whether this machine uses llama.cpp at all is machine specific, so a missing
 * config directory skips. Everything the files do assert is a fixed invariant:
 * no secrets, no absolute paths (the ini parser expands neither `~` nor `$VARS`,
 * so a path there would pin the file to one machine), and the cross-file links.
 */

import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import test from "node:test";
import { importPi, type ModelsConfig, readJson } from "./lib.ts";

const LLAMA_PROVIDER = "llama.cpp";

/** Mirrors llama.cpp's own `fs_get_config_directory()` (common/common.cpp). */
const llamaConfigDir = (): string =>
	join(process.env.XDG_CONFIG_HOME?.trim() || join(homedir(), ".config"), "llama.cpp");

const iniPath = (name: string): string => join(llamaConfigDir(), name);

interface Ini {
	/** section name -> key -> value; the global section is `*`. */
	sections: Map<string, Map<string, string>>;
	/** Only the lines that carry settings, comments stripped. */
	settingLines: string[];
}

/**
 * Enough of llama.cpp's preset format to check it: `[section]` headers,
 * `key = value` pairs, `;` comments. Values are kept verbatim.
 */
function parseIni(text: string): Ini {
	const sections = new Map<string, Map<string, string>>();
	const settingLines: string[] = [];
	let current = "*";
	for (const raw of text.split("\n")) {
		const line = raw.trim();
		if (!line || line.startsWith(";") || line.startsWith("#")) continue;
		const header = /^\[(.+)]$/.exec(line);
		if (header) {
			current = header[1];
			if (!sections.has(current)) sections.set(current, new Map());
			continue;
		}
		const eq = line.indexOf("=");
		if (eq === -1) continue;
		settingLines.push(line);
		if (!sections.has(current)) sections.set(current, new Map());
		sections.get(current)?.set(line.slice(0, eq).trim(), line.slice(eq + 1).trim());
	}
	return { sections, settingLines };
}

function readIni(name: string): Ini | undefined {
	const path = iniPath(name);
	if (!existsSync(path)) return undefined;
	try {
		return parseIni(readFileSync(path, "utf8"));
	} catch (error) {
		// pi-sandbox denies reads outside its allowRead list, so an agent session can
		// see the file exist and still not open it. Report that rather than failing:
		// the same run from a plain shell checks it for real.
		unreadable.set(name, error instanceof Error ? error.message : String(error));
		return undefined;
	}
}

/** name -> why it could not be read, for the skip messages below. */
const unreadable = new Map<string, string>();

/** Model sections are every section except the global one. */
const modelSections = (ini: Ini): Map<string, Map<string, string>> =>
	new Map([...ini.sections].filter(([name]) => name !== "*" && name !== "default"));

const models = readIni("models.ini");
const config = readIni("config.ini");

/** Skip reason shared by every check that needs a file it could not read. */
const blocked = (name: string): string | undefined => {
	const reason = unreadable.get(name);
	return reason ? `${name} exists but could not be read (${reason}); add ~/.config/llama.cpp to sandbox.json allowRead` : undefined;
};

test("llama.cpp config is present", (t) => {
	for (const name of ["config.ini", "models.ini"]) {
		const reason = blocked(name);
		if (reason) return t.skip(reason);
	}
	if (!models && !config) {
		return t.skip(`no llama.cpp config in ${llamaConfigDir()} (fine if this machine does not run it)`);
	}
	assert.ok(config, `config.ini missing from ${llamaConfigDir()} while models.ini is there`);
	assert.ok(models, `models.ini missing from ${llamaConfigDir()} while config.ini is there`);
	t.diagnostic(`${modelSections(models).size} model preset(s) in ${iniPath("models.ini")}`);
});

for (const [name, ini] of [
	["config.ini", config],
	["models.ini", models],
] as const) {
	test(`${name} stays machine-independent and secret-free`, (t) => {
		if (!ini) return t.skip(blocked(name) ?? `${name} absent`);

		// The preset parser has no ~ or $VAR expansion and resolves relative paths
		// against the server's CWD, so any path here would be machine specific. Model
		// artifacts are named by HF repo or URL instead, and the preset file's own
		// location comes from $LLAMA_ARG_MODELS_PRESET, expanded by the shell.
		const paths = ini.settingLines.filter((line) => /(^|[\s=])[~/]|\/(Users|home)\//.test(line));
		assert.deepEqual(paths, [], `${name} carries a filesystem path: ${paths.join(", ")}`);

		// --api-key belongs in $LLAMA_API_KEY (~/.custom_env, untracked), which
		// llama-server and pi both read, not in a tracked config file.
		const secrets = ini.settingLines.filter((line) => /^(api[-_]key|LLAMA_API_KEY)\s*=/i.test(line));
		assert.deepEqual(secrets, [], `${name} carries a secret: ${secrets.join(", ")}`);
	});
}

test("every models.ini preset names a model source", (t) => {
	if (!models) return t.skip(blocked("models.ini") ?? "models.ini absent");
	const sections = modelSections(models);
	if (sections.size === 0) return t.diagnostic("models.ini defines no model presets");

	// A section whose name is not already a cached model needs `hf-repo` (or a
	// `model` path) of its own; without one the router still lists it and the load
	// fails later. See tools/server/README.md, "Model presets".
	for (const [name, keys] of sections) {
		const hasSource = ["hf-repo", "model", "hf-file", "docker-repo"].some((key) => keys.has(key));
		assert.ok(hasSource, `models.ini [${name}] names no model source (hf-repo/model), so loading it fails`);
	}
	t.diagnostic(`${sections.size} preset(s) carry a model source`);
});

test("models.json overrides match models.ini preset names", (t) => {
	if (!models) return t.skip(blocked("models.ini") ?? "models.ini absent");
	const real = readJson<Record<string, unknown>>("models.json");
	const provider = (real?.providers as Record<string, { modelOverrides?: Record<string, unknown> }> | undefined)?.[
		LLAMA_PROVIDER
	];
	const overrides = Object.keys(provider?.modelOverrides ?? {});
	if (overrides.length === 0) return t.skip(`models.json defines no ${LLAMA_PROVIDER} modelOverrides`);

	// pi matches modelOverrides by exact model id and ignores unknown ids, so a
	// typo here silently drops reasoning/thinking/sampling for that model. The
	// router names a model after the preset section it came from.
	const sections = [...modelSections(models).keys()];
	for (const id of overrides) {
		assert.ok(
			sections.includes(id),
			`models.json overrides "${id}", which is no models.ini section (${sections.join(", ") || "none"}); pi would ignore it`,
		);
	}
	t.diagnostic(`${overrides.length} override(s) matched to a preset`);
});

test("enabledModels reaches the llama.cpp models", async (t) => {
	if (!models) return t.skip(blocked("models.ini") ?? "models.ini absent");
	const settings = readJson<{ enabledModels?: string[] }>("settings.json");
	const patterns = settings?.enabledModels;
	if (!patterns?.length) return t.skip("settings.json defines no enabledModels (nothing is filtered)");

	const ids = [...modelSections(models).keys()];
	if (ids.length === 0) return t.diagnostic("models.ini defines no model presets");

	// Ask pi's own resolver, so this cannot drift from dist/core/model-resolver.js.
	// Only loaded models reach /model, so the ids come from the presets instead.
	const { resolveModelScopeWithDiagnostics } = (await importPi()) as unknown as {
		resolveModelScopeWithDiagnostics: (
			patterns: string[],
			modelRuntime: unknown,
		) => Promise<{ scopedModels: Array<{ model: { provider: string; id: string } }> }>;
	};
	const catalog = ids.map((id) => ({ provider: LLAMA_PROVIDER, id, name: id, reasoning: false }));
	const { scopedModels } = await resolveModelScopeWithDiagnostics(patterns, {
		getAvailable: async () => catalog,
	});

	const reached = new Set(scopedModels.filter((s) => s.model.provider === LLAMA_PROVIDER).map((s) => s.model.id));
	const missing = ids.filter((id) => !reached.has(id));
	assert.deepEqual(
		missing,
		[],
		`enabledModels (${patterns.join(", ")}) matches no pattern for ${missing.join(", ")}: ` +
			`llama.cpp ids contain "/", and minimatch's "*" does not cross it — use "${LLAMA_PROVIDER}/**"`,
	);
	t.diagnostic(`${reached.size} llama.cpp model(s) reachable through enabledModels`);
});

test("config.ini pins the router's listener", (t) => {
	if (!config) return t.skip(blocked("config.ini") ?? "config.ini absent");
	const global = config.sections.get("*") ?? config.sections.get("default") ?? new Map();
	const port = global.get("port");
	const host = global.get("host");

	// Not a correctness requirement, but an unpinned port silently moves when
	// llama.cpp changes its default (8080 -> 9931, PR #26508) and pi keeps asking
	// the old one, so record what is pinned.
	t.diagnostic(port ? `router pinned to ${host ?? "(default host)"}:${port}` : "no port pinned in config.ini");
	if (host !== undefined) {
		assert.equal(host, "127.0.0.1", `config.ini exposes the router on ${host}; it has no auth by default`);
	}

	const stored = readJson<Record<string, { env?: Record<string, string> }>>("auth.json")?.[LLAMA_PROVIDER]?.env
		?.LLAMA_BASE_URL;
	if (!stored || !port) return;
	// pi prefers the URL stored by /login over $LLAMA_BASE_URL, so a port change
	// here needs a re-login; the mismatch is otherwise invisible until a request.
	t.diagnostic(
		stored.includes(`:${port}`)
			? `auth.json agrees with config.ini on :${port}`
			: `auth.json still points at ${stored} while config.ini pins :${port} — re-run /login ${LLAMA_PROVIDER}`,
	);
});
