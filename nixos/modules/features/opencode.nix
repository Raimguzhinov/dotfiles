{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.opencode = pkgs.opencode;
    };

  flake.homeModules.opencode =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      inherit (lib)
        mkForce
        mkOption
        types
        ;

      cfg = config.programs.opencode;

      opencodeConfigDir = "${config.xdg.configHome}/opencode";
      toolkitRepoUrl = "https://git.protei.ru/qa-stuff/llm-toolkit.git";

      opencodeSettings = {
        provider = {
          protei = {
            npm = "@ai-sdk/openai-compatible";
            name = "Protei";
            options = {
              baseURL = "${config.sops.placeholder."work_ai/litellm_url"}/api";
              apiKey = config.sops.placeholder."work_ai/litellm_api_key";
            };
            models = {
              "Qwen/Qwen3.5-122B-A10B-FP8" = {
                name = "Qwen3.5-122b";
              };
              "ПротеЯ-2.1" = {
                name = "Protei2";
              };
            };
          };
        };

        model = "protei/Qwen/Qwen3.5-122B-A10B-FP8";
        small_model = "protei/Qwen/Qwen3.5-122B-A10B-FP8";
        enabled_providers = [
          "protei"
          "opencode"
          "anthropic"
          "openai"
          "deepseek"
        ];

        mcp = {
          youtrack = {
            type = "remote";
            url = config.sops.placeholder."work_ai/mcp_sse_url";
            enabled = true;
            headers = {
              youtrack_token = config.sops.placeholder."youtrack/token";
            };
          };
        };

        permission = {
          read = {
            "~/.config/opencode/*" = "allow";
          };
          external_directory = {
            "~/.config/opencode/*" = "allow";
          };
        };
      };

      opencodeConfigJson = builtins.toJSON (
        {
          "$schema" = "https://opencode.ai/config.json";
        }
        // opencodeSettings
      );
    in
    {
      # Home Manager module (pinned in this flake) already provides
      # `programs.opencode.agents`, but does not provide `programs.opencode.skills`.
      options.programs.opencode.skills = mkOption {
        type = types.attrsOf (types.either types.lines types.path);
        default = { };
        description = ''
          Custom skills for opencode.

          The attribute name becomes the skill directory name, and the value is either:
          - Inline content as a string
          - A path to a file containing the skill content

          Each skill is written to {file}`$XDG_CONFIG_HOME/opencode/skills/<name>/SKILL.md`.
        '';
      };

      config = {
        programs.opencode = {
          enable = true;
          package = pkgs.opencode;
          enableMcpIntegration = true;
          settings = opencodeSettings;

          # Personal inline examples (live in Nix, not in ~/Work)
          agents."nix-code-reviewer" = lib.mkDefault ''
            # Nix Code Reviewer

            Reviews Nix code quickly.

            - Point out obvious mistakes
            - Suggest simpler patterns
            - Prefer small, surgical changes
          '';

          skills."nix-trivia" = lib.mkDefault ''
            # Nix Trivia

            A tiny example skill.

            When invoked, explain one Nix concept in one paragraph.
          '';

          # How to override inline:
          # - `agents.<name>` becomes `~/.config/opencode/agent/<name>.md`
          # - `skills.<name>` becomes `~/.config/opencode/skills/<name>/SKILL.md`
        };

        sops.templates."opencode-config.json" = {
          content = opencodeConfigJson;
          mode = "0400";
        };

        home.activation.ensureOpencodeToolkit = config.lib.dag.entryBefore [ "writeBoundary" ] ''
          opencode_cfg_dir="${opencodeConfigDir}"
          git_bin="${pkgs.git}/bin/git"

          mkdir -p "$opencode_cfg_dir"

          if [[ ! -d "$opencode_cfg_dir/.git" ]]; then
            echo "opencode: bootstrapping llm-toolkit in $opencode_cfg_dir" >&2

            if [[ -z "$(ls -A "$opencode_cfg_dir" 2>/dev/null)" ]]; then
              GIT_TERMINAL_PROMPT=0 "$git_bin" clone "${toolkitRepoUrl}" "$opencode_cfg_dir" || true
            else
              GIT_TERMINAL_PROMPT=0 "$git_bin" -C "$opencode_cfg_dir" init || true
              if ! "$git_bin" -C "$opencode_cfg_dir" remote get-url origin >/dev/null 2>&1; then
                "$git_bin" -C "$opencode_cfg_dir" remote add origin "${toolkitRepoUrl}" || true
              fi
              GIT_TERMINAL_PROMPT=0 "$git_bin" -C "$opencode_cfg_dir" fetch origin --depth=1 || true
              "$git_bin" -C "$opencode_cfg_dir" checkout -B llm-toolkit FETCH_HEAD || true
            fi
          fi

          ensure_alias() {
            local preferred="$1"
            local compat="$2"

            if [[ -d "$opencode_cfg_dir/$preferred" && ! -e "$opencode_cfg_dir/$compat" ]]; then
              ln -s "$preferred" "$opencode_cfg_dir/$compat"
              return
            fi

            if [[ -d "$opencode_cfg_dir/$compat" && ! -e "$opencode_cfg_dir/$preferred" ]]; then
              ln -s "$compat" "$opencode_cfg_dir/$preferred"
              return
            fi

            if [[ ! -e "$opencode_cfg_dir/$preferred" && ! -e "$opencode_cfg_dir/$compat" ]]; then
              mkdir -p "$opencode_cfg_dir/$preferred"
              ln -s "$preferred" "$opencode_cfg_dir/$compat"
              return
            fi
          }

          ensure_alias agents agent
          ensure_alias skills skill
          ensure_alias commands command
        '';

        xdg.configFile = {
          "opencode/config.json".source = mkForce (
            config.lib.file.mkOutOfStoreSymlink config.sops.templates."opencode-config.json".path
          );
        }
        // (lib.mapAttrs' (
          name: content:
          lib.nameValuePair "opencode/skills/${name}/SKILL.md" (
            if lib.isPath content then { source = content; } else { text = content; }
          )
        ) (cfg.skills or { }));
      };
    };
}
