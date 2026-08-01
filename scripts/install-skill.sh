#!/usr/bin/env bash
set -eEuo pipefail

CB_NAME="curl-bash"
CB_REPOSITORY="ryanraposo/curl-bash"
CB_SOURCE=""
CB_MODE=both
CB_DRY_RUN=false
CB_AGENTS_ROOT="${AGENTS_HOME:-${HOME}/.agents}"
CB_HERMES_ROOT="${HERMES_HOME:-${HOME}/.hermes}"
CB_STATE_ROOT="${CURL_BASH_STATE_HOME:-${HOME}/.local/state/$CB_NAME}"
CB_LOCK=""
CB_TRANSACTION=""
CB_ACTIVE=false
CB_COMMITTED=0
CB_LABELS=()
CB_TARGETS=()
CB_TEMPS=()
CB_OLDS=()
CB_OLD_KINDS=()

cb_info() { printf '\033[34m[INFO]\033[0m %s\n' "$*"; }
cb_ok() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
cb_warn() { printf '\033[33m[WARN]\033[0m %s\n' "$*" >&2; }
cb_die() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) CB_SOURCE="${2:-}"; shift 2 ;;
    --agents-only) [ "$CB_MODE" = both ] || cb_die "choose one runtime scope"; CB_MODE=agents; shift ;;
    --hermes-only) [ "$CB_MODE" = both ] || cb_die "choose one runtime scope"; CB_MODE=hermes; shift ;;
    --dry-run) CB_DRY_RUN=true; shift ;;
    *) cb_die "unknown engine option: $1" ;;
  esac
done

[ -n "$CB_SOURCE" ] && [ -d "$CB_SOURCE" ] || cb_die "--source must name the verified payload"
[ "${EUID:-$(id -u)}" -ne 0 ] || cb_die "run as the logged-in user, not root"
grep -q '^name: curl-bash$' "$CB_SOURCE/SKILL.md" || cb_die "source skill identity is invalid"
CB_VERSION="$(tr -d '[:space:]' < "$CB_SOURCE/VERSION")"
[[ "$CB_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || cb_die "source version is invalid"
umask 077

case "$CB_MODE" in both|hermes) CB_LABELS+=(hermes); CB_TARGETS+=("$CB_HERMES_ROOT/skills/$CB_NAME") ;; esac
case "$CB_MODE" in both|agents) CB_LABELS+=(agents); CB_TARGETS+=("$CB_AGENTS_ROOT/skills/$CB_NAME") ;; esac

printf '\n'
cat <<'MASCOT'
< ▄▄ | ▄▄ >   ║
   ▄▀ 0x0 ▀▄   ║
    █  ───  █══╝
    █ VERIFY█
     ▀▀   ▀▀
MASCOT
printf '\n'

cb_info "[1/5] Preflight: source identity, version, tools, and destinations"
command -v awk >/dev/null 2>&1 || cb_die "awk is required"
command -v cp >/dev/null 2>&1 || cb_die "cp is required"
for cb_target in "${CB_TARGETS[@]}"; do
  [ "$cb_target" != "/" ] && [ "$cb_target" != "$HOME" ] || cb_die "unsafe target: $cb_target"
done
cb_ok "curl-bash $CB_VERSION is ready to stage"

cb_info "[2/5] Plan"
for cb_index in "${!CB_TARGETS[@]}"; do
  printf '  %-8s %s\n' "${CB_LABELS[$cb_index]}" "${CB_TARGETS[$cb_index]}"
done
if $CB_DRY_RUN; then
  printf '\nDry run complete. No directories, locks, or backups were created.\n'
  exit 0
fi

CB_TRANSACTION="${CB_STATE_ROOT}/transactions/$(date -u +%Y%m%dT%H%M%SZ)-$$"
CB_LOCK="${CB_STATE_ROOT}/transaction.lock"
mkdir -p "$CB_STATE_ROOT/transactions"
if ! mkdir "$CB_LOCK" 2>/dev/null; then
  cb_die "another curl-bash transaction is active or left $CB_LOCK; inspect it before recovery"
fi
printf 'pid=%s\nstarted=%s\n' "$$" "$(date -u +%FT%TZ)" > "$CB_LOCK/owner"
mkdir "$CB_TRANSACTION"

cb_rollback() {
  local cb_i cb_target cb_old cb_failed
  $CB_ACTIVE || return 0
  cb_warn "rolling back $CB_COMMITTED committed target(s)"
  for ((cb_i=CB_COMMITTED-1; cb_i>=0; cb_i--)); do
    cb_target="${CB_TARGETS[$cb_i]}"
    cb_old="${CB_OLDS[$cb_i]}"
    if [ -e "$cb_target" ] || [ -L "$cb_target" ]; then
      cb_failed="$CB_TRANSACTION/${CB_LABELS[$cb_i]}.failed"
      mv "$cb_target" "$cb_failed" || cb_warn "could not archive failed target $cb_target"
    fi
    if [ -n "$cb_old" ] && { [ -e "$cb_old" ] || [ -L "$cb_old" ]; }; then
      mv "$cb_old" "$cb_target" || cb_warn "manual restore required: $cb_old -> $cb_target"
    fi
  done
  CB_ACTIVE=false
}

cb_cleanup() {
  local cb_temp
  for cb_temp in "${CB_TEMPS[@]:-}"; do
    case "$cb_temp" in */.curl-bash.new.*) [ ! -e "$cb_temp" ] || rm -rf -- "$cb_temp" ;; esac
  done
  if [ -n "$CB_LOCK" ] && [ -d "$CB_LOCK" ]; then
    [ ! -f "$CB_LOCK/owner" ] || unlink "$CB_LOCK/owner"
    rmdir "$CB_LOCK" 2>/dev/null || :
  fi
}

cb_on_exit() {
  local cb_rc=$?
  if [ "$cb_rc" -ne 0 ]; then cb_rollback; fi
  cb_cleanup
  trap - EXIT
  exit "$cb_rc"
}
trap cb_on_exit EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

cb_copy_payload() {
  local cb_label="$1" cb_temp="$2" cb_body
  mkdir -p "$cb_temp/agents" "$cb_temp/runtimes" "$cb_temp/references" "$cb_temp/scripts" "$cb_temp/assets"
  cp "$CB_SOURCE/SKILL.md" "$CB_SOURCE/VERSION" "$CB_SOURCE/LICENSE" "$cb_temp/"
  cp "$CB_SOURCE/agents/openai.yaml" "$cb_temp/agents/"
  cp "$CB_SOURCE/runtimes/hermes-frontmatter.yaml" "$cb_temp/runtimes/"
  cp "$CB_SOURCE/references/"*.md "$cb_temp/references/"
  cp "$CB_SOURCE/scripts/audit-installer.sh" "$CB_SOURCE/scripts/scaffold-installer.sh" "$cb_temp/scripts/"
  cp "$CB_SOURCE/assets/mascot.txt" "$cb_temp/assets/"
  cp -a "$CB_SOURCE/assets/starter" "$cb_temp/assets/"
  chmod +x "$cb_temp/scripts/"*.sh
  if [ "$cb_label" = hermes ]; then
    cb_body="$cb_temp/.skill-body"
    awk 'BEGIN { marks=0 } /^---$/ { marks++; next } marks >= 2 { print }' "$CB_SOURCE/SKILL.md" > "$cb_body"
    cat "$CB_SOURCE/runtimes/hermes-frontmatter.yaml" "$cb_body" > "$cb_temp/SKILL.md"
    rm -f "$cb_body"
    rm -rf "$cb_temp/agents" "$cb_temp/runtimes"
  else
    rm -rf "$cb_temp/runtimes"
  fi
  printf 'managed-by=%s\nversion=%s\nrepository=%s\n' "$CB_NAME" "$CB_VERSION" "$CB_REPOSITORY" > "$cb_temp/.$CB_NAME-managed"
}

cb_info "[3/5] Stage complete runtime-native payloads"
for cb_index in "${!CB_TARGETS[@]}"; do
  cb_target="${CB_TARGETS[$cb_index]}"
  cb_parent="$(dirname "$cb_target")"
  mkdir -p "$cb_parent"
  cb_temp="$cb_parent/.curl-bash.new.$$.$cb_index"
  [ ! -e "$cb_temp" ] || cb_die "staging path already exists: $cb_temp"
  mkdir "$cb_temp"
  CB_TEMPS+=("$cb_temp")
  cb_copy_payload "${CB_LABELS[$cb_index]}" "$cb_temp"
  grep -q '^name: curl-bash$' "$cb_temp/SKILL.md" || cb_die "staged identity failed for ${CB_LABELS[$cb_index]}"
done

cb_info "[4/5] Commit and verify"
CB_ACTIVE=true
for cb_index in "${!CB_TARGETS[@]}"; do
  cb_target="${CB_TARGETS[$cb_index]}"
  cb_old="$(dirname "$cb_target")/.curl-bash.rollback.$$.$cb_index"
  cb_kind=none
  if [ -e "$cb_target" ] || [ -L "$cb_target" ]; then
    [ ! -e "$cb_old" ] || cb_die "rollback path already exists: $cb_old"
    if [ -f "$cb_target/.curl-bash-managed" ]; then cb_kind=managed; else cb_kind=unmanaged; fi
    mv "$cb_target" "$cb_old"
  else
    cb_old=""
  fi
  CB_OLDS+=("$cb_old")
  CB_OLD_KINDS+=("$cb_kind")
  mv "${CB_TEMPS[$cb_index]}" "$cb_target"
  CB_COMMITTED=$((CB_COMMITTED + 1))
  [ "${CURL_BASH_TEST_FAIL_AFTER:-}" != "${CB_LABELS[$cb_index]}" ] || cb_die "injected failure after ${CB_LABELS[$cb_index]} commit"
  [ -f "$cb_target/.curl-bash-managed" ] || cb_die "managed marker verification failed"
  grep -q '^name: curl-bash$' "$cb_target/SKILL.md" || cb_die "installed identity verification failed"
  cb_ok "${CB_LABELS[$cb_index]} committed and verified"
done

cb_info "[5/5] Finalize recoverable backups and receipt"
cb_backup_batch="$CB_STATE_ROOT/backups/$(basename "$CB_TRANSACTION")"
: > "$CB_TRANSACTION/backups.tsv"
for cb_index in "${!CB_OLDS[@]}"; do
  cb_old="${CB_OLDS[$cb_index]}"
  [ -n "$cb_old" ] || continue
  cb_archive="$cb_backup_batch/${CB_LABELS[$cb_index]}.${CB_OLD_KINDS[$cb_index]}"
  mkdir -p "$cb_backup_batch"
  mv "$cb_old" "$cb_archive"
  CB_OLDS[cb_index]="$cb_archive"
  printf '%s\t%s\t%s\n' "${CB_TARGETS[$cb_index]}" "$cb_archive" "${CB_OLD_KINDS[$cb_index]}" >> "$CB_TRANSACTION/backups.tsv"
  [ "${CB_OLD_KINDS[$cb_index]}" != unmanaged ] || cb_warn "preserved unmanaged target -> $cb_archive"
done
cp "$CB_TRANSACTION/backups.tsv" "$CB_STATE_ROOT/latest-backups.tsv"
printf 'version=%s\ninstalled=%s\n' "$CB_VERSION" "$(date -u +%FT%TZ)" > "$CB_TRANSACTION/receipt"
CB_ACTIVE=false

printf '\n     \033[1mPipeline sealed.\033[0m\n\n'
for cb_index in "${!CB_TARGETS[@]}"; do printf '  \033[33m%-12s\033[0m %s\n' "${CB_LABELS[$cb_index]}:" "${CB_TARGETS[$cb_index]}"; done
printf '  \033[33mNext:\033[0m        Start a fresh agent session so curl-bash is discovered.\n\n'
cat <<'MASCOT'
< ▄▄ ✓ ▄▄ >   ║
   ▄▀ ^x^ ▀▄   ║
    █  ───  █══╝
    █ COMMIT█
     ▀▀   ▀▀
MASCOT
printf '\n'
