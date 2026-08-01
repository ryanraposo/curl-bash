# Testing and release

## Contents

- Test matrix
- Fault injection
- CI hardening
- Reproducible artifacts
- Release sequence
- Consumer verification

## Test matrix

Run `bash -n`, ShellCheck, and the skill validator. Exercise supported Bash and
platform versions in containers or hosted runners when behavior differs.

The integration suite must use isolated `HOME`-equivalent roots and mocked
network, privilege, service, and package commands. Cover local and actual
`bash -s --` piped execution. Assert exact file modes, markers, manifests,
runtime payloads, output phases, and postconditions.

Include malformed options, missing values, HTTP 404/500, redirect downgrade,
timeout, partial file, wrong digest, duplicate manifest entry, missing or wrong
attestation, malicious archive names, unsupported OS/architecture, missing
tools, unwritable target, disk exhaustion where practical, spaces/newlines in
paths, hostile environment values, and no TTY.

## Fault injection

Add a test-only fault hook that is unavailable or inert in production unless a
specific test environment variable is set. Inject failure after each target
swap and verification point. Send `INT` and `TERM` during stage and commit.
Prove the old state is restored byte-for-byte and no temporary sibling is left.

Run the installer twice and compare state. Run uninstall twice. Install over an
unmanaged collision, uninstall with restore, and compare the restored tree.
Assert `--dry-run` leaves no durable state.

## CI hardening

Set top-level `permissions: contents: read`; grant write permissions only to the
release job. Pin every action to a full commit SHA with a version comment. Add
timeouts and concurrency cancellation. Avoid `pull_request_target` for running
untrusted code. Do not interpolate PR titles, branch names, or issue text into
shell. Prefer GitHub-owned actions and direct shell steps.

## Reproducible artifacts

Build from a clean tagged revision. Sort file lists, normalize owner/group,
timestamps (`SOURCE_DATE_EPOCH`), locale, permissions, and gzip headers. Build
twice and compare digests when practical. Include the installer engine,
payload, license, version, and machine-readable manifest—nothing from `.git`,
developer state, or previous `dist/`.

## Release sequence

1. Validate that tag `vX.Y.Z` matches `VERSION` and the changelog/release notes.
2. Run the complete test and audit suite.
3. Build the deterministic archive and `SHA256SUMS`.
4. Generate hosted build provenance for the archive; generate an SBOM when it
   adds meaningful dependency visibility.
5. Create a draft release and upload the complete asset set.
6. Verify assets from a clean consumer environment.
7. Publish the draft. With immutable releases enabled, tag and assets lock and
   GitHub creates release attestation.
8. Deploy the stable bootstrap only after the immutable release exists.
9. Exercise the live review-first, pinned, and piped commands.

Do not overwrite a released asset or move its version tag. Publish a new patch
release.

## Consumer verification

Document:

```bash
gh attestation verify PROJECT-X.Y.Z.tar.gz -R OWNER/PROJECT
sha256sum -c SHA256SUMS
```

Explain expected repository, workflow, tag, and digest. Verification output is
evidence of provenance and integrity, not a vulnerability scan.
