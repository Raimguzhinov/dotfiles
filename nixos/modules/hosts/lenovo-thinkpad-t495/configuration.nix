{ ... }:
{
  flake.nixosModules.configThinkpadT495 =
    {
      config,
      lib,
      pkgs,
      pkgs-unstable,
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
      # Needed for `pkgs.claude-code` (and possibly other inputs-provided packages).
      nixpkgs.overlays = [
        inputs.claude-code.overlays.default
      ];

      networking.hostName = hostname;
      networking.networkmanager.enable = true;
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [ 22 ];
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
        claude-code
        codex
        curl
        eza
        fd
        fzf
        git
        glow
        htop
        jocalsend
        ripgrep
        rsync
        vim
        wget
        yazi
        zellij
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
              inputs.nvf.homeManagerModules.default
              homeModules.neovim
              homeModules.tools
              homeModules.git
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
              inputs.nvf.homeManagerModules.default
              homeModules.neovim
              homeModules.tools
              homeModules.git
            ];
          };
      };

      system.stateVersion = version;
    };
}
