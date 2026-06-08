{
  description = "NixOS configuration";

  nixConfig = {
    extra-experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    # При недоступности кэша — сборка из исходников
    fallback = true;
    # Минимальные таймауты: лучше быстро упасть, чем выжимать плохой интернет
    connect-timeout = 3;
    stalled-download-timeout = 10;
    download-attempts = 1;
    extra-substituters = [
      "https://mirror.yandex.ru/nixos"
      "https://mirrors.ustc.edu.cn/nix-channels/store"
      "https://nix-community.cachix.org"
      "https://niri.cachix.org"
      "https://notashelf.cachix.org"
      "https://noctalia.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "notashelf.cachix.org-1:VTTBFNQWbfyLuRzgm2I7AWSDJdqAa11ytLXHBhrprZk="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-jetbrains.url = "github:NixOS/nixpkgs/1c3fe55ad329cbcb28471bb30f05c9827f724c76";
    nixpkgs-go21.url = "github:NixOS/nixpkgs/5ed627539ac84809c78b2dd6d26a5cebeb5ae269";
    nixpkgs-protobuf23.url = "github:NixOS/nixpkgs/ebe4301cbd8f81c4f8d3244b3632338bbeb6d49c";
    nixpkgs-protoc-gen-go-grpc1_3_0.url = "github:NixOS/nixpkgs/566e53c2ad750c84f6d31f9ccb9d00f823165550";
    nixpkgs-protoc-gen-go1_36_1.url = "github:NixOS/nixpkgs/a1945f760a8fe019a4d753808de424dcd4e5b3cf";
    flake-compat.url = "github:NixOS/flake-compat";
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-utils.url = "github:numtide/flake-utils";
    import-tree.url = "github:vic/import-tree";
    claude-code = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs-stable.follows = "nixpkgs";
    };
    niri-float-sticky = {
      url = "github:probeldev/niri-float-sticky";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    nix-firefox-addons = {
      url = "github:osipog/nix-firefox-addons";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
    };
    nvf = {
      url = "github:notashelf/nvf";
      inputs.flake-compat.follows = "flake-compat";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    obsidian-plugins = {
      url = "github:cjavad/nixpille-obsidian-community-plugins";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    meridian = {
      url = "github:rynfar/meridian";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.flake-parts.lib.mkFlake { inherit inputs; } (inputs.import-tree ./modules);
}
