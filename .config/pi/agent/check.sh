#!/usr/bin/env bash
#
# Verify this config directory. Four checks, all documented in README.md:
#
#   1. Vendored files match the pi-coding-agent bundled examples. The `model:`
#      line in agents/*.md is the only local edit, so it is excluded from the
#      comparison and there are no diff counts to maintain.
#   2. Each agent references a tier token that models.json defines exactly once.
#   3. The committed *.sample files neither drift from the real config nor leak a
#      secret.
#   4. Every server in pi-lsp.json that is installed actually execs. The file is
#      a superset of what any single machine has, so a server missing from PATH
#      is only reported, not a failure. A server that is present but cannot run
#      is: mason wrappers hardcode the asdf interpreter present at install time,
#      so they stay on PATH but die with exit 126 once that version is gone.
#
# Deliberately does not reimplement pi's model resolution (globs, provider/id,
# thinking-level suffixes): that logic lives in dist/core/model-resolver.js and a
# copy here would rot silently. pi already warns about unmatched scope patterns.
#
# Usage: ./check.sh [-v]     # -v prints diffs for drifting files
#
set -uo pipefail

VERBOSE=0
[ "${1:-}" = "-v" ] && VERBOSE=1

C="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="$(brew --prefix pi-coding-agent 2>/dev/null)" || true
U="$PREFIX/libexec/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/subagent"
if [ -z "$PREFIX" ] || [ ! -d "$U" ]; then
    echo "error: upstream examples not found (looked in ${U:-brew --prefix pi-coding-agent})" >&2
    exit 2
fi

ok() { printf '  \033[32m✓\033[0m %s\n' "$1"; }
bad() { printf '  \033[33m!\033[0m %s\n' "$1"; }

echo "pi: $(pi --version 2>/dev/null | head -1)  upstream: $U"
fail=0

# --- 1. vendored files ------------------------------------------------------
echo
echo "Vendored files:"
for rel in extensions/subagent/index.ts extensions/subagent/agents.ts \
    prompts/implement.md prompts/scout-and-plan.md prompts/implement-and-review.md \
    agents/scout.md agents/planner.md agents/reviewer.md agents/worker.md; do
    up="$U/${rel#extensions/subagent/}"
    [ -f "$C/$rel" ] || {
        bad "$rel missing locally"
        fail=1
        continue
    }
    [ -f "$up" ] || {
        bad "$rel missing upstream"
        fail=1
        continue
    }

    if diff -q <(grep -v '^model:' "$C/$rel") <(grep -v '^model:' "$up") >/dev/null; then
        ok "$rel"
    else
        bad "$rel drifted from upstream"
        fail=1
        [ "$VERBOSE" = 1 ] && diff -u "$C/$rel" "$up" | sed 's/^/      /'
    fi
done

# --- 2. agent tier tokens ---------------------------------------------------
# pi matches --model as a case-insensitive substring and resolves an ambiguous
# match silently to the highest-sorting id, so uniqueness matters. A trailing
# `:<thinking level>` would be parsed as a thinking level, not as the model.
echo
echo "Agent tiers:"
names="$(python3 -c 'import json,sys
for prov in (json.load(open(sys.argv[1])).get("providers") or {}).values():
    for m in (prov.get("models") or []):
        if m.get("name"): print(m["name"])' "$C/models.json" 2>/dev/null)"

if [ -z "$names" ]; then
    bad "models.json unreadable or defines no named models; skipping tier check"
    fail=1
else
    for f in "$C"/agents/*.md; do
        agent="$(basename "$f")"
        token="$(sed -n 's/^model: *//p' "$f" | head -1)"
        hits="$(printf '%s\n' "$names" | grep -icF -- "${token:-__none__}")"
        case "${token##*:}" in
        off | minimal | low | medium | high | xhigh | max) clash=1 ;;
        *) clash=0 ;;
        esac

        if [ -z "$token" ]; then
            bad "$agent has no model: line (would fall back to defaultModel)"
            fail=1
        elif [ "$hits" -eq 0 ]; then
            bad "$agent -> $token not defined in models.json"
            fail=1
        elif [ "$hits" -gt 1 ]; then
            bad "$agent -> $token matches $hits models (ambiguous)"
            fail=1
        elif [ "$clash" = 1 ]; then
            bad "$agent -> $token suffix is a thinking level"
            fail=1
        else
            ok "$agent -> $token"
        fi
    done
fi

# --- 3. sample files --------------------------------------------------------
# A fresh clone starts from the *.sample files, so drift means a new machine
# cannot resolve the tiers, and a leak is unrecoverable once pushed.
echo
echo "Sample files:"
python3 - "$C" <<'PY' || fail=1
import json, re, sys

cfg = sys.argv[1]
fails, notes = [], []
PLACEHOLDER = re.compile(r"^<<<.*>>>$")
SECRET = re.compile(r"(key|token|secret|password|credential)$", re.I)


def load(name):
    try:
        return json.load(open(f"{cfg}/{name}"))
    except Exception:
        return None


def leaves(obj, prefix=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            yield from leaves(v, f"{prefix}{k}.")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            yield from leaves(v, f"{prefix}{i}.")
    else:
        yield prefix.rstrip("."), obj


def entries(c):
    return {
        (p, m.get("name")): m.get("id", "")
        for p, pv in (c.get("providers") or {}).items()
        for m in (pv.get("models") or [])
    }


samples = {}
for name in ("models.json", "settings.json", "auth.json"):
    data = load(f"{name}.sample")
    if data is None:
        fails.append(f"{name}.sample missing or not valid JSON")
    else:
        samples[name] = data

# leak scan: no literal ARNs, no account id taken from the real models.json
real_models = load("models.json")
accounts = set(re.findall(r"\b\d{12}\b", json.dumps(real_models))) if real_models else set()
for name in samples:
    raw = open(f"{cfg}/{name}.sample").read()
    if "arn:aws" in raw:
        fails.append(f"{name}.sample contains a literal arn:aws")
    for a in sorted(a for a in accounts if a in raw):
        fails.append(f"{name}.sample contains account id {a}")

# models.json.sample mirrors models.json with placeholdered ARNs
if real_models and "models.json" in samples:
    real, sample = entries(real_models), entries(samples["models.json"])
    problems = len(fails)
    for missing in sorted(str(k[1]) for k in real.keys() - sample.keys()):
        fails.append(f"models.json.sample missing {missing!r} (regenerate it)")
    for stale in sorted(str(k[1]) for k in sample.keys() - real.keys()):
        fails.append(f"models.json.sample has stale entry {stale!r}")
    for key, rid in real.items():
        if rid.startswith("arn:") and not PLACEHOLDER.match(sample.get(key, "")):
            fails.append(f"models.json.sample: {key[1]!r} id is not a <<<placeholder>>>")
    if len(fails) == problems:
        notes.append(f"models.json.sample mirrors {len(real)} models")

# settings.json.sample is a byte copy minus pi's runtime state. pi rewrites
# lastChangelogVersion on upgrade and defaultThinkingLevel on the in-session
# toggle, so both are excluded to keep the sample from churning.
RUNTIME_KEYS = ("lastChangelogVersion", "defaultThinkingLevel")
real_settings = load("settings.json")
if real_settings and "settings.json" in samples:
    strip = lambda d: {k: v for k, v in d.items() if k not in RUNTIME_KEYS}
    a, b = strip(real_settings), strip(samples["settings.json"])
    if a != b:
        keys = sorted(set(a) ^ set(b)) or sorted(k for k in a if a[k] != b.get(k))
        fails.append("settings.json.sample differs from settings.json: " + ", ".join(keys))
    elif "lastChangelogVersion" in samples["settings.json"]:
        fails.append("settings.json.sample should not carry lastChangelogVersion")
    else:
        notes.append("settings.json.sample matches settings.json")

# auth.json.sample is a hand written template; it must hold no real values
if "auth.json" in samples:
    secrets = {v for _, v in leaves(load("auth.json") or {}) if isinstance(v, str) and len(v) > 8}
    leaked = [
        f"{path} ({'real value' if v in secrets else 'not a placeholder'})"
        for path, v in leaves(samples["auth.json"])
        if isinstance(v, str) and (v in secrets or (SECRET.search(path) and not PLACEHOLDER.match(v)))
    ]
    if leaked:
        fails.append("auth.json.sample leaks: " + ", ".join(leaked))
    else:
        notes.append("auth.json.sample has no real credentials")

for line in notes:
    print(f"  \033[32m✓\033[0m {line}")
for line in fails:
    print(f"  \033[33m!\033[0m {line}")
raise SystemExit(1 if fails else 0)
PY

# --- 4. lsp servers ---------------------------------------------------------
# pi-lsp never downloads a server, and a custom pi-lsp.json replaces the built-in
# catalog, so an explicitly configured command that cannot start fails the whole
# lsp_diagnostics call instead of being skipped.
echo
echo "LSP servers:"
python3 - "$C" <<'PY' || fail=1
import json, shutil, subprocess, sys

cfg = sys.argv[1]
OK = "  \033[32m\u2713\033[0m %s"
BAD = "  \033[33m!\033[0m %s"
TODO = "  \033[2m\u00b7\033[0m %s"

try:
    conf = json.load(open(f"{cfg}/pi-lsp.json"))
except FileNotFoundError:
    print(OK % "pi-lsp.json absent; pi-lsp would use its built-in catalog")
    raise SystemExit(0)
except Exception as exc:
    print(BAD % f"pi-lsp.json is not valid JSON: {exc}")
    raise SystemExit(1)

# both shapes are accepted by pi-lsp: a bare server map, or {"servers": {...}}
servers = conf.get("servers") if isinstance(conf.get("servers"), dict) else conf
fails, missing = [], []
for name, spec in sorted(servers.items()):
    if not isinstance(spec, dict):
        continue
    argv = spec.get("command") or []
    if not argv:
        fails.append(f"{name}: no command")
        continue
    if not spec.get("extensions"):
        fails.append(f"{name}: no extensions, so nothing routes to it")
    path = shutil.which(argv[0])
    if not path:
        missing.append(name)
        continue

    # exit 126/127 is the exec failure we care about; a hang means it started
    try:
        p = subprocess.run(
            [path, "--version"], capture_output=True, text=True, timeout=5
        )
        rc, err = p.returncode, (p.stderr or "") + (p.stdout or "")
    except subprocess.TimeoutExpired:
        rc, err = 0, ""
    except OSError as exc:
        rc, err = 126, str(exc)

    broken = rc in (126, 127) or any(
        s in err
        for s in ("bad interpreter", "cannot execute", "No such file or directory")
    )
    if broken:
        detail = next((l for l in err.splitlines() if l.strip()), f"exit {rc}")
        fails.append(f"{name}: on PATH but does not exec ({detail.strip()})")
    else:
        print(OK % f"{name} -> {path}")

# not installed here is expected: pi-lsp.json is shared across machines. It only
# bites once a file of that type is diagnosed on this one.
for name in missing:
    print(TODO % f"{name}: not installed")
if missing:
    print(TODO % "install the above, or drop the entries from pi-lsp.json")
for line in fails:
    print(BAD % line)
raise SystemExit(1 if fails else 0)
PY

echo
if [ "$fail" -ne 0 ]; then
    echo "Problems found. Run with -v for diffs; see README.md for the update and"
    echo "sample-regeneration procedures."
    exit 1
fi
echo "All checks passed."
