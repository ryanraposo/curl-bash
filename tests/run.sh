#!/usr/bin/env bash
# shellcheck disable=SC2016 # sh -c snippets intentionally expand positional parameters in the child shell.
set -euo pipefail

cb_root="$(cd "$(dirname "$0")/.." && pwd)"
cb_tmp="$(mktemp -d)"
trap 'rm -rf "$cb_tmp"' EXIT
cb_passed=0 cb_failed=0
pass() { printf 'ok - %s\n' "$1"; ((cb_passed++)) || :; }
fail() { printf 'not ok - %s\n' "$1" >&2; ((cb_failed++)) || :; }
assert() { local cb_name="$1"; shift; if "$@"; then pass "$cb_name"; else fail "$cb_name"; fi; }

while IFS= read -r cb_script; do assert "syntax: ${cb_script#"$cb_root/"}" bash -n "$cb_script"; done < <(find "$cb_root" -type f -name '*.sh' | sort)
cb_validator="${SKILL_VALIDATOR:-${HOME}/.codex/skills/.system/skill-creator/scripts/quick_validate.py}"
if [ -f "$cb_validator" ]; then assert "skill metadata validates" python3 "$cb_validator" "$cb_root"; fi
assert "OpenAI frontmatter stays minimal" sh -c '! sed -n "2,/^---$/p" "$1" | grep -Eq "^(version|author|license|platforms|metadata):"' sh "$cb_root/SKILL.md"
assert "Hermes payload is versioned" grep -q '^version: 1.0.0$' "$cb_root/runtimes/hermes-frontmatter.yaml"
assert "AGENTS routes audits through sources" grep -q 'references/primary-sources.md' "$cb_root/AGENTS.md"
assert "Piper has two poses" sh -c 'grep -q "checking the line" "$1" && grep -q "committed" "$1"' sh "$cb_root/assets/mascot.txt"
assert "social preview is exactly 1280x640" python3 - "$cb_root/assets/github-social-preview.png" <<'PY'
import pathlib
import struct
import sys

data = pathlib.Path(sys.argv[1]).read_bytes()
assert data[:8] == b"\x89PNG\r\n\x1a\n"
assert struct.unpack(">II", data[16:24]) == (1280, 640)
PY
assert "Pages landing page carries both Piper poses" sh -c 'grep -q "VERIFY" "$1" && grep -q "COMMIT" "$1"' sh "$cb_root/index.html"
assert "Pages command uses HTTPS-only curl policy" grep -Fq "curl -fsSL --proto '=https' --tlsv1.2 https://ryanraposo.github.io/curl-bash/install.sh | bash" "$cb_root/index.html"
assert "Pages copy control is accessible" grep -q 'aria-label="Copy install command"' "$cb_root/index.html"

cb_agents="$cb_tmp/agents" cb_hermes="$cb_tmp/hermes" cb_state="$cb_tmp/state"
cb_dry="$cb_tmp/dry.out"
AGENTS_HOME="$cb_agents" HERMES_HOME="$cb_hermes" CURL_BASH_STATE_HOME="$cb_state" "$cb_root/install.sh" --dry-run > "$cb_dry"
assert "dry-run reports the plan" grep -q 'Dry run complete' "$cb_dry"
assert "dry-run creates no skill homes" sh -c '[ ! -e "$1" ] && [ ! -e "$2" ]' sh "$cb_agents" "$cb_hermes"

cb_install_out="$cb_tmp/install.out"
AGENTS_HOME="$cb_agents" HERMES_HOME="$cb_hermes" CURL_BASH_STATE_HOME="$cb_state" "$cb_root/install.sh" > "$cb_install_out"
assert "installer prints five phases" sh -c 'for n in 1 2 3 4 5; do grep -q "\[$n/5\]" "$1" || exit 1; done' sh "$cb_install_out"
assert "installer starts and finishes with Piper" sh -c 'grep -q VERIFY "$1" && grep -q COMMIT "$1"' sh "$cb_install_out"
assert "Hermes skill is runtime-native" sh -c 'grep -q "^version: 1.0.0$" "$1" && [ ! -e "$(dirname "$1")/agents" ]' sh "$cb_hermes/skills/curl-bash/SKILL.md"
assert "Agent Skills copy keeps OpenAI metadata" test -f "$cb_agents/skills/curl-bash/agents/openai.yaml"
assert "installed scaffold remains executable" test -x "$cb_agents/skills/curl-bash/scripts/scaffold-installer.sh"

AGENTS_HOME="$cb_agents" HERMES_HOME="$cb_hermes" CURL_BASH_STATE_HOME="$cb_state" "$cb_root/install.sh" >/dev/null
assert "rerun converges to a managed install" test -f "$cb_agents/skills/curl-bash/.curl-bash-managed"

cb_collision="$cb_tmp/collision-agents"
mkdir -p "$cb_collision/skills/curl-bash"
printf 'original\n' > "$cb_collision/skills/curl-bash/original.txt"
AGENTS_HOME="$cb_collision" HERMES_HOME="$cb_tmp/collision-hermes" CURL_BASH_STATE_HOME="$cb_tmp/collision-state" "$cb_root/install.sh" --agents-only >/dev/null 2>&1
AGENTS_HOME="$cb_collision" HERMES_HOME="$cb_tmp/collision-hermes" CURL_BASH_STATE_HOME="$cb_tmp/collision-state" "$cb_root/uninstall.sh" --agents-only --restore >/dev/null
assert "uninstall restores an unmanaged collision" test -f "$cb_collision/skills/curl-bash/original.txt"

cb_rollback_agents="$cb_tmp/rollback-agents"
cb_rollback_hermes="$cb_tmp/rollback-hermes"
mkdir -p "$cb_rollback_agents/skills/curl-bash" "$cb_rollback_hermes/skills/curl-bash"
printf 'agent-old\n' > "$cb_rollback_agents/skills/curl-bash/sentinel"
printf 'hermes-old\n' > "$cb_rollback_hermes/skills/curl-bash/sentinel"
cb_rollback_rc=0
AGENTS_HOME="$cb_rollback_agents" HERMES_HOME="$cb_rollback_hermes" CURL_BASH_STATE_HOME="$cb_tmp/rollback-state" CURL_BASH_TEST_FAIL_AFTER=hermes \
  "$cb_root/scripts/install-skill.sh" --source "$cb_root" >/dev/null 2>&1 || cb_rollback_rc=$?
assert "injected mid-transaction failure is reported" test "$cb_rollback_rc" -ne 0
assert "Hermes prior state is restored byte-for-byte" grep -qx hermes-old "$cb_rollback_hermes/skills/curl-bash/sentinel"
assert "uncommitted Agent Skills state is untouched" grep -qx agent-old "$cb_rollback_agents/skills/curl-bash/sentinel"

cb_scaffold="$cb_tmp/scaffold"
"$cb_root/scripts/scaffold-installer.sh" --project acme --repository example/acme --version 2.3.4 "$cb_scaffold" >/dev/null
assert "scaffold replaces all identity tokens" sh -c '! grep -R "__[A-Z]" "$1" --exclude-dir=.git | grep -q .' sh "$cb_scaffold"
assert "scaffold starter passes its own tests" "$cb_scaffold/tests/run.sh"
assert "auditor finds no high-severity issue in starter" "$cb_root/scripts/audit-installer.sh" "$cb_scaffold"

cb_dist_one="$cb_tmp/dist-one" cb_dist_two="$cb_tmp/dist-two"
SOURCE_DATE_EPOCH=1700000000 "$cb_root/scripts/package-release.sh" "$cb_dist_one" >/dev/null
SOURCE_DATE_EPOCH=1700000000 "$cb_root/scripts/package-release.sh" "$cb_dist_two" >/dev/null
assert "release archive checksum verifies" sh -c 'cd "$1" && sha256sum -c SHA256SUMS >/dev/null' sh "$cb_dist_one"
assert "release archive is reproducible" cmp -s "$cb_dist_one/curl-bash-1.0.0.tar.gz" "$cb_dist_two/curl-bash-1.0.0.tar.gz"

cb_remote="$cb_tmp/remote"
mkdir -p "$cb_remote/v1.0.0"
cp "$cb_dist_one/curl-bash-1.0.0.tar.gz" "$cb_dist_one/SHA256SUMS" "$cb_remote/v1.0.0/"
cb_mock_bin="$cb_tmp/mock-bin"
mkdir "$cb_mock_bin"
cat > "$cb_mock_bin/curl" <<'SH'
#!/usr/bin/env bash
output="" url=""
while [ "$#" -gt 0 ]; do
  case "$1" in --output) output="$2"; shift 2 ;; -o) output="$2"; shift 2 ;; -*) shift ;; *) url="$1"; shift ;; esac
done
relative=${url#https://mock/}
cp "$MOCK_RELEASE_ROOT/$relative" "$output"
SH
chmod +x "$cb_mock_bin/curl"
cb_remote_agents="$cb_tmp/remote-agents"
cb_remote_hermes="$cb_tmp/remote-hermes"
AGENTS_HOME="$cb_remote_agents" HERMES_HOME="$cb_remote_hermes" CURL_BASH_STATE_HOME="$cb_tmp/remote-state" \
MOCK_RELEASE_ROOT="$cb_remote" CURL_BASH_RELEASE_BASE_URL=https://mock PATH="$cb_mock_bin:/usr/bin:/bin" \
  bash < "$cb_root/install.sh" >/dev/null
assert "true piped bootstrap installs verified release" test -f "$cb_remote_agents/skills/curl-bash/.curl-bash-managed"

printf 'tampered' >> "$cb_remote/v1.0.0/curl-bash-1.0.0.tar.gz"
cb_bad_agents="$cb_tmp/bad-agents" cb_bad_rc=0
AGENTS_HOME="$cb_bad_agents" HERMES_HOME="$cb_tmp/bad-hermes" CURL_BASH_STATE_HOME="$cb_tmp/bad-state" \
MOCK_RELEASE_ROOT="$cb_remote" CURL_BASH_RELEASE_BASE_URL=https://mock PATH="$cb_mock_bin:/usr/bin:/bin" \
  bash < "$cb_root/install.sh" >/dev/null 2>&1 || cb_bad_rc=$?
assert "checksum mismatch fails closed" test "$cb_bad_rc" -ne 0
assert "checksum failure happens before target mutation" test ! -e "$cb_bad_agents"

printf '\n%d passed, %d failed\n' "$cb_passed" "$cb_failed"
[ "$cb_failed" -eq 0 ]
