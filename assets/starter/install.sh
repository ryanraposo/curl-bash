#!/usr/bin/env bash
set -eEuo pipefail

PROJECT_NAME="__PROJECT__"
PROJECT_REPOSITORY="__REPOSITORY__"
PROJECT_DEFAULT_VERSION="__VERSION__"
PROJECT_RELEASE_ROOT="${PROJECT_RELEASE_BASE_URL:-https://github.com/__REPOSITORY__/releases/download}"
PROJECT_REQUIRE_ATTESTATION=false
PROJECT_VERIFY_ONLY=false
PROJECT_TEMP=""
PROJECT_ENGINE_ARGS=()

fail() { printf 'error: %s\n' "$*" >&2; exit 1; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --require-attestation) PROJECT_REQUIRE_ATTESTATION=true; shift ;;
    --verify-only) PROJECT_VERIFY_ONLY=true; shift ;;
    --dry-run|--yes) PROJECT_ENGINE_ARGS+=("$1"); shift ;;
    --help|-h) printf 'Usage: install.sh [--require-attestation] [--verify-only] [--dry-run] [--yes]\n'; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done
[ "${EUID:-$(id -u)}" -ne 0 ] || fail "run as the user, not root"
umask 077

project_source_ref="${BASH_SOURCE[0]:-}"
if [ -n "$project_source_ref" ] && [ -f "$project_source_ref" ]; then
  project_source="$(cd "$(dirname "$project_source_ref")" && pwd)"
else
  project_source=""
fi
if [ -n "$project_source" ] && [ -x "$project_source/scripts/install-core.sh" ] && [ -d "$project_source/payload" ]; then
  $PROJECT_VERIFY_ONLY && { "$project_source/tests/run.sh"; exit; }
  exec "$project_source/scripts/install-core.sh" --source "$project_source" "${PROJECT_ENGINE_ARGS[@]}"
fi

command -v curl >/dev/null 2>&1 || fail "curl is required"
project_version="${PROJECT_VERSION:-$PROJECT_DEFAULT_VERSION}"
[[ "$project_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "PROJECT_VERSION must be X.Y.Z"
project_asset="$PROJECT_NAME-$project_version.tar.gz"
project_release="$PROJECT_RELEASE_ROOT/v$project_version"
PROJECT_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/$PROJECT_NAME.bootstrap.XXXXXX")"
cleanup() { case "$PROJECT_TEMP" in "${TMPDIR:-/tmp}"/"$PROJECT_NAME".bootstrap.*) rm -rf -- "$PROJECT_TEMP" ;; esac; }
trap cleanup EXIT HUP INT TERM

fetch() {
  curl --disable --fail --silent --show-error --location \
    --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --connect-timeout 10 --max-time 120 --retry 3 --retry-max-time 60 \
    --output "$2" "$1"
}
fetch "$project_release/$project_asset" "$PROJECT_TEMP/$project_asset" || fail "release download failed"
fetch "$project_release/SHA256SUMS" "$PROJECT_TEMP/SHA256SUMS" || fail "manifest download failed"
project_expected="$(awk -v wanted="$project_asset" '$1 ~ /^[[:xdigit:]]{64}$/ && $2 == wanted { print tolower($1); n++ } END { if (n != 1) exit 1 }' "$PROJECT_TEMP/SHA256SUMS")" || fail "invalid manifest"
if command -v sha256sum >/dev/null 2>&1; then project_actual="$(sha256sum "$PROJECT_TEMP/$project_asset" | awk '{print tolower($1)}')"; else project_actual="$(shasum -a 256 "$PROJECT_TEMP/$project_asset" | awk '{print tolower($1)}')"; fi
[ "$project_actual" = "$project_expected" ] || fail "SHA-256 mismatch"
if $PROJECT_REQUIRE_ATTESTATION; then
  command -v gh >/dev/null 2>&1 || fail "gh is required"
  gh attestation verify "$PROJECT_TEMP/$project_asset" -R "$PROJECT_REPOSITORY" >/dev/null || fail "provenance failed"
fi
while IFS= read -r member; do case "$member" in ""|/*|../*|*/../*|*/.. ) fail "unsafe archive member: $member" ;; "$PROJECT_NAME-$project_version"/*|"$PROJECT_NAME-$project_version"/) : ;; *) fail "unexpected archive root: $member" ;; esac; done < <(tar -tzf "$PROJECT_TEMP/$project_asset")
mkdir "$PROJECT_TEMP/extract"
tar -xzf "$PROJECT_TEMP/$project_asset" -C "$PROJECT_TEMP/extract" --no-same-owner --no-same-permissions
project_root="$PROJECT_TEMP/extract/$PROJECT_NAME-$project_version"
[ -x "$project_root/scripts/install-core.sh" ] || fail "transaction engine missing"
$PROJECT_VERIFY_ONLY && { printf 'verified %s\n' "$project_asset"; exit; }
trap - EXIT HUP INT TERM
"$project_root/scripts/install-core.sh" --source "$project_root" "${PROJECT_ENGINE_ARGS[@]}"
project_status=$?
cleanup
exit "$project_status"
