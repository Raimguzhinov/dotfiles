{ ... }:
{
  flake.homeModules.claude =
    { config, pkgs-unstable, ... }:
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
    };
}
