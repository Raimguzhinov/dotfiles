{
  description = "Lightweight devshells for ~/Work (go + python)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts.url = "github:hercules-ci/flake-parts";

    # Keep toolchain pins consistent with main nixos flake.
    nixpkgs-go21.url = "github:NixOS/nixpkgs/5ed627539ac84809c78b2dd6d26a5cebeb5ae269";
    nixpkgs-protobuf23.url = "github:NixOS/nixpkgs/ebe4301cbd8f81c4f8d3244b3632338bbeb6d49c";
    nixpkgs-protoc-gen-go-grpc1_3_0.url = "github:NixOS/nixpkgs/566e53c2ad750c84f6d31f9ccb9d00f823165550";
    nixpkgs-protoc-gen-go1_36_1.url = "github:NixOS/nixpkgs/a1945f760a8fe019a4d753808de424dcd4e5b3cf";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
      ];

      imports = [
        ../modules/devshells/go.nix
        ../modules/devshells/python.nix
      ];

      perSystem =
        {
          config,
          pkgs,
          ...
        }:
        {
          devShells.work = pkgs.mkShell {
            inputsFrom = [
              config.devShells.go
              config.devShells.python
            ];
          };
        };
    };
}
