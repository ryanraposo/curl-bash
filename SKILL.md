---
name: curl-bash
description: Build and audit safe curl-pipe installers.
---

# Engineer Curl-to-Bash Installers

Treat an installer as a package manager in miniature. It crosses a remote-code
trust boundary, changes durable state, and must remain recoverable when any
individual step fails.

Use this skill for install.sh bootstraps, remote shell installers, one-command setup flows, uninstallers, updaters, release-asset delivery, checksum or provenance verification, transactional installs, idempotency, backup, rollback, dry-run, installer CI, and supply-chain controls. Do not use it for ordinary HTTP requests or shell scripts that do not install software.

## Workflow Contract

Take control when invoked. Inspect the actual repository and callable tools,
classify its trust and mutation boundaries, recommend one architecture, preview
exact changes, apply deterministic machinery, then prove installation,
rollback, restoration, and release identity.

Move through:

1. **Classify** — identify whether the work is an audit, repair, scaffold,
   migration, release, or live installation and establish the user's desired
   proof.
2. **Inspect** — read the bootstrap, engine, uninstall path, release workflow,
   payload inventory, state markers, tests, and authoritative references.
3. **Threat-model** — resolve origins, redirects, artifact identity,
   authenticity policy, privilege, mutable targets, secrets, and rollback
   boundaries.
4. **Preview** — state exact files, commands, mutations, backups, irreversible
   actions, rollback, and verification before applying.
5. **Apply** — put repeated and fragile work in scripts, manifests, validators,
   and transaction machinery; preserve project-specific semantics.
6. **Verify** — distinguish syntax, command success, persisted state, runtime
   behavior, rollback, restoration, reproducibility, and user-visible success.
7. **Recover or complete** — reverse partial changes on failure, or report a
   receipt with evidence and remaining trust assumptions.

Infer reversible, local, unprivileged defaults. Ask only when the target,
project semantics, trust policy, live-mutation scope, or irreversible release
action materially changes the result. Ask one question per decision and never
more than three. Recommend one path; mention alternatives only when their trust,
risk, or delivery outcome is materially different.

For longer work, surface the active phase at the beginning, on strategy change,
and when user action is required. Never publish a release, enable repository
settings, execute an unreviewed remote installer, or mutate a live installation
without authorization at that boundary.

Read `references/skill-ux-contract.md` when deciding assumptions, mutation
classes, recovery, proof, or completion.

## Start With the Trust Statement

State plainly that `curl URL | bash` authenticates only the HTTPS endpoint at
the moment of execution. A checksum downloaded from the same mutable endpoint
detects corruption but does not create an independent root of trust. Offer a
review-first command and a version-pinned command before the shortest pipe.

Classify the project against `references/threat-model.md`. Identify the
bootstrap host, release host, redirect targets, artifact identity, verification
policy, privileges, mutable destinations, secrets, and rollback boundary.

## Use the Two-Stage Architecture

Keep the public bootstrap small and stable. It may only:

1. parse a small fixed option set without `eval`;
2. create a private temporary directory and register cleanup traps;
3. download versioned assets into files with HTTPS-only redirects, timeouts,
   bounded retries, and HTTP failures enabled;
4. verify the exact expected artifact name and SHA-256 digest;
5. verify build provenance or a detached signature when policy requires it;
6. validate archive paths before extraction; and
7. execute the verified transaction engine while forwarding arguments exactly.

Put platform detection, dependency checks, planning, prompts, staging, commit,
rollback, and postcondition checks in the transaction engine inside the
verified artifact. Never stream the large mutable implementation directly into
a privileged shell.

Read `references/installer-architecture.md` before implementing the engine.

## Make Mutation Transactional

Follow this order:

1. **Preflight** all tools, platform constraints, versions, permissions, disk
   space, conflicts, and noninteractive requirements without mutation.
2. **Plan** exact downloads, targets, backups, commands, and restart/session
   consequences. Make `--dry-run` print this plan.
3. **Stage** complete files beside each final target and validate identities,
   modes, and content.
4. **Commit** with same-filesystem renames. Move each prior target to a unique
   rollback sibling before moving the staged target into place.
5. **Verify** observable postconditions, not just exit codes.
6. **Finalize** durable backups and the install manifest only after every
   target verifies.
7. **Rollback** committed targets in reverse order on error or interruption.

Mark owned state. Refuse to remove or rewrite an unmarked destination unless
the installer first archives it and records the mapping. Make reruns converge
to the requested state; do not accumulate duplicate PATH lines, services,
hooks, groups, or config blocks.

## Keep Privilege Narrow

Run the installer as the user. When system mutation is unavoidable, explain it
and elevate the smallest direct command, such as `pkexec apt-get install ...`
or `sudo install ...`. Never pipe into `sudo bash`, request a password on stdin,
use `sudo -S`, or open a general-purpose root shell. Re-verify the result
without privilege.

## Design the UX as an API

Support `--help`, `--version`, `--dry-run`, an explicit noninteractive mode,
version pinning, and machine-readable diagnostics when useful. Read prompts
from `/dev/tty`, never from the script stream. Detect piped stdin. Use stable
phase labels, actionable errors, a concise success receipt, and one exact
`Next:` instruction. Do not print secrets or entire environments.

Name Piper, the pipewright, only when a mascot suits the project; personality
must never obscure errors or verification status.

## Test Failure, Not Only Success

Use `scripts/scaffold-installer.sh` to create a starter and
`scripts/audit-installer.sh` to inspect a repository. Read
`references/testing-and-release.md` before shipping.

At minimum test syntax, ShellCheck, local install, true piped execution, option
forwarding, HTTP failure, truncated downloads, checksum mismatch, provenance
policy, malicious archive names, unsupported platforms, missing dependencies,
idempotent reruns, unmanaged collisions, spaces in paths, signals at each
commit point, injected mid-transaction failure, reverse rollback, uninstall,
restore, dry-run non-mutation, noninteractive behavior, and offline failure.

## Release With Verifiable Identity

Build a deterministic versioned archive from a clean revision. Generate a
SHA-256 manifest, hosted-build provenance, and an SBOM when dependencies make
it useful. Give CI least privilege, pin actions to full reviewed commit SHAs,
use ephemeral hosted runners, create the release as a draft, attach the complete
asset set, and then publish. Enable immutable releases before the first
production release. Document `gh attestation verify` and make strict
verification opt-in or mandatory according to the threat model.

## Package Installer Knowledge as a Skill

Keep this workflow in a concise `SKILL.md`; move threat models, architecture,
tests, and sources to one-level-deep references. Bundle deterministic scaffold
and audit scripts. Put OpenAI UI metadata in `agents/openai.yaml` and compose
other runtime-native frontmatter without duplicating the instruction body.

## Completion Gate

- Short pipe, review-first, and version-pinned paths are documented.
- The bootstrap is small, unprivileged, and downloads to files.
- Artifact identity, checksum, and optional provenance are verified before use.
- Preflight and dry-run make no durable changes.
- Commit is atomic per target and rollback spans the full transaction.
- Reruns, uninstall, and restore are proven by tests.
- CI actions are SHA-pinned with explicit permissions and timeouts.
- The release is complete, immutable, and independently verifiable.
- README rendering, social preview, default branch, assets, and live commands
  were checked before claiming success.
- Final response states exact changes, verification evidence, rollback or
  recovery, remaining trust assumptions, and one meaningful next action.
