# Curl-Bash Skill UX Contract

This reference governs workflow decisions around installer design, audit,
mutation, recovery, and release. `SKILL.md` remains the invoked authority.

## Phase transitions

| Phase | Required evidence | Legal next state |
|---|---|---|
| Classify | Request type, target repository, and desired proof known | Inspect |
| Inspect | Bootstrap, engine, uninstall, release, payload, and tests read | Threat-model |
| Threat-model | Origins, identity, authenticity, privilege, targets, and rollback resolved | Preview or ask |
| Preview | Exact mutations, backups, recovery, and verification stated | Apply |
| Apply | Deterministic machinery performs authorized changes | Verify |
| Verify | Persisted state, behavior, rollback, restoration, and release evidence collected | Complete or recover |
| Recover | Partial state classified and reverse plan available | Inspect or apply rollback |
| Complete | Every required check passed | Receipt |

A successful command, checksum match, or CI job is evidence for one layer, not
proof of the entire installer system.

## Assumptions and questions

Infer local, reversible, unprivileged, review-first defaults. Preserve existing
project package, service, config, platform, and rollback semantics unless the
user explicitly authorizes a migration.

Ask when the target or payload is ambiguous, when authenticity policy changes,
when system privilege is required, when a live installation will mutate, or
when publishing and repository settings become part of the work. Ask one
question per decision and never more than three.

## Decision ownership

Recommend one architecture and verification policy. Mention alternatives only
when they materially change trust roots, supported platforms, privileges,
release identity, or recovery guarantees.

## Mutation classes

- **Read-only audit:** inspect and report; findings are leads, not proof.
- **Repository change:** preview files and tests, apply deterministically, and
  verify the actual generated and packaged outputs.
- **Isolated install test:** use temporary homes, state, network, and services.
- **Live installation:** requires explicit scope and a tested rollback route.
- **Privileged host change:** elevate only the smallest direct command.
- **Release publication or repository setting:** irreversible external action;
  require explicit authorization at the boundary.

## Trust layers

Keep these distinct:

1. **Transport:** HTTPS endpoint and redirect policy.
2. **Artifact identity:** exact expected name and version.
3. **Integrity:** digest or signature matches downloaded bytes.
4. **Authenticity/provenance:** an independent trust root names origin and
   workflow.
5. **Archive safety:** members, roots, types, links, paths, and modes are safe.
6. **Transaction safety:** preflight, plan, stage, commit, verify, finalize, and
   reverse rollback.
7. **Release identity:** deterministic assets, checksums, attestations, and
   immutable publication policy.

Never let evidence from one layer impersonate another.

## Failure budget and recovery

A failed verification blocks completion. A later passing check does not erase
an earlier unexplained failure. On transaction failure, roll back committed
targets in reverse order and preserve failed evidence. On release failure,
leave the release draft or unpublished and report the exact incomplete state.

## Proof and receipt

Completion evidence should cover:

- syntax and ShellCheck;
- true piped execution and exact argument forwarding;
- HTTP, checksum, provenance, archive, and platform failures;
- dry-run non-mutation and noninteractive behavior;
- idempotency, unmanaged collision, rollback, uninstall, and restore;
- installed runtime payload identity and executable modes;
- reproducible packaging and complete release assets;
- rendered README, Pages, and live commands when they are in scope.

Finish with exact changes, checks, failures encountered, rollback or recovery,
remaining trust assumptions, and one meaningful next action.

## Honest boundary

Static audit cannot prove runtime safety. Same-origin checksums do not create an
independent trust root. Provenance proves origin, not absence of vulnerabilities.
Local event records and receipts are evidence, not external signatures.
