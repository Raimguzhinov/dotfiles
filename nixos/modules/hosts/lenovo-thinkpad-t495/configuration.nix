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
      # Matrix deployment (router terminates TLS):
      # - Server name is exactly the public domain you expose to the Internet.
      # - No /.well-known delegation is used/required.
      serverName = "matrix.nixos.netcraze.pro";

      # mautrix-telegram needs its appservice registration registered in Synapse.
      mautrixTelegramRegistration = lib.attrByPath [
        "services"
        "mautrix-telegram"
        "registrationFile"
      ] "/var/lib/mautrix-telegram/registration.yaml" config;
    in
    {
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        auto-optimise-store = true;
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };

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

      # mautrix-telegram pulls libolm for Matrix E2EE support; nixpkgs marks it insecure.
      # You need this until the bridge stack migrates away from olm (or you remove the dependency).
      nixpkgs.config.permittedInsecurePackages = [
        "olm-3.2.16"
      ];

      networking.hostName = hostname;
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [
          22
          80
          443
        ];
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

      # Enable the Ly Display Manager (TUI).
      services.displayManager.ly = {
        enable = true;
        settings = {
          animation = "colormix"; # "matrix";
          bigclock = true;
          clear_password = true;
          session_log = ".local/state/ly-session.log";
        };
      };
      # Ensure services start properly
      systemd.services.display-manager.environment.XDG_CURRENT_DESKTOP = "X-NIXOS-SYSTEMD-AWARE";

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };

      users.users.${username} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        initialHashedPassword = # mkpasswd <password>
          "$y$j9T$u06AsIj.fZtLVi2I0teH9.$IRF6NKQyvVgQKtr7r6PPAHO3CPnvp/nPHxVj.SBgBK4";
        openssh.authorizedKeys.keyFiles = [
          (builtins.fetchurl {
            url = "https://github.com/Raimguzhinov.keys";
            sha256 = "sha256-eWeyPsWYNQdiSrCZGGtTmpwhrSZztiHMDg6vgBZkGRs=";
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
        thinkfan
        vim
        wget
        yazi
        zellij
      ];

      services.postgresql = {
        enable = true;
        ensureDatabases = [
          "matrix-synapse"
          "mautrix-telegram"
        ];
        ensureUsers = [
          {
            name = "matrix-synapse";
            ensureDBOwnership = true;
          }
          {
            name = "mautrix-telegram";
            ensureDBOwnership = true;
          }
        ];
      };

      systemd.tmpfiles.rules = [
        # Secret env file for mautrix-telegram (create empty, fill manually on the server).
        "d /var/lib/mautrix-telegram 0700 mautrix-telegram mautrix-telegram - -"
        "f /var/lib/mautrix-telegram/secrets.env 0600 mautrix-telegram mautrix-telegram - -"
        # Basic-auth password file for nginx (create empty, fill with `htpasswd` manually).
        "d /var/lib/nginx 0750 nginx nginx - -"
        "f /var/lib/nginx/matrix.htpasswd 0640 nginx nginx - -"
      ];

      services.matrix-synapse = {
        enable = true;
        settings = {
          # This must match the domain part of your Matrix user IDs.
          server_name = serverName;
          public_baseurl = "https://${serverName}";
          listeners = [
            {
              port = 8008;
              bind_addresses = [ "127.0.0.1" ];
              type = "http";
              tls = false;
              x_forwarded = true;
              resources = [
                {
                  names = [
                    "client"
                    "federation"
                  ];
                  compress = false;
                }
              ];
            }
          ];
          database = {
            name = "psycopg2";
            args = {
              database = "matrix-synapse";
              user = "matrix-synapse";
              host = "/run/postgresql";
              cp_min = 5;
              cp_max = 10;
            };
          };
          enable_registration = false;
          report_stats = false;

          # Register appservices (bridges) here.
          app_service_config_files = [ mautrixTelegramRegistration ];
        };
      };

      services.mautrix-telegram = {
        enable = true;
        # Local-only file on the server (not in git, not in the Nix store).
        # Example contents:
        #   MAUTRIX_TELEGRAM_TELEGRAM_API_ID=12345
        #   MAUTRIX_TELEGRAM_TELEGRAM_API_HASH=0123456789abcdef0123456789abcdef
        #
        # You can also put appservice tokens there if you want to pin them:
        #   MAUTRIX_TELEGRAM_APPSERVICE_AS_TOKEN=...
        #   MAUTRIX_TELEGRAM_APPSERVICE_HS_TOKEN=...
        environmentFile = "/var/lib/mautrix-telegram/secrets.env";
        settings = {
          homeserver = {
            address = "http://127.0.0.1:8008";
            domain = serverName;
          };
          appservice = {
            address = "http://127.0.0.1:29317";
            hostname = "127.0.0.1";
            port = 29317;
            database = "postgresql:///mautrix-telegram?host=/run/postgresql";
            bot_username = "telegrambot";
            bot_displayname = "Telegram bridge bot";
          };
          bridge.permissions = {
            "@${username}:${serverName}" = "admin";
          };
          # Telegram API credentials must be provided via `environmentFile` to avoid
          # leaking them into the Nix store.
        };
      };

      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        virtualHosts = {
          # Router handles TLS/auth; nginx on the ThinkPad serves plain HTTP.
          # Configure the router to proxy https://matrix.nixos.netcraze.pro -> http://<thinkpad>:80
          "${serverName}" = {
            forceSSL = false;
            enableACME = false;
            listen = [
              {
                addr = "0.0.0.0";
                port = 80;
              }
            ];
            # Keep Matrix client/federation endpoints publicly reachable.
            locations."/_matrix".proxyPass = "http://127.0.0.1:8008";
            locations."/_synapse".proxyPass = "http://127.0.0.1:8008";
            locations."/_matrix".extraConfig = "client_max_body_size 50M;";
            locations."/_synapse".extraConfig = "client_max_body_size 50M;";

            # Everything else is not needed for federation; require auth so the host isn't an open web surface.
            locations."/".extraConfig = ''
              auth_basic "Matrix admin";
              auth_basic_user_file /var/lib/nginx/matrix.htpasswd;
              return 404;
            '';

            # Synapse admin UI should never be world-accessible.
            locations."/_synapse/admin".extraConfig = ''
              auth_basic "Synapse admin";
              auth_basic_user_file /var/lib/nginx/matrix.htpasswd;
            '';
            locations."/_synapse/admin".proxyPass = "http://127.0.0.1:8008";
          };
        };
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = {
          inherit pkgs-unstable;
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
