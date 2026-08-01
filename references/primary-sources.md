# Primary sources

Research checked 2026-08-01.

- [curl command-line manual](https://curl.se/docs/manpage.html) — HTTP failure,
  redirects, protocol restrictions, TLS minimums, timeouts, retries, output,
  and retry caveats.
- [curl option introduction versions](https://curl.se/docs/optionswhen.html) —
  compatibility dates for `--proto`, `--retry-all-errors`,
  `--fail-with-body`, and `--remove-on-error`.
- [GNU Bash Reference Manual](https://www.gnu.org/software/bash/manual/bash.html)
  — pipelines, `pipefail`, `errexit`, traps, quoting, arrays, and execution
  environments.
- [GitHub: immutable releases](https://docs.github.com/en/code-security/concepts/supply-chain-security/immutable-releases)
  — locked tags/assets and automatic release attestations.
- [GitHub: preventing release changes](https://docs.github.com/en/code-security/how-tos/secure-your-supply-chain/establish-provenance-and-integrity/prevent-release-changes)
  — enabling release immutability.
- [GitHub: artifact attestations](https://docs.github.com/en/actions/concepts/security/artifact-attestations)
  — Sigstore-backed provenance, transparency, limits, and verification.
- [GitHub: using artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)
  — generating attestations and `gh attestation verify`.
- [GitHub: secure Actions use](https://docs.github.com/en/code-security/tutorials/secure-your-organization/protect-against-threats)
  — full-SHA action pinning and explicit permissions.
- [SLSA v1.2 specification](https://slsa.dev/spec/v1.2/) and
  [artifact verification](https://slsa.dev/spec/v1.2/verifying-artifacts) —
  provenance levels, expectations, and verification.
- [Reproducible Builds: archives](https://reproducible-builds.org/docs/archives/)
  and [SOURCE_DATE_EPOCH](https://reproducible-builds.org/docs/source-date-epoch/)
  — deterministic archive metadata and timestamps.

Prefer these sources over blog posts. Re-check versions and GitHub action SHAs
when releasing because current defaults change.
