#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
project_tmp="$(mktemp -d)"
trap 'rm -rf "$project_tmp"' EXIT
for script in "$project_root/install.sh" "$project_root/uninstall.sh" "$project_root/scripts/"*.sh; do bash -n "$script"; done
PROJECT_INSTALL_ROOT="$project_tmp/install" PROJECT_STATE_HOME="$project_tmp/state" "$project_root/install.sh" --dry-run >/dev/null
[ ! -e "$project_tmp/install" ]
PROJECT_INSTALL_ROOT="$project_tmp/install" PROJECT_STATE_HOME="$project_tmp/state" "$project_root/install.sh" >/dev/null
[ -f "$project_tmp/install/.__PROJECT__-managed" ]
printf original > "$project_tmp/install/original"
PROJECT_INSTALL_ROOT="$project_tmp/install" PROJECT_STATE_HOME="$project_tmp/state" "$project_root/install.sh" >/dev/null
[ ! -e "$project_tmp/install/original" ]
PROJECT_INSTALL_ROOT="$project_tmp/install" PROJECT_STATE_HOME="$project_tmp/state" "$project_root/uninstall.sh" --restore >/dev/null
[ -e "$project_tmp/install/original" ]
printf 'starter tests passed\n'
