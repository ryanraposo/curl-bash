<div align="center">
<pre>
&lt; ▄▄ | ▄▄ &gt;   ║
   ▄▀ 0x0 ▀▄   ║
    █  ───  █══╝
    █ VERIFY█
     ▀▀   ▀▀
</pre>

# curl-bash

Fetch. Verify. Transact. Recover.

[Install](#install-the-skill) · [Architecture](#the-two-stage-rule) ·
[Scaffold](#scaffold-an-installer) · [Trust model](#trust-model)
</div>

**Piper, the pipewright** helps agents build curl-pipe-bash installers that are
pleasant to use and difficult to break. This is a general-purpose Agent Skill,
not an installer for one specific application.

It combines a compact skill definition with a reusable starter, transaction
engine patterns, an auditor, adversarial tests, CI, Pages delivery, and an
immutable-release-ready flow.

## Install the skill

Review first (recommended):

```bash
curl -fsSLo install.sh --proto '=https' --tlsv1.2 \
  https://ryanraposo.github.io/curl-bash/install.sh
less install.sh
bash install.sh --require-attestation
```

Short form:

```bash
curl -fsSL --proto '=https' --tlsv1.2 \
  https://ryanraposo.github.io/curl-bash/install.sh | bash
```

Pin a release:

```bash
curl -fsSL --proto '=https' --tlsv1.2 \
  https://ryanraposo.github.io/curl-bash/install.sh |
  CURL_BASH_VERSION=1.0.0 bash
```

The installer downloads a versioned release archive to a private temporary
directory, verifies its SHA-256 digest, optionally verifies GitHub build
provenance, validates archive paths, and only then runs the transaction engine.
It installs portable skill copies under `~/.agents/skills/` and
`~/.hermes/skills/`. Use `--agents-only`, `--hermes-only`, `--dry-run`, or
`--verify-only` as needed. For piped options, use `bash -s -- OPTION...`.

## The two-stage rule

```text
small stable bootstrap
  -> versioned archive downloaded to a file
  -> exact artifact + SHA-256 verification
  -> optional provenance/signature policy
  -> archive path validation
  -> verified transaction engine
  -> preflight -> plan -> stage -> commit -> verify -> finalize
                              \-> reverse rollback on any failure
```

The bootstrap never performs project installation itself. The verified engine
never downloads executable code while committing state. This makes both pieces
small enough to reason about and test.

## Scaffold an installer

```bash
./scripts/scaffold-installer.sh \
  --project acme \
  --repository OWNER/acme \
  --version 1.0.0 \
  ./work/acme-installer
```

Then adapt the starter's `payload/`, target plan, platform policy, and
postcondition checks. Audit any repository with:

```bash
./scripts/audit-installer.sh /path/to/repository
```

The audit is intentionally conservative and returns findings with severity; it
does not pretend pattern matching is a security proof.

## Trust model

The short pipe trusts DNS, PKI, the hosting account, the served bootstrap, and
the user's current network/toolchain. A digest served beside an artifact
detects transfer corruption and accidental mismatch, but a compromised origin
can replace both. GitHub artifact attestations add signed provenance tying the
archive to the repository, workflow, and commit, but provenance proves origin,
not that the source is vulnerability-free.

The review-first and pinned commands reduce ambiguity. Immutable releases stop
published tags and assets from being altered and automatically add release
attestation on GitHub. See `references/threat-model.md` for the full boundary.

## What “robust” means here

- HTTPS-only redirects, bounded retries, timeouts, private temporary files;
- no `eval`, no password-on-stdin, no whole-installer root shell;
- exact asset identity, SHA-256, optional `gh attestation verify`;
- traversal-resistant extraction and validation before execution;
- mutation-free preflight and dry-run;
- same-filesystem atomic swaps and transaction-wide reverse rollback;
- marker-gated uninstall, durable backups, and restoration;
- idempotent managed blocks and convergent reruns;
- terminal-safe prompts, noninteractive mode, stable phases, useful receipts;
- mocked network/failure/signal tests and reproducible release artifacts;
- SHA-pinned GitHub Actions, minimal permissions, attestations, and immutable
  release instructions.

## Repository map

| Path | Purpose |
|---|---|
| `SKILL.md` | Agent workflow and completion gate |
| `AGENTS.md` | Repository-aware install and self-use funnel |
| `install.sh` | Small verified release bootstrap |
| `scripts/install-skill.sh` | Transactional installation engine for this skill |
| `scripts/scaffold-installer.sh` | General project installer generator |
| `scripts/audit-installer.sh` | Static architecture and safety audit |
| `assets/starter/` | Copyable generic installer project |
| `references/` | Threat model, architecture, tests, releases, sources |
| `tests/run.sh` | Adversarial regression suite |

MIT © Ryan Raposo
