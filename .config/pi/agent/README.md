# pi coding agent config

Config directory for [pi](https://github.com/earendil-works/pi-mono) (`pi-coding-agent`).

**pi does not support XDG paths.** `getAgentDir()` (`dist/config.js`) returns
`$PI_CODING_AGENT_DIR` if set, otherwise `~/.pi/agent`, and `~/.zshrc` exports it.
A committed `~/.pi -> .config/pi` symlink makes that fallback land here too, so the
variable is now a second line of defence rather than the only one — and extensions
that build their own `~/.pi/agent` paths instead of calling `getAgentDir()` stay
inside this directory. Read `~/.pi/agent` in upstream docs as "this directory".

```bash
export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"
```

## Files

| Path | Tracked in dotfiles | Purpose |
|------|---------------------|---------|
| `settings.json` | `.sample` mirror | Theme, default model, `enabledModels` for `Ctrl+P` cycling. Holds no secrets since it references tiers instead of ARNs |
| `models.json` | `.sample` only | Providers, models and the tier aliases. Holds the AWS account ID inside Bedrock inference profile ARNs, hence the `.sample` indirection |
| `auth.json` | `.sample` template | Credentials. Never commit the real file. The sample is a **template**, not a mirror: it documents providers (such as `google`) that may not be configured here |
| `models-store.json` | no | Generated model catalog cache. Do not edit or commit. `check.sh` reads it to cross-check prices |
| `pi-lsp.json` | yes | Language server routes for the `@narumitw/pi-lsp` extension. No secrets or machine-specific paths, so it is committed as-is |
| `magpi.json` | yes | MagPi's config: the 100 MB cache budget and a pinned `allowPrivateNetwork: false`. Written only by an explicit `/magpi` config command, which merges the file with the changed key rather than expanding it, so there is no runtime churn to keep out of git |
| `magpi-cache/` | no | MagPi's fetch cache (24 h TTL, capped at 100 MB, LRU eviction) |
| `cost-tracker/` | no | `@ctogg/pi-cost-counter`'s append-only cost ledger, one JSONL file per day under `YYYY/MM/`. Contains the Bedrock inference profile ARNs, hence never committed |
| `npm/` | no | `pi install` target. Ships its own `.gitignore` containing `*` |
| `extensions/subagent/` | yes | Vendored subagent extension |
| `extensions/guard.ts` | yes | Blocks writes to credential files, confirms package installs and irreversible commands |
| `extensions/git-checkpoint.ts` | yes | Vendored upstream example: per-turn git stash checkpoints for `/fork` |
| `extensions/statusline.ts` | yes | Claude Code style footer |
| `AGENTS.md` | yes | [Global instructions](#global-instructions-agentsmd) for every session and subagent, general rules only |
| `agents/*.md` | yes | Subagent definitions, read by the subagent extension |
| `prompts/*.md` | yes | Prompt templates, invoked as `/name` in the editor |
| `check.sh` | yes | Entry point for the checks: runs `tests/` on node's test runner and reports what this machine has |
| `tests/*.ts` | yes | The checks themselves. `lib.ts` is shared helpers, the rest are `node:test` files runnable on their own |

`~/.gitignore` ignores `.config/` wholesale, so tracked files here were added with
`git add -f`. Files holding secrets or machine-specific values are committed as
`<name>.sample` with `<<<placeholder>>>` markers, the convention already used for
`.config/claude`, `.config/git`, etc.

## Global instructions (AGENTS.md)

`AGENTS.md` here is pi's *global* context file: `loadProjectContextFiles`
(`dist/core/resource-loader.js`) reads the agent directory first, then `AGENTS.md`
/ `CLAUDE.md` from cwd and every ancestor. It reaches the subagents below too,
since `index.ts` spawns `pi` without `--no-context-files`.

Its subject is verification — find a project's quality gates before editing, run
them as the work proceeds, never silence one for a green run — because nothing
else here can carry that policy: `buildSystemPrompt`
(`dist/core/system-prompt.js`) ships three guidelines, none about correctness, and
`agents/*.md` must stay byte-identical to upstream.

Hence its two constraints. **General rules only:** per-project rules belong in
that project's own `AGENTS.md` and notes about this directory in this README, so
the file says "read the project's `README.md` first" rather than naming
`./check.sh`. **Short and publishable:** it is billed on every turn of every
session and subagent, in a public repo.

It offers `lsp_diagnostics` / `lsp_fix` only as a fallback and only "if they are
among your tools": they come from `@narumitw/pi-lsp`, and `--tools` is an
allowlist over extension tools too, so `scout`, `planner` and `reviewer` lack them
while `worker` has them. That wording also survives dropping the package.

Keep the file in this directory. The ancestor walk has no repository boundary — it
stops at the filesystem root — so an `AGENTS.md` at `~`, the dotfiles repo root,
would load into every session under the home directory.

## Vendored subagent extension

pi intentionally ships **no built-in sub-agents** (`docs/usage.md`, "Design
Principles"), so tiered model usage comes from the upstream `subagent` example
extension, vendored here.

- **Upstream repo:** <https://github.com/earendil-works/pi-mono>
- **Upstream path:** `packages/coding-agent/examples/extensions/subagent/`
- **Local copy of upstream:** `$(brew --prefix pi-coding-agent)/libexec/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/subagent/` (`brew --prefix` resolves to a version-independent symlink, so this path survives pi upgrades)
- **Vendored from:** pi 0.83.0

It registers a `subagent` tool that spawns a **separate `pi` process** per
delegation (`index.ts`: `args.push("--model", agent.model)`), giving each agent an
isolated context window. Agents are discovered from `agents/*.md` by `agents.ts`.

### Agents

| Agent | `model:` | Upstream model | Tools | Role |
|-------|----------|----------------|-------|------|
| `scout` | `tier:fast:low` | `claude-haiku-4-5` | read, grep, find, ls, bash | Fast recon, returns compressed context |
| `planner` | `tier:strong:high` | `claude-sonnet-4-5` | read, grep, find, ls | Produces an implementation plan, makes no changes |
| `reviewer` | `tier:strong:high` | `claude-sonnet-4-5` | read, grep, find, ls, bash | Code review, read-only bash |
| `worker` | `tier:mid:medium` | `claude-sonnet-4-5` | all | Performs the actual implementation |

The `model:` line is the only local edit in these files, and the `Upstream model`
column is what the example pins there; both are what to re-apply after an upstream
update.

Each pin carries a thinking level, because `settings.json`
`defaultThinkingLevel` reaches every spawned child otherwise: `index.ts` passes
`--model` but never `--thinking`, and `sdk.js` then falls back to that setting, so
`scout` would do "fast recon" at whatever level the interactive session happened to
be on. `resolveCliModel` consumes a trailing `:<level>` before the model lookup,
so `tier:fast:low` still resolves the pattern `tier:fast` — see [Rules the tokens
must obey](#rules-the-tokens-must-obey).

The split follows the convention visible across large public subagent collections
(wshobson/agents, VoltAgent/awesome-claude-code-subagents, @vigolium/piolium), and
the economics agree: planners and reviewers read a lot and write little, so an
expensive model costs little there, while an implementer emits many output tokens,
where the same model costs the most. Do not "upgrade" `worker` to the top tier;
upgrade `planner` instead so `worker` needs less rework.

An agent without a `model:` line does **not** track the parent session's current
model. `index.ts` appends `--model` only for an agent that declares one, and the
child `pi` then resolves its own default from `settings.json` `defaultModel`;
`PI_MODEL` / `PI_PROVIDER` are exported to bash-tool commands only and never read
back as input, so `/model` in the parent has no effect. Every agent here therefore
pins a tier explicitly.

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

The vendored files are byte-identical to upstream except the `model:` lines, which
the comparison ignores — so the tier pins are expected and no diff counts need
keeping in sync. That clean `diff` is the update-detection mechanism, which is why
these files carry no provenance comments or extra frontmatter keys. Run it after
every `brew upgrade pi-coding-agent`, and before committing a change here:

```bash
~/.config/pi/agent/check.sh      # -v to print the diffs
```

`check.sh` is a wrapper: it resolves the upstream prefix, then hands over to
`node --test tests/*.test.ts`. Node runs the TypeScript directly, so there is
nothing to build and no test dependency to install; a single file also runs on its
own, for example `node --test tests/samples.test.ts`. The split is deliberate:
fixed expectations (drift, tier resolution, sample leaks, guard policy) are
assertions, while machine-specific facts (which models this machine has, which
language servers are installed) arrive as `node:test` diagnostics and skips — the
same notes-versus-failures distinction the shell version made by hand.
`tiers.test.ts` goes further than that version could: it imports pi's own
`resolveCliModel` and asserts pi picks the model the uniqueness check found, so the
local matching rule cannot drift away from `dist/core/model-resolver.js` in
silence.

When it reports drift:

```bash
U="$(brew --prefix pi-coding-agent)"/libexec/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions
C=~/.config/pi/agent

diff -u $C/extensions/subagent/index.ts $U/subagent/index.ts   # inspect first

cp $U/subagent/index.ts $U/subagent/agents.ts $C/extensions/subagent/
cp $U/git-checkpoint.ts $C/extensions/
cp $U/subagent/prompts/*.md $C/prompts/
cp $U/subagent/agents/*.md $C/agents/     # then re-apply the tiers from the
                                          # Agents table
~/.config/pi/agent/check.sh
```

Then bump "Vendored from" above.

If a pi session is running while upgrading, disable Homebrew's cleanup so the
Cellar directory the running process started from stays in place:

```bash
HOMEBREW_NO_INSTALL_CLEANUP=1 brew upgrade pi-coding-agent
brew cleanup pi-coding-agent    # after the session ends
```

## Guard extension

pi has no tool permission system, on purpose: built-in tools run with the
permissions of the pi process, and pi's `docs/security.md` points at containers or
micro-VMs rather than per-call prompts. That is no use for a config that edits the
home directory itself. `extensions/guard.ts` is the narrow middle ground — the
patterns live in the file, the decisions are:

- Credential files are **blocked, not confirmed**: `~/.ssh`, `~/.gnupg`, `~/.aws`,
  `~/.config/gcloud`, `~/.config/rclone`, `~/.netrc`, `~/.npmrc`,
  `~/.ollama/id_ed25519`, `auth.json`, and Claude's `settings.json` (whose hooks
  run commands). There is no case where the agent should rewrite them, so a prompt
  would only be a chance to say yes by mistake. Directories rather than single
  files where a vendor keeps adding state: `~/.aws` was two files until
  `sso/cache` and `cli/cache` turned up holding live tokens.
- Most of those are also **unreadable** through `read` and `grep`, plus the
  transcript stores (`sessions/`, `history.jsonl`, shell histories). A secret the
  agent reads goes to the provider and into `sessions/*.jsonl` in the clear, so
  reading one is already the damage, before anyone tries to exfiltrate it. The two
  lists differ on purpose: `~/.aws/config` and Claude's `settings.json` stay
  readable, and transcripts are read-blocked without being write-blocked.
- Package managers and irreversible git/filesystem operations **ask once**.
  Read-only and reversible forms are excluded deliberately: a gate that fires on
  every `ls` gets removed, and a noisy one trains blind acceptance.
- With no UI to ask (`-p`, `--mode json`) a match is **blocked**, so headless runs
  fail loudly instead of installing something.
- `!` commands go through `user_bash`, which only enforces that same no-UI rule.
  They were already an explicit user action.

`extensions/git-checkpoint.ts` is the other half: an unmodified copy of pi's
example that stashes a checkpoint each turn so `/fork` can restore code state.
Keeping it a separate file lets `check.sh` diff it against upstream and lets
`pi config` disable it on its own.

The read block is a guard against accidents, **not a boundary**. `bash` can still
`cat` any of those files: gating it on patterns would be trivially bypassable
(`$HOME`, quoting, `python -c`) and would fire on `check.sh`, which reads the real
`auth.json` to prove the sample carries no live credentials — exactly the routine
prompt this file avoids on purpose. Command matching is substring-based over the
whole command, so it also trips on a pattern quoted inside an unrelated script.

The `tool_call` check asks whether the target sits inside a guarded path, which
leaves `grep` pointed at an ancestor (`~`, `~/.config`) free to walk into the
secrets underneath. Blocking every ancestor would block `grep` on this directory,
so a `tool_result` handler drops the offending lines from the result instead and
appends a count, since a model reasoning from a silently shortened result is its
own failure mode. `tests/guard.test.ts` pins both halves.

What actually lowers the risk is credential hygiene, a short-lived AWS session
rather than a long-lived key, and — now that MagPi pulls untrusted web pages into
context, where an injected instruction can ask for a file and then post it to a
public URL — doing that kind of work in an isolated environment, as
`docs/security.md` recommends.

## Model tiers

Agents and `settings.json` never name a concrete model. They reference role
tokens embedded in the `name` of a `models.json` entry:

| Token | Meaning | Current model |
|-------|---------|---------------|
| `tier:fast` | Cheap, mechanical lookup and recon | `claude-haiku-4-5` |
| `tier:mid` | Default implementation model | `claude-sonnet-5` |
| `tier:strong` | Architecture, review, adversarial verification | `claude-opus-5` |
| `tier:fable` | Experimental top-end model. No agent uses it, and it is kept out of the `Ctrl+P` cycle | `claude-fable-5` |
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

`cost` is **USD per 1M tokens**, `cacheWrite` the 5-minute cache write price and
`cacheRead` the cache hit price. The reference is always the
[AWS Bedrock pricing page](https://aws.amazon.com/bedrock/pricing/) for
**us-east-1, on-demand**. Update these whenever a tier points at a new model; they
only drive the footer's cost readout, so a stale value is silently wrong rather
than broken.

Why us-east-1 specifically: an application inference profile hides which model and
region it resolves to, so the numbers need one fixed basis. Bedrock prices the
`us.` and `global.` cross-region profiles the same as us-east-1, while `eu.` and
`au.` run about 10% higher — do not chase those; the file stays on the us-east-1
basis.

AWS's Price List API (`pricing.us-east-1.amazonaws.com/.../AmazonBedrock/...`) is
not usable here: it still only carries Claude 2 and Claude 3 era models, so the
pricing page is authoritative. `check.sh` cross-checks the values against pi's own
catalog (`models-store.json`, which covers current models) and reports differences
as notes.

### Rules the tokens must obey

From pi's resolver (`dist/core/model-resolver.js`). `check.sh` enforces
the first two:

- **Unique.** `--model` falls back to a case-insensitive substring match over id
  and name. An ambiguous substring is **not** an error: pi sorts the matches by id
  and silently takes the highest one. `--model bedrock-claude` used to resolve to
  the most expensive model this way.
- **Never a thinking level.** A trailing `:<suffix>` is consumed as a thinking
  level when it is one of `off`, `minimal`, `low`, `medium`, `high`, `xhigh`,
  `max`, and the rest is the pattern. That is what makes the agents'
  `tier:fast:low` work — and what makes `tier:high` a trap, since the pattern is
  then `tier`, which matches every entry. Measured against this `models.json`, the
  silent winner is `tier:local`, so a mistyped tier would quietly run an agent on
  the local 4B model. `fast` / `mid` / `strong` / `fable` / `local` are safe as
  tier names precisely because none of them is a level.
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

A fresh clone starts from the committed `.sample` files, since the real
`settings.json` / `models.json` / `auth.json` are untracked. `check.sh` enforces
that they parse, that a fresh machine can bootstrap (every tier an agent asks for
resolves exactly once in `models.json.sample`), and that no sample carries an ARN,
an AWS account id or a value taken from the real `auth.json`.

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

## Packages

`settings.json` `packages`, installed into `npm/` on first launch. The list stays
short on purpose: every entry also loads in each subagent process, and a package
runs with full system access (`docs/packages.md`), so what earns a place is small,
dependency-free, auditable code.

| Package | Why |
|---------|-----|
| `@ctogg/pi-cost-counter` | Appends every assistant message's `usage` to `~/.pi/cost-tracker/YYYY/MM/DD.jsonl` and adds `/cost [Nd]` for daily and per-model totals. The statusline below shows the *current session*; this is the only cross-session ledger. 284 lines, no dependencies, no network access, append-only writes |
| `@narumitw/pi-lsp` | Language server tools, see [Language servers](#language-servers-pi-lsp) |
| `@narumitw/pi-retry` | Marks empty-detail and stalled provider streams as retryable and hands them to pi's own backoff rather than looping itself. 325 lines, no dependencies, no network or filesystem access |
| `pi-ask-user` | An `ask_user` tool with a structured form, so the model asks instead of guessing. Also ships an `ask-user` skill. Needs a UI: it degrades where `ctx.hasUI` is false, so subagents do not get it |
| `pi-magpi` | `magpi_fetch` / `magpi_search` / `magpi_cached`: pages fetched as markdown behind a 24 h cache, with official-API handlers for GitHub, GitLab, npm, PyPI, crates, rubygems, maven, hex, arxiv, Wikipedia, StackExchange and HN. Search scrapes `lite.duckduckgo.com`, the one fragile part. SSRF-guarded: a model-supplied URL cannot reach loopback, link-local (AWS IMDS) or private ranges unless `allowPrivateNetwork` is set |

Measured: `npm/` holds 19 MB, all pure JavaScript with no native binaries, and
startup goes from 0.67 s to 1.03 s — paid again by every subagent process. Nearly
all of both numbers is MagPi's HTML and PDF conversion dependencies; retry and
ask-user together cost 160 KB and nothing measurable, and cost-counter 28 KB.

Cost-counter records `message.model`, which under `amazon-bedrock` is the full
inference profile ARN, so **`/cost` prints the AWS account ID** and its "by model"
column (padded to 45 characters) wraps. The ledger under `cost-tracker/` holds the
same ARNs; `~/.gitignore` covers `.config/` wholesale, so it is only reachable by
an explicit `git add -f` like the tracked files here. Accuracy rides on the `cost`
blocks in `models.json` — `tests/pricing.test.ts` is what keeps those honest, and
ollama is priced at 0 so local runs record zero rather than nothing.

MagPi builds its paths from `homedir()` plus pi's `CONFIG_DIR_NAME` instead of
calling `getAgentDir()`, so its config and cache would sit in `~/.pi/agent/`. The
`~/.pi -> .config/pi` symlink above resolves that to this directory, which is why
`magpi.json` and `magpi-cache/` appear in the table. Cost-counter is the same
case, one level up: `homedir()` plus a hardcoded `.pi/cost-tracker`. `magpi.json` sets two of
MagPi's four keys: a 100 MB cache budget with LRU eviction (its default is
unlimited), and `allowPrivateNetwork: false`, which is already the default but is
pinned because it is the SSRF guard that keeps a model-supplied URL away from AWS
IMDS on a machine holding Bedrock credentials. `ttlHours` stays at 24: package
registry metadata is exactly the kind of thing a longer cache would answer
stalely, and `refresh` on a single call bypasses the cache anyway. `/magpi status`
reports scope, ttl, budget and what the session saved; `/magpi scope project`
would move writes to `.pi/magpi-cache` inside the repo, and it records that
project-locally when the project is trusted.

Rejected on the same criteria: `pi-smart-fetch`, which puts
`@earendil-works/pi-tui@^0.82.1` in `dependencies` against the host's 0.84.1 —
core packages must be peer dependencies — and pulls 54 MB of prebuilt Rust
binaries through `wreq-js`.

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
   `AGENTS.md`, `check.sh`, this README, the `.sample` files, and the
   `~/.pi -> .config/pi` symlink (tracked, so no manual step).
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
6. Language servers: install through mason, as
   [above](#language-servers-pi-lsp). `./check.sh` lists what `pi-lsp.json`
   expects and whether it runs.
7. Verify: `pi --list-models` and `./check.sh`
## Security note

The subagent extension defaults to `agentScope: "user"`, so only agents in this
directory are loaded. Project-local `.pi/agents/*.md` are repo-controlled prompts
that can instruct the model to read files and run commands — enable them
(`agentScope: "both"`) only for repositories you trust.
