{ ... }:
{
  flake.nixosModules.configThinkpadT495 =
    {
      config,
      lib,
      pkgs,
      pkgs-unstable,
      llm-agents,
      inputs,
      hostname,
      username,
      version,
      homeModules,
      ...
    }:
    let
      kodi = pkgs.kodi-gbm.withPackages (p: [ p.jellyfin ]);
    in
    {
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
      boot.kernelParams = [ "video=eDP-1:d" ];

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        auto-optimise-store = true;
        connect-timeout = 10;
        stalled-download-timeout = 30;
        download-attempts = 2;
        fallback = true;
        extra-substituters = [
          "https://mirror.yandex.ru/nixos?priority=50"
          "https://mirrors.ustc.edu.cn/nix-channels/store?priority=60"
          "https://nix-community.cachix.org"
          "https://niri.cachix.org"
          "https://notashelf.cachix.org"
          "https://noctalia.cachix.org"
          "https://cache.numtide.com"
        ];
        extra-trusted-public-keys = [
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
          "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
          "notashelf.cachix.org-1:VTTBFNQWbfyLuRzgm2I7AWSDJdqAa11ytLXHBhrprZk="
          "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
          "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g="
        ];
      };
      nix.settings.trusted-users = [ username ];

      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };

      nix.registry.nixpkgs.flake = inputs.nixpkgs;
      nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

      nixpkgs.config.allowUnfree = true;

      networking.hostName = hostname;
      networking.networkmanager.enable = true;
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 22 ];
        trustedInterfaces = [ config.services.tailscale.interfaceName ];
      };

      networking.nftables.enable = true;
      services.tailscale = {
        enable = true;
        openFirewall = true;
      };
      systemd.services.tailscaled.environment.TS_DEBUG_FIREWALL_MODE = "nftables";

      systemd.services.tailscale-serve-thinkrail = {
        after = [ "tailscaled.service" ];
        wants = [ "tailscaled.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          Restart = "on-failure";
          RestartSec = 5;
          ExecStart = "${lib.getExe config.services.tailscale.package} serve --bg --https=443 http://localhost:24242";
        };
      };

      time.timeZone = "Asia/Novosibirsk";
      i18n.defaultLocale = "en_US.UTF-8";

      # Reasonable console fonts for a headless/TUI-first system.
      console = {
        # Terminus with unicode glyphs; good default for Cyrillic + general CLI usage.
        font = "${pkgs.terminus_font}/share/consolefonts/ter-u16n.psf.gz";
        useXkbConfig = true;
      };
      fonts = {
        fontconfig.enable = true;
        packages = with pkgs; [
          terminus_font
          dejavu_fonts
          noto-fonts
        ];
      };

      services.logind.settings.Login = {
        HandleLidSwitch = "ignore";
        HandleLidSwitchExternalPower = "ignore";
        HandleLidSwitchDocked = "ignore";
      };

      services.thinkfan.enable = true;

      hardware.graphics.enable = true;

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      users.users.${username} = {
        isNormalUser = true;
        linger = true;
        extraGroups = [
          "wheel"
          "networkmanager"
        ];
        initialHashedPassword = # mkpasswd <password>
          "$y$j9T$u06AsIj.fZtLVi2I0teH9.$IRF6NKQyvVgQKtr7r6PPAHO3CPnvp/nPHxVj.SBgBK4";
        openssh.authorizedKeys.keyFiles = [
          (builtins.fetchurl {
            url = "https://github.com/Raimguzhinov.keys";
            sha256 = "sha256-QzT6y3xDYuPq9NmuqhWqeE9a9pGpgGFqxvrzsuzZ6Eo=";
          })
        ];
      };

      security.sudo.wheelNeedsPassword = false;

      # CLI-first defaults
      users.defaultUserShell = pkgs.zsh;
      programs.zsh.enable = true;

      environment.systemPackages = with pkgs; [
        bat
        btop
        chawan
        llm-agents.claude-code
        llm-agents.codex
        curl
        eza
        fd
        fzf
        git
        glow
        htop
        jocalsend
        pre-commit
        ripgrep
        rsync
        vim
        wget
        yazi
      ];

      users.users.kodi = {
        isNormalUser = true;
        extraGroups = [
          "video"
          "render"
          "input"
          "audio"
        ];
      };

      services.greetd = {
        enable = true;
        settings = {
          initial_session = {
            command = "${kodi}/bin/kodi-standalone";
            user = "kodi";
          };
          default_session.command = "${pkgs.greetd}/bin/agreety --cmd ${kodi}/bin/kodi-standalone";
        };
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = {
          inherit pkgs-unstable;
          inherit llm-agents;
          inherit hostname;
          inherit username;
        };
        users.root =
          { ... }:
          {
            programs.home-manager.enable = true;
            home.username = "root";
            home.homeDirectory = "/root";
            home.stateVersion = version;
            imports = [
              inputs.nvf.homeModules.default
              homeModules.git
              homeModules.neovim
              homeModules.tools
            ];
          };
        users.${username} =
          { ... }:
          {
            programs.home-manager.enable = true;
            home.username = username;
            home.stateVersion = version;
            home.homeDirectory = "/home/${username}";
            imports = [
              inputs.nvf.homeModules.default
              homeModules.git
              homeModules.herdr
              homeModules.neovim
              homeModules.thinkrail
              homeModules.tools
            ];
            systemd.user.services.thinkrail.Install.WantedBy = lib.mkForce [ "default.target" ];
          };
      };

      system.stateVersion = version;
    };
}
