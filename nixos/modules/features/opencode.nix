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

      agentsDir = "${config.home.homeDirectory}/Work/llm-toolkit/agents";
      skillsDir = "${config.home.homeDirectory}/Work/llm-toolkit/skills";

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

          Each skill is written to {file}`$XDG_CONFIG_HOME/opencode/skill/<name>/SKILL.md`.
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
        };

        sops.templates."opencode-config.json" = {
          content = opencodeConfigJson;
          mode = "0400";
        };

        home.activation.linkLlmToolkitToOpencode = config.lib.dag.entryAfter [ "writeBoundary" ] ''
          opencode_cfg_dir="${config.xdg.configHome}/opencode"
          mkdir -p "$opencode_cfg_dir/agent" "$opencode_cfg_dir/skill"

          if [[ -d "${agentsDir}" ]]; then
            for f in "${agentsDir}"/*.md; do
              [[ -e "$f" ]] || continue
              base="$(basename "$f")"
              target="$opencode_cfg_dir/agent/$base"
              if [[ ! -e "$target" ]]; then
                ln -s "$f" "$target"
              fi
            done
          else
            echo "llm-toolkit agents dir missing: ${agentsDir}" >&2
          fi

          if [[ -d "${skillsDir}" ]]; then
            for f in "${skillsDir}"/*; do
              [[ -e "$f" ]] || continue
              base="$(basename "$f")"
              target="$opencode_cfg_dir/skill/$base"
              if [[ ! -e "$target" ]]; then
                ln -s "$f" "$target"
              fi
            done
          else
            echo "llm-toolkit skills dir missing: ${skillsDir}" >&2
          fi
        '';

        xdg.configFile = {
          "opencode/config.json".source = mkForce (
            config.lib.file.mkOutOfStoreSymlink config.sops.templates."opencode-config.json".path
          );
        }
        // (lib.mapAttrs' (
          name: content:
          lib.nameValuePair "opencode/skill/${name}/SKILL.md" (
            if lib.isPath content then { source = content; } else { text = content; }
          )
        ) (cfg.skills or { }));
      };
    };
}
