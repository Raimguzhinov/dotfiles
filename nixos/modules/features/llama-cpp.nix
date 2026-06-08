{ ... }:
{
  flake.nixosModules.llamaCpp =
    { pkgs, ... }:
    {
      config = {
        services.llama-cpp = {
          enable = true;
          port = 8085;
          package = pkgs.llama-cpp.override {
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
              extra-args = [
                "--jinja"
                "--presence-penalty 0.0"
                "--repeat-penalty 1.0"
                "--batch-size 512"
                "--ubatch-size 256"
                "--flash-attn on"
                "--parallel 1"
                "--spec-draft-n-max 2"
              ];
            };
          };
        };
      };
    };

  flake.homeModules.llamaCpp =
    { pkgs, ... }:
    {
      home.packages = [
        (pkgs.llama-cpp.override {
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
