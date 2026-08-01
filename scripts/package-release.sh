#!/usr/bin/env bash
set -euo pipefail

cb_root="$(cd "$(dirname "$0")/.." && pwd)"
cb_version="$(tr -d '[:space:]' < "$cb_root/VERSION")"
cb_dist="${1:-$cb_root/dist}"
cb_epoch="${SOURCE_DATE_EPOCH:-$(git -C "$cb_root" log -1 --format=%ct 2>/dev/null || date +%s)}"
cb_prefix="curl-bash-$cb_version"
mkdir -p "$cb_dist"
cb_archive="$cb_dist/$cb_prefix.tar.gz"
cb_files="$cb_dist/files.txt"
(cd "$cb_root" && find SKILL.md AGENTS.md README.md SECURITY.md CONTRIBUTING.md VERSION LICENSE install.sh uninstall.sh agents runtimes references scripts assets tests -type f -print | LC_ALL=C sort) > "$cb_files"
tar --create --directory "$cb_root" --files-from "$cb_files" --sort=name \
  --transform="s,^,$cb_prefix/," --mtime="@$cb_epoch" --owner=0 --group=0 \
  --numeric-owner --format=posix --pax-option=delete=atime,delete=ctime |
  gzip -n > "$cb_archive"
(cd "$cb_dist" && sha256sum "$(basename "$cb_archive")" > SHA256SUMS)
printf '%s\n' "$cb_archive"
