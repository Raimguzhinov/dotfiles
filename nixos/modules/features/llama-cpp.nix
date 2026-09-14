{ ... }:
{
  flake.nixosModules.llamaCpp =
    { pkgs, pkgs-unstable, ... }:
    {
      config = {
        services.llama-cpp = {
          enable = true;
          host = "0.0.0.0";
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
            "granite-4.2-3b" = {
              hf-repo = "ibm-granite/granite-4.2-3b-GGUF";
              hf-file = "granite-4.2-3b-Q4_K_M.gguf";
              alias = "ibm-granite/granite-4.2-3b";
              ctx-size = "32768";
              temp = "0.7";
              top-p = "0.95";
              jinja = "on";
              flash-attn = "on";
            };
          };
          extraFlags = [
            "--batch-size"
            "512"
            "--ubatch-size"
            "256"
            "--parallel"
            "1"
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
