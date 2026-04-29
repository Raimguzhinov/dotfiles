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

      networking.hostName = hostname;
      networking.firewall = {
        enable = true;
        allowedTCPPorts = [
          22
          80
          443
        ];
      };

      time.timeZone = "Europe/Moscow";
      i18n.defaultLocale = "en_US.UTF-8";

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
        openssh.authorizedKeys.keyFiles = [
          (builtins.fetchurl {
            url = "https://github.com/Raimguzhinov.keys";
            sha256 = "sha256-eWeyPsWYNQdiSrCZGGtTmpwhrSZztiHMDg6vgBZkGRs=";
          })
        ];
      };

      security.sudo.wheelNeedsPassword = false;

      environment.systemPackages = with pkgs; [
        curl
        git
        htop
        rsync
        vim
        wget
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

      services.matrix-synapse = {
        enable = true;
        settings = {
          server_name = "example.com"; # TODO
          public_baseurl = "https://matrix.example.com";
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
        };
      };

      services.mautrix-telegram = {
        enable = true;
        settings = {
          homeserver = {
            address = "http://127.0.0.1:8008";
            domain = "example.com"; # TODO
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
            "@${username}:example.com" = "admin"; # TODO
          };
          telegram = {
            api_id = 0; # TODO: https://my.telegram.org/apps
            api_hash = ""; # TODO
          };
        };
      };

      services.nginx = {
        enable = true;
        recommendedProxySettings = true;
        recommendedTlsSettings = true;
        virtualHosts = {
          "example.com" = { # TODO
            forceSSL = true;
            enableACME = true;
            locations."= /.well-known/matrix/server".extraConfig = ''
              add_header Content-Type application/json;
              return 200 '{"m.server":"matrix.example.com:443"}';
            '';
            locations."= /.well-known/matrix/client".extraConfig = ''
              add_header Content-Type application/json;
              add_header Access-Control-Allow-Origin *;
              return 200 '{"m.homeserver":{"base_url":"https://matrix.example.com"}}';
            '';
          };
          "matrix.example.com" = { # TODO
            forceSSL = true;
            enableACME = true;
            locations."/".proxyPass = "http://127.0.0.1:8008";
            locations."/".extraConfig = "client_max_body_size 50M;";
          };
        };
      };

      security.acme = {
        acceptTerms = true;
        defaults.email = "admin@example.com"; # TODO
      };

      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        extraSpecialArgs = {
          inherit pkgs-unstable;
          inherit username;
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
