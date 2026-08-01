# Threat model

## Contents

- Assets and trust roots
- Adversaries
- Boundaries
- Policy tiers
- Non-goals

## Assets and trust roots

Protect the user's account, home directory, system configuration, credentials,
shell startup files, services, package databases, existing installations, and
the integrity of the requested program. Enumerate every trusted component:
bootstrap URL, TLS PKI, redirects, release origin, repository controls, hosted
builder, verification client, signing identity, and local extraction tools.

The bootstrap is a root of trust. A digest fetched from the same endpoint does
not independently authenticate it. A pinned bootstrap digest or reviewed local
copy, immutable versioned release, and verified hosted-build provenance reduce
different risks; none proves the source has no vulnerabilities.

## Adversaries

Consider a network attacker, compromised DNS or CA, compromised hosting or
repository account, mutable tag or release asset, malicious dependency or CI
action, pull-request script injection, poisoned local environment, hostile
archive paths, symlink attacks, interrupted power/session, concurrent
installers, and an honest but buggy release.

## Boundaries

Document:

- which code executes before artifact verification;
- which hostnames redirects may reach;
- which identity provenance must name;
- which paths can change and under which user;
- which steps request privilege;
- which state is backed up, how long, and how it is restored;
- whether installation is concurrent-safe;
- which inputs may contain secrets or untrusted strings.

Never interpolate untrusted metadata into shell source, `eval`, `sh -c`, a
command string, an unquoted glob, or a workflow expression embedded in `run:`.

## Policy tiers

### Baseline

Use a reviewed or HTTPS-fetched bootstrap, exact versioned asset, SHA-256,
private staging, archive validation, unprivileged transaction, backups, and
rollback. Document the same-origin checksum limitation.

### Verified provenance

Require `gh attestation verify ARTIFACT -R OWNER/REPO` or an equivalent
identity-bound signature check. Fail closed when verification is required and
the verifier, network, identity, or transparency service is unavailable.

### High assurance

Distribute a pinned bootstrap hash through a separate channel, require
provenance policy, use immutable releases, protect release environments and
tags, require reviewed changes and signed commits where appropriate, minimize
third-party CI, and consider ecosystem-native packages instead of curl-bash.

## Non-goals

Checksums and attestations do not establish code quality, freedom from
vulnerabilities, trustworthy transitive dependencies, or safety of an
authorized privileged action. State those limits.
