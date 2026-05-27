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
        };
      };
    };
}
