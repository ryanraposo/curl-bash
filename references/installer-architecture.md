# Installer architecture

## Contents

- Bootstrap contract
- Download policy
- Artifact verification
- Archive handling
- Transaction engine
- Idempotency and ownership
- Privilege and prompts
- Concurrency and recovery

## Bootstrap contract

Keep the bootstrap reviewable. Use Bash explicitly when Bash features are
required. Enable `set -eEuo pipefail`, but remember `errexit` has conditional,
pipeline, command-substitution, and function contexts where it does not behave
like an exception system. Handle expected failures explicitly.

Use a private directory from `mktemp -d`, `umask 077`, and traps for `EXIT`,
`HUP`, `INT`, and `TERM`. Do not reuse predictable paths. Keep cleanup targets
resolved and validated. Never clean a home, root, empty, or wildcard path.

When stdin is the script stream, prompts must read `/dev/tty`. Forward options
as an array: `bash engine -- "$@"`. Never rebuild arguments into a string.

## Download policy

Download into a named file, not a pipeline. Use:

```bash
curl --fail --silent --show-error --location \
  --proto '=https' --proto-redir '=https' --tlsv1.2 \
  --connect-timeout 10 --max-time 120 \
  --retry 3 --retry-max-time 60 \
  --output "$destination" "$url"
```

Use `--fail-with-body` only when the minimum curl version supports it and the
error body is handled without leaking secrets. Avoid default
`--retry-all-errors`; curl warns that redirected or piped output can duplicate
data. Never use `--insecure`. Treat proxy variables and `.curlrc` as part of the
local trust boundary; add `--disable` when deterministic curl configuration is
required.

## Artifact verification

Parse a manifest as data. Require one exact basename and one valid lowercase or
uppercase 64-hex SHA-256 digest. Reject duplicates, path separators, extra
fields, and missing entries. Compare using `sha256sum`, `shasum -a 256`, or a
documented platform fallback.

When provenance is required, verify the downloaded archive against the exact
repository and expected workflow/issuer policy. Verification must happen before
extraction or execution. If signatures are used, embed or distribute the public
key through a genuinely separate trust path.

## Archive handling

List before extraction. Reject absolute member names, `..` path components,
control characters, unexpected top-level directories, special devices, and
links that escape the extraction root. Extract with ownership and permission
preservation disabled. Validate the expected engine path and identity after
extraction.

Prefer archives produced by the project rather than GitHub-generated source
archives because the project controls layout, reproducibility, and provenance.

## Transaction engine

Separate preflight, plan, stage, commit, verify, and finalize functions. The
first three must be non-mutating outside the private stage and state lock.

For each destination:

1. build a complete staged sibling;
2. validate identity and modes;
3. move the old target to a unique rollback sibling;
4. rename the new sibling into place;
5. record the committed target;
6. verify its postcondition.

On any failure, iterate committed targets in reverse: move the failed/new target
aside, restore the rollback sibling, then archive or delete only the known
managed failed copy. Keep traps active until all targets verify. Move unmanaged
rollback siblings to durable state backups only after the whole commit
succeeds.

## Idempotency and ownership

Write a marker with project identity, version, source repository, and install
time. For individual files, keep an installed manifest of paths and hashes.
For config, use uniquely named begin/end blocks and replace the complete block;
never append blindly. Detect semantic current state before restarting services
or rewriting files.

An uninstaller must require the marker, archive managed state rather than
irreversibly delete it, remove only manifest-owned files/blocks, and optionally
restore the exact backup mapping. Package/group removal is usually a separate
explicit choice because other software may depend on it.

## Privilege and prompts

Preflight privilege need before mutation. Explain each elevated action. Invoke
the exact tool directly with `pkexec` or `sudo`; never elevate the dispatcher.
Do not accept passwords through stdin or environment variables.

Interactive prompts read from `/dev/tty`, show the default, accept a complete
word, and fail with an actionable message when no TTY exists. Noninteractive
mode must define every policy choice; it must not silently answer dangerous
prompts.

## Concurrency and recovery

Acquire an atomic per-project lock directory and record the owner PID/time.
Refuse a live concurrent transaction. Explain stale-lock recovery. Persist a
transaction journal before commit so an interrupted next run can offer or
perform deterministic recovery. Keep backups versioned and apply an explicit
retention policy only after a successful install.
