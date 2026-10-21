# Upstream patches at build time, inline in Nix

A `sed` patch applied to an already-installed npm package fails **silently** when an upstream update drifts the patched strings, and the agent then runs unpatched without anyone noticing.

We decided that packages which need a source patch are built at **build time** instead: the package is fetched as a pinned npm tarball, the substitutions are applied inline in Nix with `substituteInPlace --replace-fail`, and the agent config references the patched package as a store path. `piPlan` is built this way, and all four live patches (the `pi-fff` find-path fix, the `pi-lsp-extension` nix language + project-marker auto-start, the `pi-herdr-subagents` widget key) sit in `mkPiExtensions` postConfigure as one `pi-extensions` npm bundle.

No `.patch` files: the repo keeps its "no standalone code files" rule. The inline-in-Nix vendored build is already used by `pi-acp` (a plain build from source, no patch).

**Legacy exception, resolved.** `pi-fff`, `pi-lsp-extension`, and `pi-herdr-subagents` were originally patched with `sed` at activation time (a `grep` pre-check plus a `WARNING` log when a substitution did not apply). They migrated to the build-time pattern in 3ca31e8, and the fourth historical patch (`pi-permission-system`) was removed together with the package swap in ADR-0006. No activation-time `sed` patch remains in the repo.

Considered options:

- **Keep sed at activation** — the status quo for the four legacy packages; a failed patch is only a log line, not a build failure.
- **`.patch` files + `patch`** — requires a new file type in the repo and a second mechanism to keep in sync.
- **PR the patches upstream** — separate projects, none likely to accept; blocks us on other people's queues.

Consequences:

- Drift (tarball hash or a replacement string not found) fails the **build loudly**: a `--replace-fail` substitution that finds no target aborts the derivation, so the next `nixos-rebuild` fails immediately.
- Upgrading a patched package means updating a pinned tarball hash, then re-applying the substitutions — visible and atomic.
- The flake check `checks.pi-extensions` builds the same derivation, so a patch that no longer applies fails `nix flake check` before it can reach a `nixos-rebuild`.
