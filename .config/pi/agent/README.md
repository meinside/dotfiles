# pi coding agent config

Config directory for [pi](https://github.com/earendil-works/pi-mono) (`pi-coding-agent`).

**pi does not support XDG paths.** `getAgentDir()` returns `$PI_CODING_AGENT_DIR`,
else `~/.pi/agent`. `~/.zshrc` exports the variable and a committed
`~/.pi -> .config/pi` symlink covers the fallback, so packages that build their own
`~/.pi/agent` path land here too. Read `~/.pi/agent` in upstream docs as "this
directory".

```bash
export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"
```

## Files

| Path | Tracked in dotfiles | Purpose |
|------|---------------------|---------|
| `settings.json` | `.sample` mirror | Theme, default model, `enabledModels` for `Ctrl+P` cycling |
| `models.json` | `.sample` only | Providers, models, tier aliases. Holds the AWS account ID inside Bedrock ARNs |
| `auth.json` | `.sample` template | Credentials. Never commit the real file. The sample is a template, not a mirror |
| `models-store.json` | no | Generated model catalog cache. Do not edit or commit; `check.sh` reads it to cross-check prices |
| `pi-lsp.json` | yes | Language server routes ([notes](#language-servers-pi-lsp)) |
| `magpi.json` | yes | MagPi config: 100 MB cache budget, `allowPrivateNetwork: false` |
| `magpi-render.json` | yes | `extensions/magpi-render.ts` config: `enabled`, `browserBinary`, `renderHosts`, `learnHosts`, `sameSiteOnlyHosts`, `maxWaitMs`. Absent means defaults ([notes](#magpi-renderer)) |
| `mcporter.json` | `.sample` mirror | `pi-mcporter`'s exposure policy. The MCP *server* definitions live in `~/.config/mcporter/mcporter.json`, outside this directory |
| `sandbox.json` | yes | `pi-sandbox` policy ([notes](#sandbox-extension)). Mutated live by `/sandbox-allow ... for all projects`, so tracking turns that prompt into a `git diff` |
| `quota-rotate.json` | `.sample` mirror | `pi-quota-rotate`'s fallback chain of `provider/modelId` entries, plus `maxRotationsPerRun`. The real file is local (which models a machine has is machine specific); `quota-rotate.test.ts` checks that both it and the sample still resolve ([notes](#magpi-handlers) explain why that check exists) |
| `magpi-cache/` | no | MagPi's fetch cache. `~/.pi/agent/magpi-cache` in MagPi's own paths and upstream docs is this same directory through the `~/.pi` symlink, not a second one |
| `cost-tracker/` | no | Cost ledger, one JSONL per day under `YYYY/MM/`. Contains Bedrock ARNs |
| `npm/` | no | `pi install` target. Ships its own `.gitignore` with `*` |
| `extensions/subagent/` | yes | Vendored subagent extension ([notes](#vendored-subagent-extension)) |
| `extensions/guard.ts` | yes | Blocks writes to credential files, confirms installs and irreversible commands |
| `extensions/git-checkpoint.ts` | yes | Vendored upstream example: per-turn git stash checkpoints for `/fork` |
| `extensions/statusline.ts` | yes | Claude Code style footer ([notes](#statusline-extension)) |
| `extensions/magpi-render.ts` | yes | Reads JavaScript-rendered pages through Firefox over WebDriver BiDi ([notes](#magpi-renderer)) |
| `extensions/magpi-handlers.ts` | yes | Local MagPi fetch handlers: reddit, Discourse, naver blog ([notes](#magpi-handlers)) |
| `AGENTS.md` | yes | [Global instructions](#global-instructions-agentsmd) for every session and subagent |
| `agents/*.md` | yes | Subagent definitions |
| `prompts/*.md` | yes | Prompt templates, invoked as `/name` |
| `check.sh` | yes | Entry point for the checks |
| `tests/*.ts` | yes | The checks. `lib.ts` is shared helpers, the rest run standalone under `node --test` |
| `../../llama.cpp/config.ini` | yes | Router-level llama.cpp config, auto-loaded by every llama.cpp binary ([notes](#llamacpp-provider)) |
| `../../llama.cpp/models.ini` | yes | Router model presets, pointed at by `$LLAMA_ARG_MODELS_PRESET` |

`~/.gitignore` ignores `.config/` wholesale, so tracked files here were added with
`git add -f`. Files holding secrets or machine-specific values are committed as
`<name>.sample` with `<<<placeholder>>>` markers. Files with nothing to
placeholder (`pi-lsp.json`, `sandbox.json`, both `llama.cpp/*.ini`) are tracked
directly.

## Global instructions (AGENTS.md)

pi's *global* context file: `loadProjectContextFiles` reads the agent directory
first, then `AGENTS.md` / `CLAUDE.md` from cwd and every ancestor. It reaches
subagents too, since they spawn without `--no-context-files`.

Two constraints when editing it:

- **General rules only.** Per-project rules belong in that project's own
  `AGENTS.md`, notes about this directory in this README.
- **Short and publishable.** It is billed on every turn of every session and
  subagent, in a public repo.

Keep the file in *this* directory: the ancestor walk stops only at the filesystem
root, so an `AGENTS.md` at `~` would load into every session under the home
directory.

## Vendored subagent extension

pi ships no built-in sub-agents, so tiered model usage comes from the upstream
`subagent` example extension, vendored here.

- **Upstream repo:** <https://github.com/earendil-works/pi-mono>
- **Upstream path:** `packages/coding-agent/examples/extensions/subagent/`
- **Local copy of upstream:** resolved by `tests/lib.ts`'s `piPackageDir()` — `brew --prefix pi-coding-agent`, else the real path of the `pi` binary on `PATH` (works for `pi.dev/install.sh` installs too)
- **Vendored from:** pi 0.84.3

Each delegation spawns a separate `pi` process with its own context window. Agents
come from `agents/*.md`.

### Agents

| Agent | `model:` | Upstream model | Tools | Role |
|-------|----------|----------------|-------|------|
| `scout` | `tier:fast:low` | `claude-haiku-4-5` | read, grep, find, ls, bash | Fast recon, returns compressed context |
| `planner` | `tier:strong:high` | `claude-sonnet-4-5` | read, grep, find, ls | Implementation plan, makes no changes |
| `reviewer` | `tier:strong:high` | `claude-sonnet-4-5` | read, grep, find, ls, bash | Code review, read-only bash |
| `worker` | `tier:mid:medium` | `claude-sonnet-4-5` | all | The actual implementation |

The `model:` line is the only local edit in these files; the `Upstream model`
column is what to re-apply after an upstream update.

Every agent must pin a tier **and** a thinking level:

- No `model:` line means the agent inherits the dispatching session's model *and*
  thinking level, so "fast recon" follows whatever `/model` is on.
- With a `model:` pin, `--thinking` is deliberately not passed, so
  `settings.json`'s `defaultThinkingLevel` would apply instead.
- `tier:fast:low` still resolves the pattern `tier:fast`, because a trailing
  level is consumed first ([rules](#rules-the-tokens-must-obey)).

Do not "upgrade" `worker` to the top tier — upgrade `planner` so `worker` needs
less rework.

### Workflow prompt templates

| Command | Chain |
|---------|-------|
| `/implement <task>` | scout → planner → worker |
| `/scout-and-plan <task>` | scout → planner (no implementation) |
| `/implement-and-review <task>` | worker → reviewer → worker |

Ad-hoc delegation works too (`Run 2 scouts in parallel: ...`; max 8 tasks, 4
concurrent, `Ctrl+O` expands output and per-step cost).

### Updating the vendored files

The vendored files are byte-identical to upstream except the `model:` lines, which
the comparison ignores. Run after every `brew upgrade pi-coding-agent` and before
committing:

```bash
~/.config/pi/agent/check.sh      # -v to print the diffs
```

When it reports drift:

```bash
U="$(./check.sh 2>&1 | head -1 | sed -E 's/.*upstream: //')"
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

Upgrading Homebrew's copy while a pi session runs would delete the Cellar
directory that process started from:

```bash
HOMEBREW_NO_INSTALL_CLEANUP=1 brew upgrade pi-coding-agent
brew cleanup pi-coding-agent    # after the session ends
```

(`pi.dev/install.sh` installs replace in place; no such risk.)

`check.sh` resolves the upstream prefix, then hands over to `node --test
tests/*.test.ts` — no build step, no test dependency. A single file runs on its
own: `node --test tests/samples.test.ts`. Fixed expectations are assertions;
machine-specific facts (which models and language servers this machine has) arrive
as diagnostics and skips.

## Guard extension

pi has no tool permission system: built-in tools run with the permissions of the pi
process. `extensions/guard.ts` is the narrow middle ground — patterns live in the
file, policy is:

- **Blocked, never confirmed (writes):** `~/.ssh`, `~/.gnupg`, `~/.aws`,
  `~/.config/gcloud`, `~/.config/rclone`, `~/.netrc`, `~/.npmrc`,
  `~/.ollama/id_ed25519`, `~/.custom_env`, `auth.json`, Claude's `settings.json`.
  Directories rather than single files where a vendor keeps adding state.
- **Also unreadable** through `read`/`grep`: most of the above plus transcript
  stores (`sessions/`, `history.jsonl`, shell histories). `~/.aws/config` and
  Claude's `settings.json` stay readable; transcripts are read-blocked but not
  write-blocked. `~/.custom_env` is on both lists: it is the untracked file the
  shells source, so it holds live tokens, and the sandbox keeps `bash` away from it
  only as a side effect of the home root being `denyRead`.
- **Ask once:** package managers, irreversible git/filesystem operations.
  Read-only and reversible forms are excluded on purpose.
- **No UI (`-p`, `--mode json`): a match is blocked**, so headless runs fail
  loudly.
- `!` commands go through `user_bash` and only enforce that no-UI rule.

Two limits worth remembering: the read block is **not a boundary** (`bash` can
`cat` anything — that is what `pi-sandbox` is for), and command matching is
substring-based over the whole command, so it also trips on a pattern quoted inside
an unrelated script. `grep` pointed at an ancestor (`~`, `~/.config`) is allowed;
offending lines are stripped from the *result* and a count appended.

## Sandbox extension

[`pi-sandbox`](https://github.com/carderne/pi-sandbox) gives `bash` a real OS
boundary (Seatbelt on macOS, bubblewrap + seccomp on Linux via
`@carderne/sandbox-runtime`); `read`/`write`/`edit` get the same filesystem policy
applied in-process. Policy is `sandbox.json`.

Commands: `/sandbox` shows the active policy and session allowances, `Alt+S`
toggles for the session, `/sandbox-allow {read,write,domain} <path>` extends
`allowRead`/`allowWrite`/`allowedDomains` — once, for the session, for this project
(`.pi/sandbox.json`), or for all projects (this file).

Rules that decide how entries are written:

- **`allowWrite` also grants read**, so a cache directory holding a credential file
  at its root is scoped to the specific subdirectory (`cargo/registry`,
  `gem/specs`) rather than allowed wholesale, with the credential files in
  `denyWrite` on top. `denyWrite` always wins and is never prompted.
- **A wildcard does not cover the bare domain at the enforcing layer.**
  `matchesDomainPattern` in `@carderne/sandbox-runtime` requires a strict
  subdomain, so a domain present only as `*.example.com` is hard-blocked *without a
  prompt*. Every apex host a tool hits is listed literally next to its wildcard;
  `tests/sandbox.test.ts` pins that with `BARE_DOMAINS_TOOLS_NEED`.
- **Execute is a read**, so every `PATH` directory (`~/.local/bin`, `~/bin`,
  `~/.local/share/cargo/bin`, `~/.local/share/nvim/mason`, `~/.luarocks`) must be
  readable or `command -v` reports installed tools as missing.
- **A package's data directory can sit outside the workspace.** `~/.pi/cost-tracker`
  and its symlink twin `~/.config/pi/cost-tracker` are both listed, as is
  `~/.pi/agent/magpi-cache`. Read-only: tools write those in-process, outside the
  sandbox.
- **A `~/.pi/...` entry only helps the in-process tools, not `bash`.** `~/.pi` is a
  symlink into `.config/pi`, and the home root is `denyRead`, so Seatbelt cannot even
  stat the symlink: `bash` gets `EPERM` on the `~/.pi/...` spelling while `read`
  (textual policy matching) succeeds. Use the `~/.config/pi/...` spelling in commands
  — the paths `magpi_fetch` returns are the `~/.pi/...` ones and must be rewritten.
- **`~/.config/llama.cpp` is `allowRead`** so `tests/llama.test.ts` checks instead
  of skipping; it stays out of `allowWrite` because `edit`/`write` go through
  `guard.ts` and leave a reviewable diff.
- **`allowBrowserProcess` stays `false`** — turning it on makes Chrome's
  cookie/login-data stores bash-readable.
- Toolchains here are XDG-relocated by asdf
  (`~/.local/share/{asdf,cargo,rustup,npm,pipx,uv}`), not the classic `~/.cargo`,
  `~/.npm`. Both `~/.asdf` and `~/.local/share/asdf` are listed; `~/.tool-versions`
  must be readable even though the home root is `denyRead`, or asdf silently
  resolves a different version (on Linux `denyRead` is a `tmpfs`, so the file reads
  as *absent*).
- **`$TMPDIR` is `/tmp/claude`, created by `sandbox-runtime`.** Only `/tmp` (and
  `/private/tmp`, the macOS symlink target) is writable, not `/var/folders`, and the
  variable outlives the directory when the sandbox is switched off mid-session — so
  anything calling `os.tmpdir()` must `mkdirSync` it first.

**When a `sandbox.json` edit takes effect:** at `session_start`, on
`/sandbox-enable` after a disable, and — the surprising one — on granting *any*
permission prompt (`applyChoice() -> refreshSandbox()` reloads the file). Outside
those moments the edit lies dormant and re-running a probe reproduces the old
behaviour.

**Probing the policy honestly:** a granted domain prompt whitelists that host for
the session *and* is invisible to the agent, so a `200` proves nothing. Read domain
results only from a session where `/sandbox` lists no allowances, or from outside
pi (nested it fails with `EPERM` on its own mux socket):

```bash
# expand ~ and fold allowWrite into allowRead the way buildRuntimeConfig() does
node .../@carderne/sandbox-runtime/dist/cli.js -s <that file> -c '<command>'
```

`tests/sandbox.test.ts` pins the committed JSON (which credential paths stay
hard-blocked, that the path lists stay sorted, that `denyWrite` *equals*
`GENERIC_SECRET_GLOBS ∪ CREDENTIAL_PATHS` so an addition also fails), not the live
effect — `pi-sandbox/src/policy.ts` cannot be imported (Node refuses type stripping
under `node_modules`). `tests/sandbox-deps.test.ts` checks the OS helpers the
policy needs (`rg`; `bwrap`/`socat` on Linux, plus userns sysctls).

### Troubleshooting: `apply-seccomp: ... nested userns ... CAP_SYS_ADMIN` on Ubuntu 24.04+

Every `bash` command inside pi fails, while a bare `bwrap --unshare-all ... echo ok`
works. Cause: `apply-seccomp` needs a *nested* unprivileged userns, which Ubuntu's
`bwrap-userns-restrict` AppArmor profiles block — regardless of the
`kernel.apparmor_restrict_unprivileged_userns` sysctl, which only affects
unconfined processes. Confirm with `sudo aa-status` (`bwrap`, `unpriv_bwrap`,
`unprivileged_userns` under enforce) and `sudo dmesg | grep -i apparmor`
(`capname="sys_admin"`). macOS and Raspberry Pi OS are unaffected.

```bash
sudo aa-complain bwrap unpriv_bwrap unprivileged_userns      # does NOT survive reboot
```

Make it stick, or revert:

```bash
sudo sed -i 's/flags=(attach_disconnected, mediate_deleted)/flags=(attach_disconnected, mediate_deleted, complain)/' /etc/apparmor.d/bwrap-userns-restrict
sudo apparmor_parser -r /etc/apparmor.d/bwrap-userns-restrict

sudo aa-enforce bwrap unpriv_bwrap unprivileged_userns
sudo sysctl -w kernel.apparmor_restrict_unprivileged_userns=1
```

A scoped AppArmor override that keeps the profiles enforcing does not work: the
blanket `audit deny capability,` wins over local allows, and `no_new_privs` (bwrap
sets it) blocks exec transitions to another profile.

## Statusline extension

`extensions/statusline.ts` replaces pi's footer with the three-line Claude Code
layout (`user@host 📂dir (branch*)`, then model/context/cost/tokens/durations, then
other extensions' `ctx.ui.setStatus()`). `/statusline` toggles back to the built-in
one; the choice and the timers live on `globalThis`, so `/fork`, `/reload` and
session switches keep them.

The numbers are re-derived from the session log, which has consequences:

- **Session-wide, including abandoned branches** — a rewind or `/fork` still counts.
  So `+N/-M` answers "how much editing has this session done", not "what is in the
  working tree".
- **`CH` is the latest response's cache hit rate**, not a session average.
- **`+N/-M` only sees `edit` and `write`.** `write` over an existing file counts the
  whole file as added; `sed`/heredoc edits through `bash` are invisible.
- **No `(sub)` marker** for subscription-backed models; the cost group is omitted
  when cost is zero.
- `(auto)` reads `.pi/settings.json` only when the project is trusted, and the `*`
  dirty marker treats any `git status --porcelain` output as dirty even alongside an
  error.

`tests/statusline.test.ts` pins the accounting and formatters. Git polling and the
timers are not covered.

## MagPi handlers

`extensions/magpi-handlers.ts` is the one place local `pi-magpi` handlers live, so
there is a single file to look at when a site starts returning junk, and one test
file beside it. Each handler is there because the behaviour was *measured*, not
guessed:

| Handler | What MagPi's built-ins do here | What this does instead |
|---------|-------------------------------|------------------------|
| `reddit` (shadows the built-in) | turns Reddit's login page into a 20-byte "Skip to main content" document and **reports success** | live JSON endpoint, else the Arctic Shift archive, else an error |
| `discourse` | reads the server-rendered HTML, which carried **18 of 169 posts** on a discuss.python.org thread, silently | `/t/<id>.json?print=true`, the whole stream, for URLs that clear the shape-plus-corroboration rule below |
| `naver-blog` | readability on the iframe-wrapped desktop page returns **0 bytes** | the mobile host, whose HTML has the post inline |

Rules all three follow:

- **A handler throws rather than return an empty or blocked document.** MagPi caches
  whatever a handler returns, for `ttlHours`, and an empty thread reads to the model
  as "this thread says nothing" — the failure mode every one of these exists to fix.
  On a throw MagPi falls back to a stale cache entry if it has one (its documented
  offline behaviour) and reports the error otherwise.
- **Registration goes through MagPi's own extension point**,
  `pi.events.emit("magpi:register-handler", ...)`. Its `registerHandler()` replaces
  by name, which is how `reddit` shadows the built-in instead of racing it. Nothing
  under `npm/node_modules` is patched, so a `pi install` or a MagPi upgrade cannot
  undo any of it. The emit happens at load *and* at `session_start`, since
  activation order between extensions is not guaranteed.
- **MagPi's TypeScript cannot be imported** — Node refuses type stripping under
  `node_modules`, the same wall `tests/sandbox.test.ts` hits. So the file restates
  the three interfaces it needs, does its own `fetch`, and carries a small regex
  `htmlToMarkdown()` in place of MagPi's readability+turndown one. That converter is
  aimed at *fragments* that are already content (a Discourse `cooked` body, a blog
  post container); handed a whole page it would keep the navigation too.
- **A handler's own requests check every redirect hop.** MagPi's `assertPublicTarget()`
  runs on the URL the model supplied, before `resolveHandler()`, so the entry point is
  covered — but its own comment grants that "a redirect hop to a private address can
  still slip through", and `fetch` follows such a hop silently by default. So the two
  helpers here use `redirect: "manual"` and re-check each hop (scheme, literal IP, and
  the addresses the hostname resolves to) against loopback, link-local, carrier-NAT and
  RFC 1918 ranges, capped at five hops. A name that does not resolve is passed through
  rather than refused, so the caller sees the real network error. `169.254.169.254` is
  the reason the list is wider than RFC 1918.
- **No `sandbox.json` entry is needed.** These handlers run in-process, and
  `pi-sandbox` enforces its policy at the **`bash` tool** — it replaces that one tool
  with a sandboxed implementation and hooks `tool_call` for `read`/`write`/`edit`/`bash`
  (its `src/extension.ts`). It creates its own sandbox manager, which pi's core knows
  nothing about, so `pi.exec` from an extension is *not* covered either: MagPi's
  `git clone` writes into `magpi-cache/` through a child process that `bash` cannot even
  read from. That asymmetry is why `curl` to `arctic-shift.photon-reddit.com` is blocked
  here while the handler's own request is not — and why a future handler that spawns a
  browser would not be sandboxed by that setting either.

Per-handler caveats:

- **Reddit has no key path left.** Measured from here: `www.reddit.com/*.json`,
  `api.reddit.com` and `oauth.reddit.com` answer `403`, `old.reddit.com` `302`s to
  `/login?reason=lor2`, `r.jina.ai` relays the block page, PullPush answers `429`,
  public Redlib instances sit behind an Anubis proof-of-work page. Self-service API
  keys ended with the Responsible Builder Policy (r/redditdev, Nov 2025).
- **Arctic Shift answers are archive snapshots**, so score and comment count are
  from crawl time and very recent threads can be missing. The document names its
  source on its own line so the model cannot mistake one for the other.
- **Discourse is claimed by URL shape plus corroboration, never by a host list.** It
  is self-hosted on arbitrary domains, so the URL is all there is to go on, and
  `match()` is synchronous — it cannot ask the site. The rule is the `/t/<id>` shape
  *and* either a slug (`/t/<slug>/<id>`, which every canonical Discourse link carries)
  or a hostname that names Discourse itself (`discourse.`/`discuss.` prefix,
  `.discourse.group`/`.discourse.org` suffix). NodeBB (`/topic/<id>/<slug>`), Flarum
  (`/d/<slug>-<id>`) and phpBB (`viewtopic.php`) never collide. **Measured collision:**
  `v2ex.com/t/1012345` — a busy non-Discourse forum — fitted the earlier shape-only
  rule exactly, and a false positive is not a slow read but an unreadable page, since a
  handler cannot hand a URL back to MagPi's default one. The slug requirement separates
  the two without naming either site.
- **A host list was rejected on this repository's own terms.** Every external-fact list
  here has a drift check — `pi-lsp.json`'s 17 servers are execed by `lsp.test.ts`,
  `models.json`'s costs are compared against pi's catalog by `pricing.test.ts`, tier
  aliases must resolve to exactly one model, and `quota-rotate.json`'s chain is now
  checked by `quota-rotate.test.ts`. That last one is the cautionary case: it had no
  check, and it is the list that went stale (a `:free` model OpenRouter had withdrawn,
  found by hand, not by `check.sh`). A list of "forums that run Discourse" could not be
  checked at all without asking the network, which `tests/magpi-handlers.test.ts` does
  not do. The four host patterns are Discourse's own naming rather than anyone's forum,
  so they age with the project. `forums.` is excluded: XenForo and phpBB use it as
  often, and a canonical URL on such a host already carries a slug.
- **The cost of the narrower rule is a slug-less link to an unlisted install.**
  `someforum.example/t/12345` is no longer claimed, so it reads through MagPi's default
  handler — truncated to the posts in the crawler HTML, which is the loss this handler
  exists to prevent. It is accepted because the alternative made readable pages fail
  outright, and because forums redirect the short form to the canonical slug URL that
  people actually paste.
- **Naver depends on markup**, not an API: the post container is matched by editor
  generation (`se-main-container`, then `postViewArea`, then `post_ct`). A redesign
  surfaces as "could not find the post container", which is the point — the failure
  it replaced was invisible.
- **Searching** reddit is still `magpi_search` with `site:reddit.com` (DuckDuckGo);
  `search.ts`'s source list has no extension point, and DDG results are good enough
  that adding one is not worth patching the package for.

`tests/magpi-handlers.test.ts` pins the fallback order, the id/ref parsing, the
comment-tree flattening, the provenance line, the shared HTML converter, the redirect
guard (a hop into a private address, a public name that resolves to one, an ordinary
redirect still followed, a loop bounded), the Discourse match rule (V2EX and a bare
`/t/<id>` on an unknown host are not claimed; a numeric first segment is a topic id and
not a slug) and — the case this file exists for — that no handler ever returns a blocked
or empty page as a document. It stubs `globalThis.fetch` and `hostResolver`, so nothing
in the checks talks to reddit, Discourse or naver, and no DNS query leaves the machine.

Removing one handler is deleting its section plus its tests; removing all of them is
deleting both files and this section (see also the `pi-magpi` row under
[Packages](#packages)).

### When to add one

`AGENTS.md` carries the general half of this in one line — an empty or boilerplate
fetch result is a failure, not the answer, and a site that fails that way twice
deserves a durable fix instead of another workaround. It deliberately stops there,
naming neither this file nor what "durable fix" means, because it is billed on every
turn of every session and holds general rules only. The specifics are here. A new
handler is worth writing when all four hold:

1. **The failure is measured, not assumed**: a byte count, a status code, or a
   missing-content count against what the page actually has. "Reddit blocks bots" is
   not a finding; "18 of 169 posts, silently" is.
2. **MagPi's built-ins genuinely lose information.** A page that arrives fat but
   complete is a token cost, not a correctness problem, and is not worth a handler —
   `topic` already slices those.
3. **A keyless source exists** that returns structure rather than a rendered page:
   an official JSON endpoint, an archive, or a host that serves the same content
   without the wrapper. Otherwise the handler is a scraper that will rot.
4. **The failure is silent.** A visible error already tells the truth; the ones
   worth intercepting are those that report success — that is what every handler
   here started as.

Measured and rejected on those grounds: `wiki.archlinux.org` (56 KB, parses fine),
`gist.github.com` (69 KB, the github handler correctly delegates), dev.to and
Substack (readability is fine), Hugging Face (works; an API would only be leaner), the
big Korean forums (no keyless structured source, aggressive bot walls), X and Discord
(no anonymous path at all), YouTube transcripts (no stable keyless endpoint).

Measured, working, and still rejected: a parts catalogue and an electronics shop, both
found during this work. Both *do* have keyless sources — the catalogue answers an
undocumented `/api/v1/…` JSON endpoint with no cookie or token, the shop serves its
description, reviews and Q&A as iframe fragments — and handlers for them were dropped
anyway. An undocumented internal API has no compatibility promise, skips the analytics
the site runs its business on, and is the
first thing a site blocks (the catalogue page already answers a proxy's IP with `429`). Those two
pages go through [the renderer](#magpi-renderer) instead, which consumes the page the
way the site intends.

## MagPi renderer

`extensions/magpi-render.ts` reads pages whose content only exists after JavaScript
runs. It registers the `magpi_fetch_rendered` tool and the `/magpi-render <url>`
command, drives the installed Firefox over WebDriver BiDi, and returns markdown.

The failure it exists for is the familiar one: a parts-catalogue page answers **27.6 KB of
Next.js scaffold containing zero product data**, MagPi's readability pass extracts the
**315-byte** company footer from it, and caches that as a successful `article` for
`ttlHours`. Nothing in the pipeline notices.

Measured on the two pages it was built against:

| Page | Server HTML | Rendered | Result |
|------|-------------|----------|--------|
| Parts catalogue, Next.js | 27.6 KB shell, 0 tables | 14.3 K chars, **11 tables** | price tiers and spec tables as markdown tables, `Product` + `FAQPage` ld+json. 13–15 s |
| Electronics shop product | 13.4 KB, reviews/Q&A/description empty | 4 frames, **61 KB** | description (1,145 lines incl. datasheet links), 630 reviews as a table, Q&A. 6 s |

How it decides things, and why:

- **Every tunable is in one `TUNING` block at the top of the file, with the measurement
  that set it.** These are not preferences. A 700 ms stability window instead of 1.6 s
  mistook the catalogue page's mid-load pause for the end, returned 2,767 of 14,296 characters with
  0 of 11 tables, and reported success in 2.9 s — the exact class of silent failure the
  renderer exists to fix, reintroduced by a tuning value.
- **Settling needs five conditions at once**: past a 3 s floor, all-frame text unchanged
  for 4 polls, no content-bearing response for 1.5 s, no request in flight, and some
  text present — then a confirm pass re-measures 800 ms later. Waiting for the `load`
  event instead is not an option: the shop page never reaches it, because an ad subresource
  never finishes.
- **Only responses that could carry content reset the idle timer.** Analytics beacons
  (GA's empty `204`s, ad pixels) never stop, so counting them means never settling.
- **`sameSiteOnlyHosts` is opt-in per host.** Restricting the idle signal to the page's
  own registrable domain saves ~1.5 s on the catalogue page (80 of 245 responses are third-party)
  but would settle early on any service that serves data from a sibling domain. Losing
  content is invisible; waiting too long is not.
- **Extraction runs in the page**, so visibility comes from `getComputedStyle` and box
  geometry rather than from guessing at tag names. No server-side parser has that.
- **Readability is a candidate, not the extractor.** It is built for articles and drops
  tables, which on a catalogue page *are* the content: 0.08 coverage with 0 tables where
  the layout pass scored 0.97 with 11. It is injected only when the layout pass scores
  below `weakCoverage` and found no table.
- **Coverage is measured against `document.body.innerText`**, the text the engine
  actually rendered. An extractor that quietly drops most of the page fails this ratio,
  which is how Readability disqualifies itself without a special case.
- **Every frame is read.** the shop page's description, reviews and Q&A are iframes; a
  top-document extraction sees 5.4 KB and stops. Frame traversal is also why no
  the shop page handler was written.
- **An empty render throws, naming why** — login wall, bot check, or nothing at all —
  rather than handing MagPi a shell to cache.

Operational notes:

- **Nothing is registered on a machine without Firefox.** This directory travels between
  machines through dotfiles, and a tool that can only fail when called still costs prompt
  tokens in every session. Discovery tries `browserBinary`, then a list of absolute paths,
  then `PATH` (`firefox`, `firefox-esr`, `firefox-developer-edition`), which covers
  Homebrew-formula, Nix and Flatpak installs that no fixed list predicts. A browser
  installed later needs a `/reload`.
- **No `sandbox.json` change is needed.** The browser is a child process of pi, and
  `pi-sandbox` enforces its policy at the `bash` tool. Measured: the same launch from
  inside sandboxed `bash` fails with Mach `bootstrap_check_in` errors and never gets a
  browsing context, while `allowBrowserProcess` stays `false` and the extension works.
- **The BiDi socket is hand-rolled over `node:net`.** Node's global `WebSocket` honours
  `HTTP(S)_PROXY`, which this machine sets, and sends even a loopback connection through
  the proxy, where the upgrade fails. Firefox also announces only `ws://127.0.0.1:PORT`;
  the socket lives at `/session`, and `/` is an ordinary HTML page.
- **A throwaway profile per render**, so the operator's own Firefox profile is never
  touched and no debugging port is left open on it. One browser per call: the 1.3 s
  startup is small next to a 6–15 s render, and pooling can wait until it is not.
- **The names borrow MagPi's.** `magpi_fetch_rendered` sorts directly under
  `magpi_fetch`, which is the tool whose thin answer sends you here, and `/magpi-render`
  follows the `/sandbox-allow`, `/telegram-connect` shape. Nothing under
  `npm/node_modules` is patched; if upstream MagPi ever ships its own renderer or reads
  `magpi-render.json`, this file yields the names.

Known limits:

- **A multi-row table header only merges when every cell is a `th`.** the catalogue page's spec
  table uses `td` for its `ℓx | ℓy` sub-header, so that row lands as a data row. The
  data rows themselves stay aligned; a heuristic for the general case risks worse.
- **6–15 seconds per page**, against 0.3 s for a handler. `navigator.webdriver` also
  stays `true`: `dom.webdriver.enabled=false` does not stick while the remote agent is
  active, so a site can tell this is automation. The catalogue page did not care; some will.
- **No automatic escalation yet.** `magpi_fetch` returning a shell does not call this by
  itself; the model has to notice and escalate. Wiring that in — plus learning which
  hosts always need it — is the obvious next step and is deliberately not done here.

### Automatic escalation

A shell does not announce itself: a marketing landing page cached **0 bytes** under a
perfectly good title and `kind: "article"`, which reads as a successful fetch. So detection
and delivery are split, and each half does the thing it can do well:

- **Detection** runs on `tool_result` for `magpi_fetch` and reads MagPi's own `details`
  (`contentBytes`, `handler`, `kind`), never its preview text. A result under
  `detect.minContentBytes` (600) from the **`webpage`** handler with a page-shaped `kind`
  is a shell: the host is written to `tmp/magpi-render/learned.json` and the result gains
  a comment saying what happened and what to call next. It fires on nothing else — a thin
  answer from `reddit`, `discourse`, `naver-blog`, `github` or a registry is a different
  failure that a browser does not fix, `render` is this extension's own handler and must
  never re-trigger itself, and an error result is already loud.
- **Delivery** is a handler registered on MagPi's own extension point, matching only
  hosts in `renderHosts` (by hand, `*.example.com` allowed) or in the learned store. It
  goes *through* MagPi on purpose: MagPi writes `content.md`, `meta.json` and the sqlite
  full-text index together, so TTL applies and `magpi_cached` can find the rendered text.
  Writing those files from outside would desync the index. MagPi also runs
  `assertPublicTarget()` before resolving a handler, so the SSRF guard is inherited.

What that adds up to, per host:

```
1st fetch   magpi_fetch(url) -> 315 bytes -> host learned, result annotated
2nd fetch   magpi_fetch(url, refresh: true) -> render handler -> 15 s -> cached by MagPi
thereafter  served from the cache like any other page, and searchable
```

The first visit cannot be repaired automatically, because nothing here can re-run MagPi's
tool; it is annotated instead, and `refresh: true` is needed because the shell is already
cached under MagPi's TTL. `learnHosts: false` turns the automatic half off and leaves
`renderHosts` as the only route.

**What detection cannot catch**: a partial loss. The shop page returns 13,377 real bytes with
three empty iframes inside, and no byte threshold will ever notice that. Pages like it
still need `renderHosts` or the explicit tool.

`tests/magpi-render.test.ts` pins the settle rule (including that the measured 2.9 s
failure would not settle), the extractor choice, the coverage yardstick, the empty-page
diagnosis, the same-site heuristic, the shell-detection rule and what it refuses to fire
on, host pattern matching, the learned store's round-trip, browser discovery on a machine
without Firefox, and the WebSocket framing. No browser is launched and no network is
touched.

```json
{
  "enabled": true,
  "browserBinary": "/Applications/Firefox.app/Contents/MacOS/firefox",
  "sameSiteOnlyHosts": ["kr.example.com"],
  "renderHosts": ["*.example.com", "shop.example.co.kr"],
  "learnHosts": true,
  "maxWaitMs": 25000
}
```

Removing it is deleting `extensions/magpi-render.ts`, its test, `magpi-render.json`,
`tmp/magpi-render/` and this section. Nothing else refers to it.

## Model tiers

Agents and `settings.json` never name a concrete model; they reference role tokens
embedded in the `name` of a `models.json` entry:

| Token | Meaning |
|-------|---------|
| `tier:fast` | Cheap, mechanical lookup and recon |
| `tier:mid` | Default implementation model |
| `tier:strong` | Architecture, review, adversarial verification |
| `tier:fable` | Experimental top-end model. No agent uses it, kept out of the `Ctrl+P` cycle |
| `tier:local-fast` | Local Ollama model, zero cost, answers in seconds ([notes](#ollama-provider)) |
| `tier:local-strong` | Local llama.cpp model, zero cost but slow — for delegated work, not conversation ([notes](#llamacpp-provider)) |
| `tier:local-coder` | Local llama.cpp model tuned for coding/agentic work — smaller and faster than `tier:local-strong` ([notes](#llamacpp-provider)) |

Only `models.json` knows what a tier resolves to, so a machine with different
providers needs no changes elsewhere. This table does not repeat the current
mapping — `./check.sh` prints it (`tiers.test.ts`, "tier tokens and their models"),
including which model a mistyped tier would land on and which prefixes are too
ambiguous to pin.

Bedrock:

```json
{ "id": "arn:aws:bedrock:...:application-inference-profile/...",
  "name": "tier:strong (claude-opus-5)" }
```

Direct Anthropic — attach the alias to a built-in model with `modelOverrides`:

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

`cost` is **USD per 1M tokens**, `cacheWrite` the 5-minute cache write price,
`cacheRead` the cache hit price. Reference: the
[AWS Bedrock pricing page](https://aws.amazon.com/bedrock/pricing/) for
**us-east-1, on-demand** — an application inference profile hides which region it
resolves to, so the file needs one fixed basis. `us.`/`global.` profiles match
us-east-1; `eu.`/`au.` run ~10% higher and are not chased. The Price List API is
unusable (Claude 2/3 era models only).

Update these whenever a tier points at a new model: they drive the footer's cost
readout, so a stale value is silently wrong rather than broken. `check.sh`
cross-checks against `models-store.json` and reports differences without failing.

### Rules the tokens must obey

From pi's resolver (`dist/core/model-resolver.js`). `check.sh` enforces the first
two:

- **Unique.** `--model` falls back to a case-insensitive substring match over id and
  name. An ambiguous substring is **not** an error: pi sorts matches by id and
  silently takes the highest.
- **Never a thinking level.** A trailing `:<suffix>` is consumed as a level when it
  is one of `off`, `minimal`, `low`, `medium`, `high`, `xhigh`, `max`. That makes
  `tier:fast:low` work — and `tier:high` a trap, since the pattern becomes `tier`,
  which matches everything. `fast` / `mid` / `strong` / `fable` / `local` are safe
  because none is a level.
- **A shared prefix is ambiguous too, even one nobody defined.** `tier:local` is a
  substring of both `tier:local-fast` and `tier:local-strong`. Never pin a prefix;
  `check.sh` reports every shared prefix it can derive.
- **A bare, non-glob pattern resolves to exactly one model — even in
  `enabledModels`.** `enabledModels: ["tier:local"]` does not enable both local
  models. Use a real glob (`"ollama/*"`, matched on `provider/id`) whenever a name
  must cover more than one model.
- **`*` does not cross a `/`.** One glob segment per `/`. Ollama ids have none
  (`ollama/*` works), but llama.cpp ids are `llama.cpp/<hf-user>/<repo>:<quant>`, so
  `llama.cpp/*` matches **nothing** — the model just never appears in `/model`. It
  needs `llama.cpp/**`. `llama.test.ts` asserts this through pi's own resolver.
- The colon itself is fine: full-pattern matching happens before the colon split,
  which is also why `<model>:<tag>` ids work.

A wrong token behaves differently depending on where it is used:

| Path | Unmatched `tier:typo` |
|------|----------------------|
| `--model` (agents, CLI) | Hard error, no fallback |
| `enabledModels` / `--models` | Warns `Invalid thinking level "typo"`, then matches the `tier` prefix and scopes the wrong model |
| `defaultModel` | Silently ignored — looked up as an exact id, so **a tier name never matches** and pi falls through to `enabledModels[0]`. Must be a raw id |

`settings.json` patterns are deliberately not validated by the checks; pi already
warns about unmatched scope patterns at startup.

## Sample files

A fresh clone starts from the committed `.sample` files. `check.sh` enforces that
they parse, that every tier an agent asks for resolves exactly once in
`models.json.sample`, and that no sample carries an ARN, an AWS account id or a
value taken from the real `auth.json`.

Samples are **not** required to mirror the real config: an entry present on only one
side is a note, not a failure. Treat those notes as a reminder to sync when the
difference was not intentional.

- `models.json.sample`: generated from the real file by replacing each Bedrock ARN
  with its `<<<...>>>` placeholder, keyed on the tier name. Regenerate whenever a
  model is added or a tier renamed.
- `settings.json.sample`: the real file minus the two keys pi rewrites at runtime
  (`lastChangelogVersion`, `defaultThinkingLevel` — the sample holds the intended
  starting level). `defaultProvider` and `defaultModel` are placeholders and only
  work as a pair; `defaultModel` must be a raw id, **not** a tier. `check.sh` fails
  a half-filled pair.
- `auth.json.sample`: maintained by hand as a template.

## Packages

`settings.json` `packages`, installed into `npm/` on first launch (unless
`PI_OFFLINE`). The list stays short: every entry also loads in each subagent
process, and a package runs with full system access.

| Package | Why |
|---------|-----|
| `git:github.com/meinside/pi-quota-rotate` | Rotates to the next model in `quota-rotate.json`'s chain when the current one runs out of quota, then continues the interrupted turn |
| `@ctogg/pi-cost-counter` | Appends every message's `usage` to `cost-tracker/YYYY/MM/DD.jsonl`, adds `/cost [Nd]`. The only cross-session ledger (the statusline is session-only) |
| `@llblab/pi-telegram` | Telegram runtime adapter: turns can arrive from and be answered on Telegram. In Threaded Mode each workspace gets its own forum topic, with one instance elected leader (it alone polls `getUpdates`) and the rest registered as followers over a local IPC bus, so several concurrent sessions share one bot without fighting for updates. Also a prompt queue, voice replies, `telegram_button` prompt buttons and file delivery. Configured by `telegram.json`, which holds a **literal bot token** |
| `@narumitw/pi-lsp` | Language server tools ([notes](#language-servers-pi-lsp)) |
| `@narumitw/pi-retry` | Marks empty-detail and stalled provider streams retryable, hands them to pi's backoff |
| `pi-ask-user` | `ask_user` tool with a structured form, plus an `ask-user` skill. Needs a UI, so subagents do not get it |
| `pi-env` | Exports `settings.json`'s `env` block into the process environment. That is the only route by which `PI_RETRY_STALL_TIMEOUT_MS` reaches `@narumitw/pi-retry`, which reads it from the environment and not from settings |
| `pi-magpi` | `magpi_fetch` / `magpi_search` / `magpi_cached`: pages as markdown behind a 24 h cache, official-API handlers for the big registries. SSRF-guarded. Its reddit handler is replaced locally, and Discourse/naver get their own ([notes](#magpi-handlers)) |
| `pi-mcporter` | MCP servers behind one `mcporter` proxy tool, with per-server exposure levels (`on-demand`/`index`/`match`/`native`) that decide how much schema reaches context |
| `pi-rewind` | Snapshots taken per tool call, restored through `/rewind` or `Esc Esc`, with a redo stack. Beside `extensions/git-checkpoint.ts`, not instead of it: that one stashes once per turn so `/fork` has a tree to return to, this one undoes individual edits inside a turn |
| `pi-sandbox` | OS-level sandboxing ([notes](#sandbox-extension)) |

The bar is small, dependency-free, auditable code. `pi-mcporter` and `pi-sandbox`
are **documented exceptions** (each ships a prebuilt native binary and a large
dependency chain) kept for capability, not weight: neither MCP access nor a real
kernel-enforced boundary can be built dependency-free. `pi-smart-fetch` is rejected
on the same criteria — it puts a core `@earendil-works/pi-tui` in `dependencies`
rather than peer dependencies and pulls 54 MB of Rust binaries.

Gotchas:

- **`/cost` prints the AWS account ID**: cost-counter records `message.model`, which
  under Bedrock is the full inference profile ARN. The ledger holds the same ARNs, so
  it is never committed.
- Cost accuracy rides on the `cost` blocks in `models.json`
  (`tests/pricing.test.ts`); ollama is priced at 0 so local runs record zero rather
  than nothing.
- MagPi and cost-counter build paths from `homedir()` + a hardcoded `.pi/...`
  instead of `getAgentDir()`; the `~/.pi -> .config/pi` symlink is what lands them
  here.
- `/magpi status` reports scope, ttl, budget and what the session saved. `/magpi
  scope project` moves writes to `.pi/magpi-cache` inside the repo.

## Language servers (pi-lsp)

Adds `lsp_diagnostics`, `lsp_fix` and `/lsp`. `pi-lsp.json` **replaces** pi-lsp's
built-in catalog and is deliberately a superset of what any one machine has: the
file stays identical everywhere, servers come from mason (shared with neovim), and
`check.sh` reports what is missing here.

An entry whose command is absent stays inert until a call includes a matching file —
and then aborts that whole call, losing the other servers' results. So the risk is
not an unused language, it is a language used here whose server was never installed.

- **`check.sh` separates two states.** Missing from `PATH` is a note. On `PATH` but
  unable to exec *is* a failure: mason wrappers hardcode the asdf interpreter present
  at install time (`ruby-lsp`, `fennel-ls`), so an asdf upgrade leaves them dead with
  exit 126, in neovim too. Reinstall through mason.
- **`pushDiagnosticsGraceMs`** on push-only servers stops a clean file from waiting
  out the full `timeout`.
- **Ruby needs both servers**: `ruby-lsp` for parse errors, `rubocop --lsp` for
  style. Python is split the same way (`ruff` lint, `ty` types). `clojure-lsp`
  embeds clj-kondo and needs no companion.
- **biome lints but does not typecheck** — add `vtsls` if `.ts` type errors ever
  matter. Its extension list omits `.json` so JSON has a single route through
  `vscode-json-language-server`.
- **`lsp_fix` only really works for gopls** (`source.organizeImports`). Use
  `rubocop -a` and `biome check --write` instead: rubocop exposes autocorrect as
  per-diagnostic quickfixes and biome marks most fixes unsafe, both of which
  `source.fixAll` skips.

## Ollama provider

A hand-written `models.json` provider, backing `tier:local-fast`.

- `apiKey` is a dummy string: Ollama ignores it, but pi hides models with no
  configured auth.
- `compat.supportsDeveloperRole: false` — Ollama rejects the `developer` role.
- **Prefer GGUF tags over `-mlx`.** The MLX runner is text-only despite advertising
  vision in the manifest (the image is dropped, the model sees `[img-0]`: ollama
  issues [#16700](https://github.com/ollama/ollama/issues/16700),
  [#17065](https://github.com/ollama/ollama/issues/17065)), and its generation speed
  collapses as context grows while GGUF stays flat. If MLX vision lands upstream,
  re-benchmark before switching, and add `"image"` to `input` only after confirming
  it at runtime.

Which tag the tier points at is `models.json`'s business; `check.sh` prints it.

## llama.cpp provider

Not a hand-written provider: pi ships a hidden built-in extension registering the
`llama.cpp` provider and the `/llama` command, discovering models from a running
[router server](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md#using-multiple-models).
Only *loaded* (or idle-`sleeping`) models reach `/model`.

| File | Why there |
|------|-----------|
| `~/.config/llama.cpp/config.ini` | The only path llama.cpp reads by itself (`/etc/llama.cpp/config.ini`, then `${XDG_CONFIG_HOME:-~/.config}/llama.cpp/config.ini`). Router-level settings: `host`, `port`, `models-max`, which the router strips from child presets |
| `~/.config/llama.cpp/models.ini` | Per-model presets. `--models-preset` has no default path and the ini parser expands neither `~` nor `$VARS`, so the location comes from `$LLAMA_ARG_MODELS_PRESET` (exported in `~/.zshrc` and `~/.bashrc`) and every artifact is named by Hugging Face repo or URL |

Each of these failed silently once:

- **A preset section needs its own `hf-repo`.** A sourceless section is still listed
  by `GET /models` and only fails on load. With `hf-repo` the router downloads on
  first load and the cache entry merges with the preset, so there is no duplicate.
- **A gated Hugging Face repo needs `$HF_TOKEN`** (llama-server reads it, or
  `--hf-token`) *and* a one-time terms acceptance on the model page by that account.
  Without both the download fails with HTTP 401. A **stale** token is the nasty case:
  public repos still serve a 307 with an invalid `Authorization` header, so nothing
  fails until the first gated repo. Check with
  `curl -sS -H "Authorization: Bearer $HF_TOKEN" https://huggingface.co/api/whoami-v2`.
- **MTP speculative decoding depends on how the repo ships the head.** `--spec-type
  draft-mtp` uses "MTP heads from the main model" (`docs/speculative.md`), so a quant
  with the `nextn` block embedded needs no draft file and no extra weights; a repo
  that ships an MTP *sidecar* instead needs `spec-draft-hf` + `spec-draft-model` and
  costs its full size in resident memory.
- **`modelOverrides`, not `models`.** The built-in provider hardcodes
  `reasoning: false` and `supportsReasoningEffort: false`, so a thinking model needs
  an override in `models.json`. The key must be the router's model id exactly; pi
  ignores unknown ids without a word.
- **`thinkingLevelMap` is mandatory for a Qwen3.8-style template**, which accepts
  only `low`/`medium`/`xhigh` and calls `raise_exception` otherwise — pi's `high`
  returns **HTTP 500**. Derive the map from the model's own template rather than
  copying this one: Ornith-1.5-9B's template takes `enable_thinking` and no
  `reasoning_effort` at all, so its override carries no `thinkingLevelMap`.
- **`enabledModels` needs `llama.cpp/**`**, per the
  [glob rule](#rules-the-tokens-must-obey).
- **A local model's context size is set by pi's compaction math, not by memory.**
  Auto-compaction fires at `contextWindow - compaction.reserveTokens` (16384) and then
  keeps `compaction.keepRecentTokens` (20000) of recent turns, so a window is only
  workable when `keepRecentTokens < contextWindow - reserveTokens`. At `c = 32768` it
  is not: the post-compaction prompt (system + tool schemas + summary + 20k kept)
  lands *above* the threshold, compaction can never get back under the window, and the
  next tool result overflows. llama.cpp answers HTTP 400 (`"exceeds the available
  context size"`, which pi's `isContextOverflow` does match) — but overflow recovery is
  **one** compact-and-retry per turn, and it drops the failed assistant message, so the
  edits in that message are lost and the second overflow ends the turn for good. Hence
  `c = 65536` in `models.ini` and a matching `contextWindow` in `models.json`; the two
  must agree or the threshold is computed against a window the server does not have.
  These settings are global, not per model, which is why the window moves instead.
- **`--context-shift` does not rescue this.** Current builds reject an oversized
  *prompt* before shifting is considered (the truncation path that worked in b6721 was
  removed; upstream's position is that compaction is the client's job,
  [#17284](https://github.com/ggml-org/llama.cpp/issues/17284)). It only affects the
  generation phase, where it silently discards context — which corrupts tool-call state
  in an agent session.
- **The memory ceiling on Apple Silicon is Metal's, and it is not the number everyone
  quotes.** `sysctl iogpu.wired_limit_mb hw.memsize` plus a 3-line Metal call
  (`MTLCreateSystemDefaultDevice()!.recommendedMaxWorkingSetSize`) measured 24.96 GiB
  of 32 GiB here — 78%, not the widely repeated two thirds. Both models fit under it at
  64k because they are hybrid-attention (16/64 and 8/32 full-attention layers, ~2 GB of
  KV each at 64k), so `iogpu.wired_limit_mb` never has to be raised. Prefill is the
  binding constraint instead: KV is allocated in full at load, and a window pi will
  never fill is pure waste. That also makes `[*] c = 65536` a claim about *these* models:
  a conventional GQA model pays KV on every layer (~160 KB per token for 40 layers x 8 KV
  heads x 128 head dim, so ~10 GB at 64k), so give one its own `[section]` with a smaller
  `c` — a section value beats `[*]` — instead of letting it inherit the global one.
- **The presets are shared config; serving them is not.** Both ini files are tracked,
  so a preset travels to machines that will never serve it — harmless at runtime, but
  the `enabledModels` check keys off `auth.json` naming a `llama.cpp` provider
  (written by `/login`) and skips with a reason where it does not.
- **Downloads bypass `/llama`'s progress bar** when the preset carries `hf-repo` (the
  child downloads, not the router); the status stays `loading`. Watch
  `~/.cache/huggingface/hub/`. Preset-sourced models report `can_remove: false`, so
  deleting one means removing that directory by hand.
- **The port is pinned to 9931**, llama.cpp's announced future default, keeping 8080
  free. pi prefers the URL stored by `/login` over `$LLAMA_BASE_URL`, so changing it
  means re-running `/login llama.cpp`; `llama.test.ts` reports a mismatch.
- **The API key belongs in `$LLAMA_API_KEY`** (`~/.custom_env`, untracked), read by
  both llama-server and pi. Without one the router leaves CORS open to every origin.
- **`--cache-ram -1` plus `--cache-reuse 256`** is what makes a large local model
  usable; the prompt cache does **not** survive an idle sleep (`cache_n=0` on wake),
  so `sleep-idle-seconds` trades a full re-prefill against keeping the weights
  resident. Re-measure both after any model or quant change.

`tests/llama.test.ts` covers what is static: no secret or path in either ini, every
preset has a model source, every `modelOverrides` key matches a preset section, and
`enabledModels` actually reaches the models (through pi's own
`resolveModelScopeWithDiagnostics`, so the glob rule cannot drift).

## New machine setup

1. `export PI_CODING_AGENT_DIR="$XDG_CONFIG_HOME/pi/agent"` must be active (already
   in `~/.zshrc`). Without it pi reads `~/.pi/agent`.
2. `brew install pi-coding-agent`
3. Clone the dotfiles repo — brings `extensions/`, `agents/`, `prompts/`,
   `AGENTS.md`, `check.sh`, this README, the `.sample` files and the
   `~/.pi -> .config/pi` symlink.
4. Create the real config from the samples:
   ```bash
   cd ~/.config/pi/agent
   cp settings.json.sample settings.json   # fill defaultProvider/defaultModel
   cp models.json.sample models.json       # replace <<<...>>> with real ARNs, or
                                           # rewrite for this machine's providers
   cp auth.json.sample auth.json           # or use /login
   ```
   `models.json` must define `tier:fast`, `tier:mid` and `tier:strong`, or the agents
   cannot resolve a model.
5. Local models:
   - Ollama — pull whatever `models.json` lists, so this needs no editing when the
     model changes:
     ```bash
     python3 -c 'import json;print("\n".join(m["id"] for m in json.load(open("models.json"))["providers"]["ollama"]["models"]))' \
       | xargs -n1 ollama pull
     ```
   - llama.cpp — `brew install llama.cpp`, then start the router in a new shell
     (`llama-server`, no `--model`) so it picks up `config.ini` and
     `$LLAMA_ARG_MODELS_PRESET`. In pi: `/login llama.cpp` with the URL built from
     `config.ini`'s `host`/`port`, then `/llama` to load a model — the first load
     downloads it.
6. Language servers: install through mason. `./check.sh` lists what `pi-lsp.json`
   expects and whether it runs.
7. Verify: `pi --list-models` and `./check.sh`

## Security note

The subagent extension defaults to `agentScope: "user"`, so only agents in this
directory are loaded. Project-local `.pi/agents/*.md` are repo-controlled prompts
that can instruct the model to read files and run commands — enable them
(`agentScope: "both"`) only for repositories you trust.
