#!/usr/bin/env bash
#
# Verify this config directory, as documented in README.md. The checks themselves
# live in tests/ and run on node's built-in test runner:
#
#   vendored.test.ts  the vendored files still match upstream except model: lines
#   tiers.test.ts     every agent pins a tier that pi resolves to exactly one model
#   samples.test.ts   a fresh clone can bootstrap and no sample leaks a secret
#   pricing.test.ts   models.json costs against pi's catalog (reported, never fails)
#   lsp.test.ts       every pi-lsp.json command is present and can exec
#   guard.test.ts     guard.ts blocks what README says it blocks
#   sandbox.test.ts   sandbox.json holds the invariants README.md documents (see
#                     its header for why pi-sandbox's own matching logic can't be
#                     borrowed the way guard.ts's is)
#
# Machine-specific differences (which models, which language servers) arrive as
# notes or skips; only drift, an unresolvable tier, a leak, a server that cannot
# exec or a guard regression fails. Node runs the TypeScript directly, so there is
# nothing to build and nothing to install.
#
# Usage: ./check.sh [-v]     # -v prints diffs for drifting vendored files
#
set -uo pipefail

[ "${1:-}" = "-v" ] && export PI_CHECK_VERBOSE=1

C="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="$(brew --prefix pi-coding-agent 2>/dev/null)" || true
U="$PREFIX/libexec/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions"

# Checked here rather than in a test: without it every vendored case fails with
# the same cause, and tiers.test.ts cannot borrow pi's resolver at all.
if [ -z "$PREFIX" ] || [ ! -d "$U/subagent" ]; then
    echo "error: upstream examples not found (looked in ${U:-brew --prefix pi-coding-agent})" >&2
    exit 2
fi
if ! command -v node >/dev/null; then
    echo "error: node not found; it comes with pi (brew install pi-coding-agent)" >&2
    exit 2
fi

# Saves every test file a `brew --prefix` subprocess; they fall back to running it
# themselves when invoked directly (node --test tests/samples.test.ts).
export PI_CHECK_PREFIX="$PREFIX"

echo "pi: $(pi --version 2>/dev/null | head -1)  upstream: $U"
echo

if node --test --test-reporter=spec "$C"/tests/*.test.ts; then
    echo
    echo "All checks passed."
    exit 0
fi

echo
echo "Problems found. See README.md for the update and sample-regeneration"
echo "procedures. -v adds diffs for drifting vendored files."
exit 1
