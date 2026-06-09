{ ... }:
{
  flake.nixosModules.llamaCpp =
    { pkgs, pkgs-unstable, ... }:
    {
      config = {
        services.llama-cpp = {
          enable = true;
          port = 8085;
          package = pkgs-unstable.llama-cpp.override {
            blasSupport = true;
            vulkanSupport = true;
            cudaSupport = false;
            rocmSupport = false;
            metalSupport = false;
            openclSupport = false;
          };
          modelsPreset = {
            "qwen3.5-4b-mtp" = {
              hf-repo = "unsloth/Qwen3.5-4B-MTP-GGUF";
              hf-file = "Qwen3.5-4B-Q4_K_M.gguf";
              alias = "unsloth/Qwen3.5-4B-MTP";
              temp = "0.6";
              top-p = "0.95";
              top-k = "20";
              jinja = "on";
              presence-penalty = "0.0";
              repeat-penalty = "1.0";
              flash-attn = "on";
              spec-draft-n-max = "2";
            };
          };
          extraFlags = [
            "--batch-size" "512"
            "--ubatch-size" "256"
            "--parallel" "1"
          ];
        };
      };
    };

  flake.homeModules.llamaCpp =
    { pkgs-unstable, ... }:
    {
      home.packages = [
        (pkgs-unstable.llama-cpp.override {
          blasSupport = true;
          vulkanSupport = true;
          cudaSupport = false;
          rocmSupport = false;
          metalSupport = false;
          openclSupport = false;
        })
      ];
    };
}
