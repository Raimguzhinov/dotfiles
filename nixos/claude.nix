{ config, pkgs, ... }:

let
  mcpConfig = {
    mcpServers = {
      demo_mcp = {
        type = "http";
        url = "${"$"}ANTHROPIC_BASE_URL/litellm/mcp/demo_mcp";
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
in
{
  home.packages = [
    (pkgs.writeShellScriptBin "claude-protei" ''
      export ANTHROPIC_MODEL="Qwen/Qwen3.5-122B-A10B-FP8"

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

      if [[ -f ${config.sops.secrets."work_ai/mcp_sse_url".path} ]]; then
        MCP_SSE_URL="$(cat ${config.sops.secrets."work_ai/mcp_sse_url".path})"
        YOUTRACK_TOKEN="$(cat ${config.sops.secrets."youtrack/token".path})"

        MCP_CONFIG=$(mktemp)
        echo '${builtins.toJSON mcpConfig}' > "$MCP_CONFIG"

        trap "rm -f $MCP_CONFIG" EXIT
        exec ${pkgs.claude-code}/bin/claude --mcp-config "$MCP_CONFIG" "$@"
      else
        exec ${pkgs.claude-code}/bin/claude "$@"
      fi
    '')
  ];

  programs.claude-code = {
    enable = true;
    package = pkgs.claude-code;
  };
}
