#!/usr/bin/env bash
set -euo pipefail

cb_root="${1:-}"
[ -n "$cb_root" ] && [ -d "$cb_root" ] || { printf 'Usage: audit-installer.sh REPOSITORY\n' >&2; exit 2; }
cb_installer="$cb_root/install.sh"
[ -f "$cb_installer" ] || { printf 'HIGH missing install.sh\n'; exit 1; }
cb_high=0 cb_medium=0 cb_low=0

cb_finding() {
  local cb_severity="$1" cb_message="$2"
  printf '%-6s %s\n' "$cb_severity" "$cb_message"
  case "$cb_severity" in HIGH) cb_high=$((cb_high + 1)) ;; MEDIUM) cb_medium=$((cb_medium + 1)) ;; LOW) cb_low=$((cb_low + 1)) ;; esac
}

grep -Eq '^set -[^[:space:]]*e[^[:space:]]*u|^set -e.*-u|^set -eEuo pipefail' "$cb_installer" || cb_finding HIGH "strict error, unset-variable, and pipeline handling is not evident"
grep -q 'mktemp -d' "$cb_installer" || cb_finding HIGH "private temporary directory is not evident"
grep -Eq "trap .*EXIT|trap .*HUP.*INT.*TERM" "$cb_installer" || cb_finding HIGH "cleanup/signal traps are not evident"
grep -Eq -- "--proto[^\n]*https|--proto-redir[^\n]*https" "$cb_installer" || cb_finding MEDIUM "HTTPS protocol restriction is not evident"
grep -Eq 'sha256sum|shasum -a 256|attestation verify|cosign|minisign' "$cb_root"/install.sh "$cb_root"/scripts/*.sh 2>/dev/null || cb_finding HIGH "artifact verification is not evident"
grep -Eq -- '--dry-run' "$cb_installer" "$cb_root"/scripts/*.sh 2>/dev/null || cb_finding MEDIUM "dry-run interface is not evident"
grep -Eqi 'rollback|transaction' "$cb_installer" "$cb_root"/scripts/*.sh 2>/dev/null || cb_finding HIGH "transaction-wide rollback is not evident"
grep -Eqi 'managed|manifest' "$cb_installer" "$cb_root"/uninstall.sh "$cb_root"/scripts/*.sh 2>/dev/null || cb_finding MEDIUM "ownership markers or manifests are not evident"
grep -Eq '(^|[^[:alnum:]_])eval[[:space:]]|sudo[[:space:]]+(-[^ ]+[[:space:]]+)*bash|curl[^|]*\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh' "$cb_installer" && cb_finding HIGH "dynamic evaluation, whole-shell privilege, or nested curl-pipe execution found"
grep -Eq 'curl .*--insecure|curl .*-k([[:space:]]|$)' "$cb_installer" && cb_finding HIGH "TLS verification appears disabled"
[ -f "$cb_root/tests/run.sh" ] || cb_finding MEDIUM "installer regression suite is missing"
[ -f "$cb_root/SECURITY.md" ] || cb_finding LOW "security reporting policy is missing"

printf '\nsummary: %d high, %d medium, %d low\n' "$cb_high" "$cb_medium" "$cb_low"
[ "$cb_high" -eq 0 ]
