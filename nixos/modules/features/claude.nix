{ ... }:
{
  flake.homeModules.claude =
    {
      config,
      lib,
      pkgs,
      pkgs-unstable,
      ...
    }:
    let
      claudeAgentDir = "${config.home.homeDirectory}/.claude";
    in
    {
      programs.claude-code = {
        enable = true;
        package = pkgs-unstable.claude-code;

        mcpServers = {
          context7 = {
            type = "http";
            url = "https://mcp.context7.com/mcp";
          };
          gh_grep = {
            type = "http";
            url = "https://mcp.grep.app";
          };
          codebase_memory = {
            type = "stdio";
            command = "npx";
            args = [
              "-y"
              "codebase-memory-mcp"
            ];
            env.CBM_ALLOWED_ROOT = config.home.homeDirectory;
          };
          searxng = {
            type = "stdio";
            command = "npx";
            args = [
              "-y"
              "mcp-searxng"
            ];
            env.SEARXNG_URL = "http://127.0.0.1:8899";
          };
          typst = {
            type = "stdio";
            command = "docker";
            args = [
              "run"
              "--rm"
              "-i"
              "ghcr.io/johannesbrandenburger/typst-mcp:latest"
            ];
          };
        };
      };

      home.activation.setupClaudeBmad = lib.mkAfter /* bash */ ''
        set -euo pipefail

        agent_dir="${claudeAgentDir}"
        log() { printf '[claude] %s\n' "$*" >&2; }

        if [[ ! -f "$agent_dir/skills/bmad/SKILL.md" ]]; then
          log "Installing BMad Method skills for Claude Code (global)"
          export PATH="${
            lib.makeBinPath [
              pkgs.nodejs
              pkgs.git
              pkgs.coreutils
            ]
          }:$PATH"
          if ! "${pkgs.coreutils}/bin/timeout" 240s npx --yes skills add bmad-code-org/BMAD-METHOD \
            --skill bmad --skill bmod-core-tools --skill bmod-method --skill bmad-build \
            --agent claude-code --global --yes >/dev/null 2>&1; then
            log "WARNING: BMad skills install failed (no network?)"
          fi
        fi
      '';
    };
}
