#!/usr/bin/env bash
set -euo pipefail

CB_NAME="curl-bash"
CB_AGENTS_ROOT="${AGENTS_HOME:-${HOME}/.agents}"
CB_HERMES_ROOT="${HERMES_HOME:-${HOME}/.hermes}"
CB_STATE_ROOT="${CURL_BASH_STATE_HOME:-${HOME}/.local/state/$CB_NAME}"
CB_MODE=both
CB_RESTORE=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --agents-only) [ "$CB_MODE" = both ] || exit 2; CB_MODE=agents; shift ;;
    --hermes-only) [ "$CB_MODE" = both ] || exit 2; CB_MODE=hermes; shift ;;
    --restore) CB_RESTORE=true; shift ;;
    --help|-h) printf 'Usage: uninstall.sh [--agents-only|--hermes-only] [--restore]\n'; exit 0 ;;
    *) printf 'error: unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
done

cb_removed="$CB_STATE_ROOT/removed/$(date -u +%Y%m%dT%H%M%SZ)-$$"
cb_manifest="$CB_STATE_ROOT/latest-backups.tsv"

cb_remove() {
  local cb_label="$1" cb_target="$2" cb_backup
  [ -e "$cb_target" ] || [ -L "$cb_target" ] || { printf 'not installed: %s\n' "$cb_target"; return 0; }
  [ -f "$cb_target/.curl-bash-managed" ] || { printf 'refused unmanaged target: %s\n' "$cb_target" >&2; return 1; }
  mkdir -p "$cb_removed"
  mv "$cb_target" "$cb_removed/$cb_label"
  printf 'archived managed copy: %s\n' "$cb_removed/$cb_label"
  if $CB_RESTORE && [ -f "$cb_manifest" ]; then
    cb_backup="$(awk -F '\t' -v target="$cb_target" '$1 == target && $3 == "unmanaged" { value=$2 } END { print value }' "$cb_manifest")"
    if [ -n "$cb_backup" ] && { [ -e "$cb_backup" ] || [ -L "$cb_backup" ]; }; then
      mkdir -p "$(dirname "$cb_target")"
      mv "$cb_backup" "$cb_target"
      printf 'restored unmanaged target: %s\n' "$cb_target"
    fi
  fi
}

cb_result=0
case "$CB_MODE" in both|hermes) cb_remove hermes "$CB_HERMES_ROOT/skills/$CB_NAME" || cb_result=1 ;; esac
case "$CB_MODE" in both|agents) cb_remove agents "$CB_AGENTS_ROOT/skills/$CB_NAME" || cb_result=1 ;; esac
exit "$cb_result"
