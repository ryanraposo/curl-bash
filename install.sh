#!/usr/bin/env bash
set -eEuo pipefail

CURL_BASH_REPOSITORY="ryanraposo/curl-bash"
CURL_BASH_DEFAULT_VERSION="1.0.0"
CURL_BASH_RELEASE_ROOT="${CURL_BASH_RELEASE_BASE_URL:-https://github.com/ryanraposo/curl-bash/releases/download}"
CURL_BASH_REQUIRE_ATTESTATION=false
CURL_BASH_VERIFY_ONLY=false
CURL_BASH_TEMP=""
CURL_BASH_LOCAL_SOURCE=""
CURL_BASH_ENGINE_ARGS=()

cb_info() { printf '\033[34m[INFO]\033[0m %s\n' "$*"; }
cb_ok() { printf '\033[32m[OK]\033[0m %s\n' "$*"; }
cb_die() { printf '\033[31m[ERROR]\033[0m %s\n' "$*" >&2; exit 1; }

cb_usage() {
  cat <<'EOF'
Usage: install.sh [options]

  --agents-only         Install only the portable Agent Skills copy
  --hermes-only         Install only the Hermes-native copy
  --dry-run             Print the verified transaction plan without mutation
  --verify-only         Download and verify the release without installing
  --require-attestation Require GitHub build-provenance verification
  --help                Show this help

Set CURL_BASH_VERSION=X.Y.Z to pin the release downloaded by a piped bootstrap.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --require-attestation) CURL_BASH_REQUIRE_ATTESTATION=true; shift ;;
    --verify-only) CURL_BASH_VERIFY_ONLY=true; shift ;;
    --agents-only|--hermes-only|--dry-run) CURL_BASH_ENGINE_ARGS+=("$1"); shift ;;
    --help|-h) cb_usage; exit 0 ;;
    *) cb_die "unknown option: $1" ;;
  esac
done

[ "${EUID:-$(id -u)}" -ne 0 ] || cb_die "run as the logged-in user, not root"
umask 077

cb_source_ref="${BASH_SOURCE[0]:-}"
if [ -n "$cb_source_ref" ] && [ -f "$cb_source_ref" ]; then
  cb_candidate="$(cd "$(dirname "$cb_source_ref")" && pwd)"
  if [ -f "$cb_candidate/SKILL.md" ] && [ -x "$cb_candidate/scripts/install-skill.sh" ]; then
    CURL_BASH_LOCAL_SOURCE="$cb_candidate"
  fi
fi

if [ -n "$CURL_BASH_LOCAL_SOURCE" ]; then
  cb_info "Using reviewed local checkout: $CURL_BASH_LOCAL_SOURCE"
  if $CURL_BASH_VERIFY_ONLY; then
    "$CURL_BASH_LOCAL_SOURCE/tests/run.sh"
    cb_ok "Local checkout passed its verification suite"
    exit 0
  fi
  exec "$CURL_BASH_LOCAL_SOURCE/scripts/install-skill.sh" \
    --source "$CURL_BASH_LOCAL_SOURCE" "${CURL_BASH_ENGINE_ARGS[@]}"
fi

command -v curl >/dev/null 2>&1 || cb_die "curl is required"
command -v tar >/dev/null 2>&1 || cb_die "tar is required"
cb_version="${CURL_BASH_VERSION:-$CURL_BASH_DEFAULT_VERSION}"
[[ "$cb_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || cb_die "CURL_BASH_VERSION must be X.Y.Z"
cb_asset="curl-bash-$cb_version.tar.gz"
cb_release="$CURL_BASH_RELEASE_ROOT/v$cb_version"
CURL_BASH_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/curl-bash.bootstrap.XXXXXX")"

cb_cleanup() {
  case "$CURL_BASH_TEMP" in
    "${TMPDIR:-/tmp}"/curl-bash.bootstrap.*) rm -rf -- "$CURL_BASH_TEMP" ;;
  esac
}
trap cb_cleanup EXIT HUP INT TERM

cb_fetch() {
  local cb_url="$1" cb_output="$2"
  curl --disable --fail --silent --show-error --location \
    --proto '=https' --proto-redir '=https' --tlsv1.2 \
    --connect-timeout 10 --max-time 120 --retry 3 --retry-max-time 60 \
    --output "$cb_output" "$cb_url"
}

cb_hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{ print tolower($1) }'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{ print tolower($1) }'
  else
    cb_die "sha256sum or shasum is required"
  fi
}

cb_info "[1/4] Fetching versioned release $cb_version..."
cb_fetch "$cb_release/$cb_asset" "$CURL_BASH_TEMP/$cb_asset" || cb_die "release download failed"
cb_fetch "$cb_release/SHA256SUMS" "$CURL_BASH_TEMP/SHA256SUMS" || cb_die "checksum manifest download failed"

cb_info "[2/4] Verifying exact artifact identity and SHA-256..."
cb_expected="$(awk -v wanted="$cb_asset" '
  $1 ~ /^[[:xdigit:]]{64}$/ && $2 == wanted { print tolower($1); count++ }
  END { if (count != 1) exit 1 }
' "$CURL_BASH_TEMP/SHA256SUMS")" || cb_die "manifest must contain exactly one valid entry for $cb_asset"
cb_actual="$(cb_hash_file "$CURL_BASH_TEMP/$cb_asset")"
[ "$cb_actual" = "$cb_expected" ] || cb_die "SHA-256 mismatch for $cb_asset"
cb_ok "SHA-256 verified: $cb_actual"

if $CURL_BASH_REQUIRE_ATTESTATION; then
  command -v gh >/dev/null 2>&1 || cb_die "gh is required by --require-attestation"
  cb_info "[3/4] Verifying GitHub build provenance..."
  gh attestation verify "$CURL_BASH_TEMP/$cb_asset" -R "$CURL_BASH_REPOSITORY" >/dev/null ||
    cb_die "artifact provenance verification failed"
  cb_ok "Build provenance names $CURL_BASH_REPOSITORY"
else
  cb_info "[3/4] Provenance verification not required (use --require-attestation to enforce it)."
fi

cb_info "[4/4] Validating archive paths before extraction..."
cb_seen_root=false
while IFS= read -r cb_member; do
  case "$cb_member" in
    ""|/*|../*|*/../*|*/..|*//$'\n'*) cb_die "unsafe archive member: $cb_member" ;;
    curl-bash-"$cb_version"/*|curl-bash-"$cb_version"/) cb_seen_root=true ;;
    *) cb_die "unexpected archive root: $cb_member" ;;
  esac
done < <(tar -tzf "$CURL_BASH_TEMP/$cb_asset")
$cb_seen_root || cb_die "expected archive root is missing"
mkdir "$CURL_BASH_TEMP/extract"
tar -xzf "$CURL_BASH_TEMP/$cb_asset" -C "$CURL_BASH_TEMP/extract" --no-same-owner --no-same-permissions
cb_engine_root="$CURL_BASH_TEMP/extract/curl-bash-$cb_version"
[ -x "$cb_engine_root/scripts/install-skill.sh" ] || cb_die "verified archive has no transaction engine"
grep -q '^name: curl-bash$' "$cb_engine_root/SKILL.md" || cb_die "verified archive has the wrong skill identity"

if $CURL_BASH_VERIFY_ONLY; then
  cb_ok "Release $cb_version verified; no installation changes made"
  exit 0
fi

trap - EXIT HUP INT TERM
"$cb_engine_root/scripts/install-skill.sh" --source "$cb_engine_root" "${CURL_BASH_ENGINE_ARGS[@]}"
cb_status=$?
cb_cleanup
exit "$cb_status"
