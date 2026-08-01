#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "$0")/.." && pwd)"
project_version="$(tr -d '[:space:]' < "$project_root/VERSION")"
project_dist="${1:-$project_root/dist}"
project_epoch="${SOURCE_DATE_EPOCH:-$(git -C "$project_root" log -1 --format=%ct 2>/dev/null || date +%s)}"
project_prefix="__PROJECT__-$project_version"
mkdir -p "$project_dist"
(cd "$project_root" && find VERSION payload scripts uninstall.sh tests -type f -print | LC_ALL=C sort) > "$project_dist/files.txt"
tar -c -C "$project_root" -T "$project_dist/files.txt" --sort=name \
  --transform="s,^,$project_prefix/," --mtime="@$project_epoch" --owner=0 \
  --group=0 --numeric-owner --format=posix \
  --pax-option=delete=atime,delete=ctime |
  gzip -n > "$project_dist/$project_prefix.tar.gz"
(cd "$project_dist" && sha256sum "$project_prefix.tar.gz" > SHA256SUMS)
