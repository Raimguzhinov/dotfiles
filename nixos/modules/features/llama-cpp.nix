{ ... }:
let
  mkLlamaCppOptimized =
    pkgs:
    (pkgs.llama-cpp.override {
      blasSupport = true;
      vulkanSupport = true;
      cudaSupport = false;
      rocmSupport = false;
      metalSupport = false;
      openclSupport = false;
    }).overrideAttrs
      (oldAttrs: {
        cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
          "-DGGML_NATIVE=ON"
        ];
        preConfigure = ''
          export NIX_ENFORCE_NO_NATIVE=0
          ${oldAttrs.preConfigure or ""}
        '';
      });

  mkThreadedWrapper =
    {
      pkgs,
      name,
      exe,
      extraArgs ? [ ],
    }:
    pkgs.writeShellScriptBin name ''
      set -eu
      threads="${"$"}{LLAMA_THREADS:-$(${pkgs.coreutils}/bin/nproc)}"
      exec ${exe} \
        --threads "$threads" \
        ${pkgs.lib.concatStringsSep " \\\n  " extraArgs} \
        "$@"
    '';

  # Indent each non-empty line by N spaces.
  indentLines =
    lib: n: s:
    let
      pad = lib.concatStringsSep "" (lib.replicate n " ");
      lines = lib.splitString "\n" (lib.removeSuffix "\n" s);
    in
    lib.concatStringsSep "\n" (map (line: if line == "" then "" else pad + line) lines);

  addContinuations =
    lib: lines:
    lib.imap0 (i: line: if i == (builtins.length lines - 1) then line else "${line} \\\n") lines;

  sanitizeRepo = lib: repo: lib.replaceStrings [ "/" " " ] [ "_" "_" ] repo;

in
{
  perSystem =
    { pkgs, ... }:
    let
      llamaCppOptimized = mkLlamaCppOptimized pkgs;
    in
    {
      packages = {
        llama-cpp = llamaCppOptimized;
        llama-swap = pkgs.llama-swap;
      };
    };

  flake.homeModules.llamaCpp =
    {
      config,
      lib,
      pkgs,
      ...
    }:

    let
      inherit (lib)
        mkDefault
        mkEnableOption
        mkIf
        mkOption
        types
        ;

      llamaCppOptimized = mkLlamaCppOptimized pkgs;

      llamaServerXps = mkThreadedWrapper {
        inherit pkgs;
        name = "llama-server-xps";
        exe = "${llamaCppOptimized}/bin/llama-server";
        extraArgs = [ "--threads-batch \"$threads\"" ];
      };

      llamaCliXps = mkThreadedWrapper {
        inherit pkgs;
        name = "llama-cli-xps";
        exe = "${llamaCppOptimized}/bin/llama-cli";
      };

      # ---- llama-swap (OpenAI API) ----

      cfg = config.programs.llamaSwap;

      enabledModels = lib.filterAttrs (_: m: m.enable) cfg.models;

      cacheBaseDir = "${config.xdg.cacheHome}/llama.cpp";

      modelPathFor =
        model:
        if model.model != null then
          model.model
        else
          "${cacheBaseDir}/${sanitizeRepo lib model.hf.repo}/${model.hf.file}";

      hfCli = pkgs.python3.withPackages (ps: [ ps.huggingface-hub ]);

      fetchModelsScript =
        let
          hfModels = lib.filterAttrs (_: m: m.hf != null) enabledModels;
          downloadSnippets = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              _name: model:
              let
                repo = model.hf.repo;
                file = model.hf.file;
                revision = model.hf.revision;
                outDir = "${cacheBaseDir}/${sanitizeRepo lib repo}";
                outFile = "${outDir}/${file}";
                revArg = lib.optionalString (revision != null) "--revision ${lib.escapeShellArg revision}";
              in
              ''
                mkdir -p ${lib.escapeShellArg outDir}
                if [[ ! -f ${lib.escapeShellArg outFile} ]]; then
                  echo "[llama-swap] downloading ${repo}/${file}"
                  ${hfCli}/bin/huggingface-cli download \
                    ${lib.escapeShellArg repo} \
                    ${lib.escapeShellArg file} \
                    ${revArg} \
                    --local-dir ${lib.escapeShellArg outDir} \
                    --local-dir-use-symlinks False
                fi
              ''
            ) hfModels
          );
        in
        pkgs.writeShellScriptBin "llama-swap-fetch-models" ''
          set -euo pipefail
          ${downloadSnippets}
        '';

      mkModelCmd =
        model:
        let
          baseLines = [
            "${llamaCppOptimized}/bin/llama-server"
            "--model ${lib.escapeShellArg (modelPathFor model)}"
            "--port \${PORT}"
            "--ctx-size ${toString model.ctxSize}"
            "--threads ${toString model.threads}"
            "--threads-batch ${toString model.threadsBatch}"
          ];
          cmdLines = addContinuations lib (baseLines ++ model.extraArgs);
        in
        lib.concatStringsSep "  " cmdLines;

      modelsYaml = lib.concatStringsSep "\n" (
        lib.mapAttrsToList (
          name: model:
          let
            cmdIndented = indentLines lib 6 (mkModelCmd model);
          in
          "  \"${name}\":\n    cmd: |\n${cmdIndented}"
        ) enabledModels
      );

      configYaml = "models:\n" + modelsYaml + "\n";

      configFile = pkgs.writeText "llama-swap-config.yaml" configYaml;

      systemctlUser = "${pkgs.systemd}/bin/systemctl --user";

      startScript = pkgs.writeShellScriptBin "llama-swap-start" ''
        exec ${systemctlUser} start llama-swap.service
      '';
      stopScript = pkgs.writeShellScriptBin "llama-swap-stop" ''
        exec ${systemctlUser} stop llama-swap.service
      '';
      statusScript = pkgs.writeShellScriptBin "llama-swap-status" ''
        exec ${systemctlUser} status llama-swap.service
      '';
      restartScript = pkgs.writeShellScriptBin "llama-swap-restart" ''
        exec ${systemctlUser} restart llama-swap.service
      '';

    in
    {
      options.programs.llamaSwap = {
        enable = mkEnableOption "llama-swap OpenAI-compatible proxy";

        listen = mkOption {
          type = types.str;
          default = "127.0.0.1:8085";
          description = "Address for llama-swap to listen on";
        };

        models = mkOption {
          type = types.attrsOf (
            types.submodule (
              { ... }:
              {
                options = {
                  enable = mkEnableOption "enable this model";

                  model = mkOption {
                    type = types.nullOr types.str;
                    default = null;
                    description = "Path to local GGUF file (outside Nix store)";
                  };

                  hf = mkOption {
                    type = types.nullOr (
                      types.submodule (
                        { ... }:
                        {
                          options = {
                            repo = mkOption {
                              type = types.str;
                              description = "HuggingFace repo id";
                            };
                            file = mkOption {
                              type = types.str;
                              description = "Filename in the repo (GGUF)";
                            };
                            revision = mkOption {
                              type = types.nullOr types.str;
                              default = null;
                              description = "Optional HF revision/tag/commit";
                            };
                          };
                        }
                      )
                    );
                    default = null;
                    description = "HuggingFace download source (stored in XDG cache)";
                  };

                  ctxSize = mkOption {
                    type = types.int;
                    default = 4096;
                    description = "Context size for llama-server";
                  };

                  threads = mkOption {
                    type = types.int;
                    default = 8;
                    description = "CPU threads for llama-server";
                  };

                  threadsBatch = mkOption {
                    type = types.int;
                    default = 8;
                    description = "Batch threads for llama-server";
                  };

                  extraArgs = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "Extra llama-server CLI args";
                  };
                };
              }
            )
          );
          default = { };
          description = "Models exposed via llama-swap";
        };
      };

      config = {
        home.packages = [
          llamaCppOptimized
          llamaServerXps
          llamaCliXps
        ]
        ++ lib.optionals cfg.enable [
          pkgs.llama-swap
          fetchModelsScript
          startScript
          stopScript
          statusScript
          restartScript
        ];

        programs.llamaSwap = {
          enable = mkDefault true;
          listen = mkDefault "127.0.0.1:8085";

          # Модели (dell-xps-13-9320, Intel Iris Xe, 32GB RAM):
          # - Чтобы модель (веса) помещалась в iGPU память (UMA), выбирай небольшие GGUF:
          #   ориентир: 1–4B, квант Q4_K_M / Q5_K_M. Текущая 1.5B Q4 (~1GB) подходит отлично.
          # - Контекст (`ctxSize`) сильно влияет на память KV-кэша: чем больше контекст,
          #   тем больше расход RAM/UMA. Для повседневного — 4096/8192.
          # - Для работы с кодом/большими репами в OpenCode имеет смысл поднять до 8192–16384,
          #   но если начнутся OOM/тормоза — откатывайся или бери меньшую модель/квант.
          # - Vulkan offload на Iris Xe может "ломать" качество при полном offload:
          #   оставляем умеренный `--n-gpu-layers` (подбирается эмпирически).
          models."qwen2.5-coder-1.5b-instruct" = {
            enable = mkDefault true;
            hf = {
              repo = mkDefault "Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF";
              file = mkDefault "qwen2.5-coder-1.5b-instruct-q4_k_m.gguf";
            };

            ctxSize = mkDefault 32768;
            threads = mkDefault 8;
            threadsBatch = mkDefault 8;
            extraArgs = mkDefault [
              "--n-gpu-layers 4"
              "--jinja" # OpenAI tool calls требуют jinja chat templates.
            ];
          };
        };

        xdg.configFile."llama-swap/config.yaml" = mkIf cfg.enable {
          source = configFile;
        };

        systemd.user.services.llama-swap = mkIf cfg.enable {
          Unit = {
            Description = "llama-swap (OpenAI-compatible, model swapper)";
            After = [ "network.target" ];
          };

          Service = {
            Type = "simple";
            ExecStartPre = "${fetchModelsScript}/bin/llama-swap-fetch-models";
            ExecStart = "${pkgs.llama-swap}/bin/llama-swap -config %h/.config/llama-swap/config.yaml -listen ${cfg.listen} -watch-config";
            Restart = "always";
            RestartSec = 2;
            Environment = [
              "LD_LIBRARY_PATH=/run/opengl-driver/lib:/run/opengl-driver-32/lib"
            ];
          };

          Install = { };
        };
      };
    };
}
