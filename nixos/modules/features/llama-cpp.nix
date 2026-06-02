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
        version = "9482";
        src = pkgs.fetchFromGitHub {
          owner = "ggml-org";
          repo = "llama.cpp";
          tag = "b9482";
          hash = "sha256-hS9t1n4Gj+QVCAQ7J7m/O5mH9aPg8UPNxm2PmDnrZTA=";
          leaveDotGit = true;
          postFetch = ''
            git -C "$out" rev-parse --short HEAD > $out/COMMIT
            find "$out" -name .git -print0 | xargs -0 rm -rf
          '';
        };
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [
          pkgs.spirv-headers
        ];
        cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
          "-DBUILD_SHARED_LIBS=OFF"
          "-DGGML_CUDA=OFF"
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
    { pkgs, pkgs-unstable, ... }:
    let
      llamaCppOptimized = mkLlamaCppOptimized pkgs-unstable;
    in
    {
      packages = {
        llama-cpp = llamaCppOptimized;
        llama-swap = pkgs-unstable.llama-swap;
      };
    };

  flake.homeModules.llamaCpp =
    {
      config,
      lib,
      pkgs,
      pkgs-unstable,
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

      fetchModelsScript =
        let
          hfModels = lib.filterAttrs (_: m: m.hf != null) enabledModels;
          downloadSnippets = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (
              _name: model:
              let
                repo = model.hf.repo;
                file = model.hf.file;
                revision = if model.hf.revision != null then model.hf.revision else "main";
                outDir = "${cacheBaseDir}/${sanitizeRepo lib repo}";
                outFile = "${outDir}/${file}";
                url = "https://huggingface.co/${repo}/resolve/${revision}/${file}";
              in
              ''
                mkdir -p ${lib.escapeShellArg outDir}
                if [[ ! -f ${lib.escapeShellArg outFile} ]]; then
                  echo "[llama-swap] downloading ${repo}/${file}"
                  ${pkgs.wget}/bin/wget \
                    --progress=dot:giga \
                    -c \
                    -O ${lib.escapeShellArg outFile}.part \
                    ${lib.escapeShellArg url} \
                    && mv ${lib.escapeShellArg outFile}.part ${lib.escapeShellArg outFile}
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
        exec ${systemctlUser} start --no-block llama-swap.service
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

          models."qwen3.5-4b-mtp" = {
            enable = mkDefault true;
            hf = {
              repo = mkDefault "unsloth/Qwen3.5-4B-MTP-GGUF";
              file = mkDefault "Qwen3.5-4B-UD-Q4_K_XL.gguf";
            };
            ctxSize = mkDefault 16384;
            threads = mkDefault 8;
            threadsBatch = mkDefault 8;
            extraArgs = mkDefault [
              "--jinja" # OpenAI tool calls требуют jinja chat templates.
              "--temp 0.6"
              "--top-p 0.95"
              "--top-k 20"
              "--presence-penalty 0.0"
              "--repeat-penalty 1.0"
              "--batch-size 512"
              "--ubatch-size 256"
              "--flash-attn on"
              "--parallel 1"
              "--spec-draft-n-max 6"
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
            TimeoutStartSec = "5h";
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
