# __PROJECT__ installer

Review first:

```bash
curl -fsSLo install.sh --proto '=https' --tlsv1.2 https://__OWNER__.github.io/__PROJECT__/install.sh
less install.sh
bash install.sh
```

The bootstrap downloads the immutable `v__VERSION__` release archive, verifies
`SHA256SUMS`, optionally verifies GitHub provenance with
`--require-attestation`, validates the archive, then runs a transaction engine.
Adapt `payload/`, target selection, preflight, and postcondition checks before
publishing.
