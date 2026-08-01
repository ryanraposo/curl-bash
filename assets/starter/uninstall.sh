#!/usr/bin/env bash
set -euo pipefail
PROJECT_NAME="__PROJECT__"
PROJECT_INSTALL_ROOT="${PROJECT_INSTALL_ROOT:-${XDG_DATA_HOME:-${HOME}/.local/share}/$PROJECT_NAME}"
PROJECT_STATE_ROOT="${PROJECT_STATE_HOME:-${XDG_STATE_HOME:-${HOME}/.local/state}/$PROJECT_NAME}"
PROJECT_RESTORE=false
[ "${1:-}" != --restore ] || PROJECT_RESTORE=true
[ -e "$PROJECT_INSTALL_ROOT" ] || { printf 'not installed\n'; exit; }
[ -f "$PROJECT_INSTALL_ROOT/.$PROJECT_NAME-managed" ] || { printf 'refused unmanaged target\n' >&2; exit 1; }
project_removed="$PROJECT_STATE_ROOT/removed/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$(dirname "$project_removed")"
mv "$PROJECT_INSTALL_ROOT" "$project_removed"
if $PROJECT_RESTORE && [ -f "$PROJECT_STATE_ROOT/latest-backup.tsv" ]; then
  project_backup="$(awk -F '\t' -v target="$PROJECT_INSTALL_ROOT" '$1 == target { print $2 }' "$PROJECT_STATE_ROOT/latest-backup.tsv")"
  [ -z "$project_backup" ] || [ ! -e "$project_backup" ] || mv "$project_backup" "$PROJECT_INSTALL_ROOT"
fi
printf 'archived: %s\n' "$project_removed"
