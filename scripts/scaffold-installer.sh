#!/usr/bin/env bash
set -euo pipefail

cb_root="$(cd "$(dirname "$0")/.." && pwd)"
cb_project="" cb_repository="" cb_version="" cb_destination=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --project) cb_project="${2:-}"; shift 2 ;;
    --repository) cb_repository="${2:-}"; shift 2 ;;
    --version) cb_version="${2:-}"; shift 2 ;;
    --help|-h)
      printf 'Usage: scaffold-installer.sh --project NAME --repository OWNER/REPO --version X.Y.Z DESTINATION\n'
      exit 0 ;;
    -*) printf 'error: unknown option: %s\n' "$1" >&2; exit 2 ;;
    *) [ -z "$cb_destination" ] || { printf 'error: one destination is allowed\n' >&2; exit 2; }; cb_destination="$1"; shift ;;
  esac
done

[[ "$cb_project" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || { printf 'error: invalid project name\n' >&2; exit 2; }
[[ "$cb_repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || { printf 'error: repository must be OWNER/REPO\n' >&2; exit 2; }
[[ "$cb_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { printf 'error: version must be X.Y.Z\n' >&2; exit 2; }
[ -n "$cb_destination" ] || { printf 'error: destination is required\n' >&2; exit 2; }

if [ -e "$cb_destination" ] && find "$cb_destination" -mindepth 1 -print -quit 2>/dev/null | grep -q .; then
  printf 'error: destination is not empty: %s\n' "$cb_destination" >&2
  exit 1
fi
mkdir -p "$cb_destination"
cp -a "$cb_root/assets/starter/." "$cb_destination/"

python3 - "$cb_destination" "$cb_project" "$cb_repository" "$cb_version" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
project, repository, version = sys.argv[2:]
replacements = {
    "__PROJECT__": project,
    "__REPOSITORY__": repository,
    "__VERSION__": version,
    "__OWNER__": repository.split("/", 1)[0],
}
for path in root.rglob("*"):
    if not path.is_file():
        continue
    text = path.read_text()
    for old, new in replacements.items():
        text = text.replace(old, new)
    path.write_text(text)
PY
chmod +x "$cb_destination/install.sh" "$cb_destination/uninstall.sh" "$cb_destination/scripts/"*.sh "$cb_destination/tests/run.sh"
printf 'scaffolded %s installer in %s\n' "$cb_project" "$cb_destination"
printf 'Next: replace payload/, implement project postcondition checks, and run ./tests/run.sh\n'
