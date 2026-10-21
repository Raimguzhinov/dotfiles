# Coding-agent harness

Modules: `harness.nix`, `pi.nix`, `opencode.nix`, `claude.nix`, `herdr.nix`,
`llama-cpp.nix`. Terms in `GLOSSARY.md`, decisions in `docs/adr/`.

- Shared settings live in `programs.harness.*` (`harness.nix`); each agent
  module renders them into its own schema.
- MCP servers: package and args in `programs.harness.*`, one entry per client.
  pi and claude take `command` + `args`, opencode takes a `command` list.
- Permission rules: `programs.harness.permissions`, model in ADR-0006, meta-files
  ask and `.env.example` in ADR-0008. pi and
  opencode render them; claude does not use them.
- pi extensions: `piExtensionDeps` and `piExtensionsLock` in `pi.nix`, built
  into the store by `mkPiExtensions` (upstream patches in `postConfigure`).
  To add, remove or bump one: edit `piExtensionDeps`, regenerate the lock with
  `npm install --package-lock-only --legacy-peer-deps` in a scratch dir, port
  the entries into `piExtensionsLock` (linux-x64 optional binaries only, no
  `resolved`), then update `npmDepsHash`.
- aft: version pin `programs.harness.aftVersion`. The binary comes from npm,
  not Nix (cache `~/.cache/aft/bin/`). The "update" at startup is an index
  rebuild, not a software upgrade.
- pi internals: source at the store path from `readlink -f $(which pi)`, in
  `lib/node_modules/pi-monorepo` (`dist/`, `docs/`, `examples/`); upstream
  github.com/earendil-works/pi. A `tool_call` block (docs/extensions.md) never
  runs the tool and its `reason` reaches the model as the error tool result
  (`packages/agent/src/agent-loop.ts`); the first blocking handler wins.
- Flake checks (perSystem, exposed as `<system>-<name>`): `pi-extensions`
  builds the patched extension bundle, `bash-guard` runs the inline block/pass
  suite, `harness-configs` parses the rendered config files with jq,
  `herdr-config` validates the rendered herdr config,
  `pi-permission-schema` validates the rendered permission config against the
  schema. Run with `nix flake check`.
