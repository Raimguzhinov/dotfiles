{
  config,
  pkgs,
  lib,
  ...
}:

let
  mcpConfig = {
    mcpServers = {
      demo_mcp = {
        type = "http";
        url = "${"$"}ANTHROPIC_BASE_URL/mcp/demo_mcp";
        headers = {
          "x-litellm-api-key" = "Bearer ${"$"}ANTHROPIC_AUTH_TOKEN";
        };
      };
      youtrack = {
        type = "sse";
        url = "${"$"}MCP_SSE_URL";
        headers = {
          youtrack_token = "${"$"}YOUTRACK_TOKEN";
        };
      };
    };
  };
  claudeWrapperMCP = pkgs.writeShellScriptBin "claude" ''
    if [[ -f ${config.sops.secrets."work_ai/mcp_sse_url".path} ]]; then
      export MCP_SSE_URL="$(cat ${config.sops.secrets."work_ai/mcp_sse_url".path})"
      export YOUTRACK_TOKEN="$(cat ${config.sops.secrets."youtrack/token".path})"

      MCP_CONFIG=$(mktemp)
      echo '${builtins.toJSON mcpConfig}' | ${pkgs.gettext}/bin/envsubst > "$MCP_CONFIG"

      trap "rm -f $MCP_CONFIG" EXIT
      exec ${pkgs.claude-code}/bin/claude --mcp-config "$MCP_CONFIG" "$@"
    else
      exec ${pkgs.claude-code}/bin/claude "$@"
    fi
  '';
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "claude-protei" ''
      export ANTHROPIC_MODEL="ПротеЯ-2-Thinking"

      if [[ -f ${config.sops.secrets."work_ai/litellm_url".path} && -f ${
        config.sops.secrets."work_ai/litellm_api_key".path
      } ]]; then
        export ANTHROPIC_BASE_URL="$(cat ${
          config.sops.secrets."work_ai/litellm_url".path
        } 2>/dev/null)/api"
        export ANTHROPIC_AUTH_TOKEN="$(cat ${
          config.sops.secrets."work_ai/litellm_api_key".path
        } 2>/dev/null)"
      fi

      exec ${lib.getExe claudeWrapperMCP} "$@"
    '')
  ];

  programs.claude-code = {
    enable = true;
    package = claudeWrapperMCP;
  };
}
