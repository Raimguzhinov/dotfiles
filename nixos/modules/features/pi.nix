{ ... }:
let
  searxPort = 8899;
in
{
  perSystem =
    { pkgs-unstable, ... }:
    {
      packages.pi = pkgs-unstable.pi-coding-agent;
    };

  flake.nixosModules.pi =
    { pkgs, ... }:

    let
      searxSecretFile = "/var/lib/searx-secret/env";
    in
    {
      config = {
        systemd.services.searx-secret = {
          requiredBy = [
            "searx-init.service"
            "searx.service"
          ];
          before = [
            "searx-init.service"
            "searx.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            StateDirectory = "searx-secret";
            StateDirectoryMode = "0700";
            UMask = "0077";
          };
          script = /* bash */ ''
            if [[ ! -s ${searxSecretFile} ]]; then
              printf 'SEARXNG_SECRET=%s\n' \
                "$(${pkgs.openssl}/bin/openssl rand -hex 32)" > ${searxSecretFile}
            fi
          '';
        };

        services.searx = {
          enable = true;
          domain = "localhost";
          environmentFile = searxSecretFile;
          settings = {
            server = {
              port = searxPort;
              bind_address = "127.0.0.1";
              secret_key = "$SEARXNG_SECRET";
            };
            search.formats = [
              "html"
              "json"
            ];
          };
        };
      };
    };

  flake.homeModules.pi =
    {
      config,
      lib,
      pkgs,
      pkgs-unstable,
      ...
    }:

    let
      inherit (lib)
        mkAfter
        ;

      piAgentDir = "${config.home.homeDirectory}/.pi/agent";

      readSecret = name: "!cat ${config.sops.secrets.${name}.path}";

      modelsConfig = {
        providers.Protei = {
          baseUrl = "https://agent.ai.protei.ru/api";
          api = "openai-completions";
          apiKey = readSecret "work_ai/litellm_api_key";
          compat.supportsDeveloperRole = false;
          models = [
            {
              id = "agent_proteya";
              name = "Protei Coding";
              reasoning = true;
              input = [
                "text"
                "image"
              ];
              contextWindow = 131072;
              maxTokens = 8192;
              samplingParams = {
                temperature = 1.0;
                top_p = 0.95;
                top_k = 20;
                min_p = 0.0;
                presence_penalty = 0.0;
                repetition_penalty = 1.0;
              };
            }
          ];
        };
      };

      mcpConfig = {
        mcpServers = {
          youtrack = {
            url = "https://youtrackmcp.ai.protei.ru/mcp";
            headers."youtrack-token" = readSecret "youtrack/token";
          };
          gitlab = {
            command = "uvx";
            args = [
              "--from"
              "git+ssh://git@git.protei.ru/qa-stuff/llm/mcp/gitlab.git"
              "gitlab-mcp-server"
            ];
            env = {
              GITLAB_URL = "https://git.protei.ru";
              GITLAB_TOKEN = readSecret "git/gitlab_mcp_token";
            };
          };
          rag = {
            command = "uvx";
            args = [
              "--from"
              "git+ssh://git@git.protei.ru/qa-stuff/llm/mcp/lightrag-mcp.git"
              "lightrag-mcp"
            ];
            env = {
              LIGHTRAG_BASE_URL = readSecret "work_ai/lightrag_url";
              LIGHTRAG_TIMEOUT = "60";
              LIGHTRAG_VERIFY_SSL = "False";
            };
          };
          searxng = {
            command = "npx";
            args = [
              "-y"
              "mcp-searxng"
            ];
            env.SEARXNG_URL = "http://127.0.0.1:${toString searxPort}";
          };
          postgres = {
            command = "npx";
            args = [
              "-y"
              "@modelcontextprotocol/server-postgres"
              "postgresql://uc:ucPassword@localhost:5432/uc?sslmode=disable&options=-csearch_path%3Dcompany_0%2Cpublic"
            ];
          };
          gh_grep = {
            url = "https://mcp.grep.app";
            auth = false;
          };
        };
      };

      settingsSeed = {
        defaultProvider = "Protei";
        defaultModel = "agent_proteya";
        theme = "dark";
        packages = [
          "npm:@upstash/context7-pi"
          "npm:pi-mcp-adapter"
          "npm:pi-plan"
          "npm:pi-permission-system"
          "npm:pi-undo-redo"
        ];
      };

      toJsonFile = (pkgs.formats.json { }).generate;

      modelsJsonFile = toJsonFile "pi-models.json" modelsConfig;
      mcpJsonFile = toJsonFile "pi-mcp.json" mcpConfig;
      settingsSeedFile = toJsonFile "pi-settings-seed.json" settingsSeed;
    in
    {
      config = {

        home.packages = [
          pkgs-unstable.pi-coding-agent
        ];

        home.activation.setupPi = mkAfter /* bash */ ''
          set -euo pipefail

          agent_dir="${piAgentDir}"

          log() { printf '[pi] %s\n' "$*" >&2; }

          mkdir -p "$agent_dir"

          cp --reflink=never "${modelsJsonFile}" "$agent_dir/models.json"
          chmod 600 "$agent_dir/models.json"

          if ! cmp -s "${mcpJsonFile}" "$agent_dir/mcp.json"; then
            cp --reflink=never "${mcpJsonFile}" "$agent_dir/mcp.json"
            chmod 600 "$agent_dir/mcp.json"
            rm -f "$agent_dir/mcp-cache.json"
            log "mcp.json changed, dropped metadata cache to re-probe servers"
          fi

          if [[ -f "$agent_dir/settings.json" ]]; then
            "${pkgs.jq}/bin/jq" --slurpfile seed "${settingsSeedFile}" \
              '(.packages // []) as $old | (. * $seed[0]) | .packages = (($old + $seed[0].packages) | unique)' \
              "$agent_dir/settings.json" > "$agent_dir/settings.json.tmp" \
              && mv "$agent_dir/settings.json.tmp" "$agent_dir/settings.json"
          else
            cp --reflink=never "${settingsSeedFile}" "$agent_dir/settings.json"
            chmod 644 "$agent_dir/settings.json"
          fi

          if [[ ! -d "$agent_dir/npm/node_modules/pi-mcp-adapter" ]]; then
            log "Installing pi-mcp-adapter"
            export PATH="${
              lib.makeBinPath [
                pkgs-unstable.pi-coding-agent
                pkgs.nodejs
                pkgs.git
                pkgs.coreutils
              ]
            }:$PATH"
            if ! "${pkgs.coreutils}/bin/timeout" 180s pi install npm:pi-mcp-adapter >/dev/null 2>&1; then
              log "WARNING: pi install npm:pi-mcp-adapter failed (no network?)"
            fi
          fi

          log "pi setup complete"
        '';
      };
    };
}
