# Coding-agent harness

Modules: `harness.nix`, `pi.nix`, `opencode.nix`, `claude.nix`, `herdr.nix`,
`llama-cpp.nix`. Terms in `GLOSSARY.md`, decisions in `docs/adr/`.

- Shared settings live in `programs.harness.*` (`harness.nix`); each agent
  module renders them into its own schema.
- MCP servers: package and args in `programs.harness.*`, one entry per client.
  pi and claude take `command` + `args`, opencode takes a `command` list.
- Permission rules: `programs.harness.permissions`, model in ADR-0006. pi and
  opencode render them; claude does not use them.
- aft: version pin `programs.harness.aftVersion`. The binary comes from npm,
  not Nix (cache `~/.cache/aft/bin/`). The "update" at startup is an index
  rebuild, not a software upgrade.
