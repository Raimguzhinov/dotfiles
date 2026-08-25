{ ... }:
{
  flake.homeModules.claude =
    {
      config,
      pkgs,
      ...
    }:
    {
      programs.claude-code = {
        enable = true;
        package = pkgs.claude-code;

        mcpServers = {
          context7 = {
            type = "http";
            url = "https://mcp.context7.com/mcp";
          };
          gh_grep = {
            type = "http";
            url = "https://mcp.grep.app";
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
        };
      };
    };
}
