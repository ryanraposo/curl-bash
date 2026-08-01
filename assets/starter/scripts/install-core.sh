#!/usr/bin/env bash
set -eEuo pipefail

PROJECT_NAME="__PROJECT__"
PROJECT_SOURCE=""
PROJECT_DRY_RUN=false
PROJECT_YES=false
PROJECT_INSTALL_ROOT="${PROJECT_INSTALL_ROOT:-${XDG_DATA_HOME:-${HOME}/.local/share}/$PROJECT_NAME}"
PROJECT_STATE_ROOT="${PROJECT_STATE_HOME:-${XDG_STATE_HOME:-${HOME}/.local/state}/$PROJECT_NAME}"
while [ "$#" -gt 0 ]; do case "$1" in --source) PROJECT_SOURCE="${2:-}"; shift 2 ;; --dry-run) PROJECT_DRY_RUN=true; shift ;; --yes) PROJECT_YES=true; shift ;; *) printf 'error: unknown engine option: %s\n' "$1" >&2; exit 2 ;; esac; done
[ -d "$PROJECT_SOURCE/payload" ] || { printf 'error: payload missing\n' >&2; exit 1; }
if [ "$PROJECT_INSTALL_ROOT" = "/" ] || [ "$PROJECT_INSTALL_ROOT" = "$HOME" ]; then
  printf 'error: unsafe target\n' >&2
  exit 1
fi
printf '[1/5] preflight\n[2/5] plan: %s\n' "$PROJECT_INSTALL_ROOT"
if $PROJECT_YES; then printf 'noninteractive policy: yes\n'; fi
$PROJECT_DRY_RUN && { printf 'dry run complete; no changes made\n'; exit; }
project_parent="$(dirname "$PROJECT_INSTALL_ROOT")"
mkdir -p "$project_parent" "$PROJECT_STATE_ROOT/transactions"
project_lock="$PROJECT_STATE_ROOT/transaction.lock"
mkdir "$project_lock" 2>/dev/null || { printf 'error: transaction lock exists: %s\n' "$project_lock" >&2; exit 1; }
project_transaction="$PROJECT_STATE_ROOT/transactions/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir "$project_transaction"
project_stage="$project_parent/.$PROJECT_NAME.new.$$"
project_old="$project_parent/.$PROJECT_NAME.rollback.$$"
project_committed=false
cleanup() { [ ! -e "$project_stage" ] || rm -rf -- "$project_stage"; rmdir "$project_lock" 2>/dev/null || :; }
rollback() { if $project_committed; then [ ! -e "$PROJECT_INSTALL_ROOT" ] || mv "$PROJECT_INSTALL_ROOT" "$project_transaction/failed"; [ ! -e "$project_old" ] || mv "$project_old" "$PROJECT_INSTALL_ROOT"; fi; }
on_exit() { project_rc=$?; [ "$project_rc" -eq 0 ] || rollback; cleanup; trap - EXIT; exit "$project_rc"; }
trap on_exit EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM
printf '[3/5] stage\n'
mkdir "$project_stage"
cp -a "$PROJECT_SOURCE/payload/." "$project_stage/"
printf 'managed-by=%s\nversion=__VERSION__\nrepository=__REPOSITORY__\n' "$PROJECT_NAME" > "$project_stage/.$PROJECT_NAME-managed"
printf '[4/5] commit and verify\n'
if [ -e "$PROJECT_INSTALL_ROOT" ] || [ -L "$PROJECT_INSTALL_ROOT" ]; then mv "$PROJECT_INSTALL_ROOT" "$project_old"; fi
mv "$project_stage" "$PROJECT_INSTALL_ROOT"
project_committed=true
[ "${PROJECT_TEST_FAIL_AFTER_COMMIT:-0}" != 1 ] || { printf 'error: injected failure\n' >&2; exit 1; }
[ -f "$PROJECT_INSTALL_ROOT/.$PROJECT_NAME-managed" ] || { printf 'error: marker verification failed\n' >&2; exit 1; }
printf '[5/5] finalize\n'
if [ -e "$project_old" ] || [ -L "$project_old" ]; then
  project_backup="$PROJECT_STATE_ROOT/backups/$(basename "$project_transaction")"
  mkdir -p "$(dirname "$project_backup")"
  mv "$project_old" "$project_backup"
  printf '%s\t%s\n' "$PROJECT_INSTALL_ROOT" "$project_backup" > "$PROJECT_STATE_ROOT/latest-backup.tsv"
fi
project_committed=false
printf 'installed: %s\nNext: run the project-specific verification command documented by the maintainer.\n' "$PROJECT_INSTALL_ROOT"
