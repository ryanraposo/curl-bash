#!/usr/bin/env bash
# shellcheck disable=SC2016 # Literal contract patterns intentionally contain shell syntax.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

description() {
  sed -n 's/^description:[[:space:]]*//p' "$1" | head -n1
}

portable_description=$(description "$ROOT/SKILL.md")
hermes_description=$(description "$ROOT/runtimes/hermes-frontmatter.yaml")
[ -n "$portable_description" ] || fail "portable skill has a description"
[ -n "$hermes_description" ] || fail "Hermes skill has a description"
[ "${#portable_description}" -lt 60 ] || fail "portable description is below 60 characters"
[ "${#hermes_description}" -lt 60 ] || fail "Hermes description is below 60 characters"
[ "$portable_description" = "$hermes_description" ] || fail "runtime descriptions stay identical"
pass "runtime descriptions are identical and ${#portable_description} characters"

grep -q '^## Workflow Contract$' "$ROOT/SKILL.md" || fail "skill owns the workflow"
grep -q '^## Completion Gate$' "$ROOT/SKILL.md" || fail "skill defines completion"
pass "runtime workflow and completion gate are explicit"

grep -q '^## Maintaining this repository$' "$ROOT/AGENTS.md" || fail "repository guide owns maintenance"
grep -q 'Keep `AGENTS.md` repository-facing and `SKILL.md` invocation-facing' \
  "$ROOT/AGENTS.md" || fail "repository and runtime authority stay distinct"
pass "repository guidance stays repository-facing"

test -f "$ROOT/references/skill-ux-contract.md" || fail "skill UX contract exists"
grep -q '^## Phase transitions$' "$ROOT/references/skill-ux-contract.md" || fail "skill UX contract defines phases"
grep -q 'cp "$CB_SOURCE/references/"\*.md' "$ROOT/scripts/install-skill.sh" || fail "installer copies all references"
grep -q ' references ' "$ROOT/scripts/package-release.sh" || fail "release packages references"
pass "skill UX contract is installed and packaged"

version=$(tr -d '[:space:]' < "$ROOT/VERSION")
grep -q "^version: ${version}$" "$ROOT/runtimes/hermes-frontmatter.yaml" || fail "Hermes version matches VERSION"
pass "version identity is consistent"
