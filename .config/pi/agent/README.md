# pi coding agent config

Config directory for [pi](https://github.com/earendil-works/pi-mono) (`pi-coding-agent`).

**pi does not support XDG paths.** `getAgentDir()` (`dist/config.js`) returns
`$PI_CODING_AGENT_DIR` if set, otherwise `~/.pi/agent`. This directory is used
only because `~/.zshrc` exports it:

```bash
export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"
```

Without that variable pi ignores everything here. Upstream docs say
`~/.pi/agent`; read that as "this directory".

## Files

| Path | Tracked in dotfiles | Purpose |
|------|---------------------|---------|
| `settings.json` | `.sample` mirror | Theme, default model, `enabledModels` for `Ctrl+P` cycling. Holds no secrets since it references tiers instead of ARNs |
| `models.json` | `.sample` only | Providers, models and the tier aliases. Holds the AWS account ID inside Bedrock inference profile ARNs, hence the `.sample` indirection |
| `auth.json` | `.sample` template | Credentials. Never commit the real file. The sample is a **template**, not a mirror: it documents providers (such as `google`) that may not be configured here |
| `models-store.json` | no | Generated model catalog cache. Do not edit or commit. `check.sh` reads it to cross-check prices |
| `pi-lsp.json` | yes | Language server routes for the `@narumitw/pi-lsp` extension. No secrets or machine-specific paths, so it is committed as-is |
| `npm/` | no | `pi install` target. Ships its own `.gitignore` containing `*` |
| `extensions/subagent/` | yes | Vendored subagent extension |
| `agents/*.md` | yes | Subagent definitions, read by the subagent extension |
| `prompts/*.md` | yes | Prompt templates, invoked as `/name` in the editor |
| `check.sh` | yes | Verifies the vendored files, the agent tiers, the samples and the LSP servers |

`~/.gitignore` ignores `.config/` wholesale, so tracked files here were added with
`git add -f`. Files holding secrets or machine-specific values are committed as
`<name>.sample` with `<<<placeholder>>>` markers, matching the convention already
used for `.config/claude`, `.config/git`, etc.

## Vendored subagent extension

pi intentionally ships **no built-in sub-agents** (`docs/usage.md`, "Design
Principles"). Tiered model usage — cheap model for recon, strong model for
planning and review — comes from the upstream `subagent` example extension,
vendored here.

- **Upstream repo:** <https://github.com/earendil-works/pi-mono>
- **Upstream path:** `packages/coding-agent/examples/extensions/subagent/`
- **Local copy of upstream:** `$(brew --prefix pi-coding-agent)/libexec/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/subagent/` (`brew --prefix` resolves to a version-independent symlink, so this path survives pi upgrades)
- **Vendored from:** pi 0.83.0

The extension registers a `subagent` tool that spawns a **separate `pi` process**
per delegation (`index.ts`: `args.push("--model", agent.model)`), giving each
agent an isolated context window. Agents are discovered from `agents/*.md` by
`agents.ts`.

### Agents

| Agent | Tier | Upstream model | Tools | Role |
|-------|------|----------------|-------|------|
| `scout` | `tier:fast` | `claude-haiku-4-5` | read, grep, find, ls, bash | Fast recon, returns compressed context |
| `planner` | `tier:strong` | `claude-sonnet-4-5` | read, grep, find, ls | Produces an implementation plan, makes no changes |
| `reviewer` | `tier:strong` | `claude-sonnet-4-5` | read, grep, find, ls, bash | Code review, read-only bash |
| `worker` | `tier:mid` | `claude-sonnet-4-5` | all | Performs the actual implementation |

The `Upstream model` column is what the example ships; it is the only local edit
in these files and is what to re-apply after an upstream update.

The tiering follows the convention visible across large public subagent
collections (wshobson/agents, VoltAgent/awesome-claude-code-subagents,
@vigolium/piolium): cheap model for lookup and recon, mid model for
implementation, top model for architecture, review and adversarial verification.
The economics agree — reviewers and planners read a lot and write little, so an
expensive model costs little there, while an implementer emits many output tokens,
where the same model costs the most. Do not "upgrade" `worker` to the top model;
upgrade `planner` instead so `worker` needs less rework.

An agent without a `model:` line does **not** track the parent session's current
model. `index.ts` only appends `--model` when the agent declares one, and the
child `pi` then resolves its own default from `settings.json` `defaultModel`.
`PI_MODEL` / `PI_PROVIDER` are exported to bash-tool commands only and are never
read back as input, so switching models with `/model` in the parent has no effect
on such an agent. Every agent here therefore pins a tier explicitly.

### Workflow prompt templates

| Command | Chain |
|---------|-------|
| `/implement <task>` | scout → planner → worker |
| `/scout-and-plan <task>` | scout → planner (no implementation) |
| `/implement-and-review <task>` | worker → reviewer → worker |

Ad-hoc delegation also works (`Use scout to find all authentication code`,
`Run 2 scouts in parallel: ...`; max 8 tasks, 4 concurrent, `Ctrl+O` expands
output and per-step cost).

### Updating the vendored files

The vendored files are byte-identical to upstream except the `model:` lines. That
is deliberate: a clean `diff` is the update-detection mechanism, which is why no
provenance comments or extra frontmatter keys are added to them.

```bash
~/.config/pi/agent/check.sh      # -v to print the diffs
```

The comparison ignores `model:` lines, so the tier pins are expected and there are
no diff counts to keep in sync. Run it after every `brew upgrade
pi-coding-agent`, and before committing a change to this directory.

When it reports drift:

```bash
U="$(brew --prefix pi-coding-agent)"/libexec/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/subagent
C=~/.config/pi/agent

diff -u $C/extensions/subagent/index.ts $U/index.ts   # inspect first

cp $U/index.ts $U/agents.ts $C/extensions/subagent/
cp $U/prompts/*.md $C/prompts/
cp $U/agents/*.md $C/agents/                          # then re-apply the tiers
                                                      # from the Agents table
~/.config/pi/agent/check.sh
```

Then bump "Vendored from" above.

If a pi session is running while upgrading, disable Homebrew's cleanup so the
Cellar directory the running process started from stays in place:

```bash
HOMEBREW_NO_INSTALL_CLEANUP=1 brew upgrade pi-coding-agent
brew cleanup pi-coding-agent    # after the session ends
```

## Model tiers

Agents and `settings.json` never name a concrete model. They reference role
tokens embedded in the `name` of a `models.json` entry:

| Token | Meaning | Current model |
|-------|---------|---------------|
| `tier:fast` | Cheap, mechanical lookup and recon | `claude-haiku-4-5` |
| `tier:mid` | Default implementation model | `claude-sonnet-5` |
| `tier:strong` | Architecture, review, adversarial verification | `claude-opus-5` |
| `tier:fable` | Experimental top-end model, no agent uses it | `claude-fable-5` |
| `tier:local` | Local Ollama model, zero cost | `gemma4-e4b` |

Only `models.json` knows which provider and model a tier resolves to, so a
machine with entirely different providers needs no changes anywhere else.

Bedrock (this machine):

```json
{ "id": "arn:aws:bedrock:...:application-inference-profile/...",
  "name": "tier:strong (claude-opus-5)" }
```

Direct Anthropic — no custom model needed, just attach the alias to a built-in
model with `modelOverrides`:

```json
{ "providers": { "anthropic": { "modelOverrides": {
    "claude-opus-4-5":   { "name": "tier:strong (claude-opus-4.5)" },
    "claude-sonnet-4-5": { "name": "tier:mid (claude-sonnet-4.5)" },
    "claude-haiku-4-5":  { "name": "tier:fast (claude-haiku-4.5)" }
} } } }
```

Local-only machine:

```json
{ "id": "qwen3-coder:30b", "name": "tier:strong (qwen3-coder-30b)" }
{ "id": "gemma4:e4b",      "name": "tier:mid (gemma4-e4b)" }
```

### Pricing

`cost` is **USD per 1M tokens**, and the reference is always the
[AWS Bedrock pricing page](https://aws.amazon.com/bedrock/pricing/) for
**us-east-1, on-demand**. `cacheWrite` is the 5-minute cache write price,
`cacheRead` the cache hit price. Update these whenever a tier points at a new
model; they only drive the footer's cost readout, so a stale value is silently
wrong rather than broken.

Why us-east-1 specifically: an application inference profile hides which model and
region it resolves to, so the numbers need one fixed basis. Bedrock prices the
`us.` and `global.` cross-region profiles the same as us-east-1, while `eu.` and
`au.` run about 10% higher — do not chase those, keep the file on the us-east-1
basis.

AWS's Price List API (`pricing.us-east-1.amazonaws.com/.../AmazonBedrock/...`) is
not a usable source here: it still only carries Claude 2 and Claude 3 era models,
so the pricing page is authoritative. `check.sh` cross-checks the values against
pi's own catalog (`models-store.json`, which covers current models) and reports
differences as notes.

### Rules the tokens must obey

From pi's resolver (`dist/core/model-resolver.js`). `check.sh` enforces
the first two:

- **Unique.** `--model` falls back to a case-insensitive substring match over id
  and name. An ambiguous substring is **not** an error: pi sorts the matches by id
  and silently takes the highest one. `--model bedrock-claude` used to resolve to
  the most expensive model this way.
- **Never a thinking level.** A trailing `:<suffix>` is read as a thinking level
  when it is one of `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`, so
  `tier:high` would mean "model `tier`, thinking high". `fast` / `mid` / `strong`
  / `fable` / `local` are safe.
- The colon itself is fine. Full-pattern matching happens before the colon split,
  which is also why Ollama ids such as `gemma4:e4b` work.

A wrong token behaves differently depending on where it is used:

| Path | Unmatched `tier:typo` |
|------|----------------------|
| `--model` (agents, CLI) | Hard error, no fallback — strict mode exists precisely to avoid resolving to a different model |
| `enabledModels` / `--models` | Warns `Invalid thinking level "typo"` at startup, then matches the `tier` prefix and scopes the wrong model |

`settings.json` patterns are intentionally **not** validated by the script: that
would mean reimplementing globs, `provider/id` handling and thinking-level
parsing, which rots as pi changes. pi already warns about unmatched scope
patterns on startup.

## Sample files

The real `settings.json` / `models.json` / `auth.json` are untracked; a fresh
clone starts from the committed `.sample` files. What `check.sh` enforces is that
the samples parse, that a fresh machine can bootstrap (every tier an agent asks
for resolves exactly once in `models.json.sample`), and that no sample carries an
ARN, an AWS account id or a value taken from the real `auth.json`.

Samples are **not** required to mirror the real config. Which providers and models
a machine has is machine specific, so an entry present on only one side is
reported as a note, not a failure — the same for a differing `settings.json` key.
Treat those notes as a reminder to sync when the difference was not intentional.

- `models.json.sample` is generated from the real file by replacing each Bedrock
  ARN with its `<<<...>>>` placeholder, keyed on the tier name. Regenerate it
  whenever a model is added or a tier is renamed.
- `settings.json.sample` tracks `settings.json` minus the two keys pi rewrites at
  runtime: `lastChangelogVersion` (on upgrade) and `defaultThinkingLevel` (on the
  in-session toggle). The sample holds the intended starting level, not whatever
  the last session was left on.
- `auth.json.sample` is maintained by hand as a template.

## Language servers (pi-lsp)

`settings.json` lists `npm:@narumitw/pi-lsp` under `packages`, and pi installs
missing packages into `npm/` on first launch (unless `PI_OFFLINE` is set), so a
fresh machine needs no manual step. It adds `lsp_diagnostics`, `lsp_fix` and
`/lsp`.

`pi-lsp.json` **replaces** pi-lsp's built-in catalog, and it is deliberately a
superset of what any single machine has installed: the file stays identical
everywhere, servers come from mason so the binary is shared with neovim, and
`check.sh` reports what is missing here. That is safe because an entry whose
command is absent stays inert until a call includes a file matching its
extensions — the catch is that it then aborts that whole call, losing the other
servers' results too, since the "skipped unavailable server" pre-check only
applies to catalog defaults. So the risk is not an unused language, it is a
language used here whose server was never installed.

- **`check.sh` separates the two states.** A server missing from `PATH` is a
  note, not a failure, since the file is machine independent. A server that is
  on `PATH` but cannot exec *is* a failure: mason wrappers hardcode the asdf
  interpreter present at install time (`ruby-lsp`, `fennel-ls`), so an asdf
  upgrade leaves them installed but dead with exit 126, in neovim too. Reinstall
  the server through mason.
- **`pushDiagnosticsGraceMs`** on the push-only servers stops a clean file from
  waiting out the full `timeout`.
- **Ruby needs both servers**: `ruby-lsp` gives parse errors only, `rubocop --lsp`
  the style layer. `clojure-lsp` embeds clj-kondo and needs no companion.
- **biome lints but does not typecheck**, so `.ts` type errors are uncovered; add
  `vtsls` if that ever matters. Its extension list omits `.json` on purpose, to
  leave JSON a single route through `vscode-json-language-server`. Python is
  split the same way as Ruby: `ruff` for lint, `ty` for types.
- **`lsp_fix` only really works for gopls** (`source.organizeImports`). rubocop
  exposes autocorrect as per-diagnostic quickfixes and biome marks most fixes
  *unsafe*, both of which `source.fixAll` skips: use `rubocop -a` and
  `biome check --write`.

## Ollama provider

`models.json` registers a local Ollama provider. Non-obvious bits:

- `apiKey` is a dummy string. Ollama ignores it, but pi hides models with no
  configured auth, so the placeholder is required.
- `compat.supportsDeveloperRole: false` — Ollama rejects the `developer` role, so
  the system prompt must go out as `system`.
- `gemma4:e4b` is the **GGUF** tag, chosen over `gemma4:e4b-mlx` on purpose:
  - The MLX runner is text-only. It advertises vision/audio in the registry
    manifest, but the runtime drops the image and the model only sees an
    `[img-0]` placeholder. Ollama issues
    [#16700](https://github.com/ollama/ollama/issues/16700),
    [#17065](https://github.com/ollama/ollama/issues/17065); pending PRs
    [#17487](https://github.com/ollama/ollama/pull/17487),
    [#17600](https://github.com/ollama/ollama/pull/17600).
  - MLX generation collapses as context grows (measured here: 38 tok/s at short
    context, 17-20 tok/s at 4-16k), while GGUF holds a flat ~29.5 tok/s.
- Verified on the GGUF tag: vision, streaming and parallel tool calls,
  tool-result round-trips, thinking combined with tool calls.

If MLX vision lands upstream, re-benchmark before switching, and add `"image"` to
the model's `input` only after confirming it at runtime.

## New machine setup

1. `export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"` must be active
   (already in `~/.zshrc`). Without it pi reads `~/.pi/agent` instead.
2. `brew install pi-coding-agent`
3. Clone the dotfiles repo — brings `extensions/`, `agents/`, `prompts/`,
   `check.sh`, this README and the `.sample` files.
4. Create the real config from the samples:
   ```bash
   cd ~/.config/pi/agent
   cp settings.json.sample settings.json
   cp models.json.sample models.json   # replace <<<...>>> with real Bedrock ARNs,
                                       # or rewrite it for whatever providers this
                                       # machine has - keep the tier: names
   cp auth.json.sample auth.json       # or use /login
   ```
   `models.json` must define `tier:fast`, `tier:mid` and `tier:strong`, otherwise
   the agents cannot resolve a model. See [Model tiers](#model-tiers).
5. Local model: `ollama pull gemma4:e4b`
6. Language servers: install through mason so neovim and pi share one binary.
   `./check.sh` lists what `pi-lsp.json` expects and whether it runs.
7. Verify: `pi --list-models` and `./check.sh`

## Security note

The subagent extension defaults to `agentScope: "user"`, so only agents in this
directory are loaded. Project-local `.pi/agents/*.md` are repo-controlled prompts
that can instruct the model to read files and run commands — enable them
(`agentScope: "both"`) only for repositories you trust.
