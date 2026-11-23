# Agent binaries come from llm-agents.nix

Agent binaries came from five places: `pkgs-unstable` (claude-code, pi, herdr, handy), stable nixpkgs (codex, the opencode Zed ran), the `sadjow/claude-code-nix` and `anomalyco/opencode` flake inputs, and a hand-written `buildNpmPackage` for pi-acp. The sadjow overlay never reached Dell's claude (it wrapped `pkgs-unstable`, which has no overlays), and Zed ran opencode 1.x while the CLI ran 2.x.

Decision:

- **`numtide/llm-agents.nix` is the single source for agent binaries and agent-adjacent tools**: claude-code, pi, pi-acp, opencode (`opencode2` plus an `opencode` symlink), codex, herdr, handy, skills and the claude/codex ACP adapters.
- **No `inputs.nixpkgs.follows`.** The flake is built and tested only against its own nixpkgs-unstable pin, and its binary cache hits only for that pin. Modules read `inputs.llm-agents.packages.${system}` through the `llm-agents` module argument (perSystem, NixOS and home-manager), not through the `shared-nixpkgs` overlay, which rebuilds against our nixpkgs and misses the cache.
- **`cache.numtide.com` is a substituter** in `nixConfig` and in `nix.settings` on both hosts.
- Bump with `nix flake lock --update-input llm-agents`.

Stays outside the catalog: codebase-memory-mcp (own input), thinkrail, pi extensions (ADR-0003), herdr plugins, mcp-nixos.

Considered:

- **Follow our nixos-26.05 nixpkgs**: rejected, upstream says a stable branch breaks the build eventually and every package compiles locally.
- **Keep per-tool inputs**: rejected, one input per agent multiplies nixpkgs copies in the lock and update commands.

Consequences:

- Daily upstream bumps can outpace herdr plugins built against a herdr version. On a break, report options (update, wait, drop) instead of patching.
- opencode's main program is `opencode2`; the `opencode` symlink in `opencode.nix` keeps herdr integrations, ecdy and Zed working.
