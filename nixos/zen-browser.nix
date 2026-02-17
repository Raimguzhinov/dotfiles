{ config, pkgs, ... }:

{
  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = [ pkgs.firefoxpwa ];
    policies =
      let
        mkExtensionSettings = builtins.mapAttrs (
          _: pluginId: {
            install_url = "https://addons.mozilla.org/firefox/downloads/latest/${pluginId}/latest.xpi";
            installation_mode = "force_installed";
          }
        );
      in
      {
        AutofillAddressEnabled = true;
        AutofillCreditCardEnabled = false;
        DisableAppUpdate = true;
        DisableFeedbackCommands = true;
        DisableFirefoxStudies = true;
        DisablePocket = true;
        DisableTelemetry = true;
        DontCheckDefaultBrowser = true;
        NoDefaultBookmarks = true;
        OfferToSaveLogins = false;
        EnableTrackingProtection = {
          Value = true;
          Locked = true;
          Cryptomining = true;
          Fingerprinting = true;
        };
        ExtensionSettings = mkExtensionSettings {
          # for unfree extensions
          "firefox@tampermonkey.net" = "tampermonkey";
        };
      };
    profiles."default" =
      let
        containers = {
          Personal = {
            color = "blue";
            icon = "fingerprint";
            id = 1;
          };
          Work = {
            color = "yellow";
            icon = "briefcase";
            id = 2;
          };
          Shopping = {
            color = "purple";
            icon = "dollar";
            id = 3;
          };
        };
        spaces = {
          "tmp" = {
            id = "c6de089c-410d-4206-961d-ab11f988d40a";
            icon = "👽";
            position = 1000;
          };
          "dev" = {
            id = "cdd10fab-4fc5-494b-9041-325e5759195b";
            icon = "🛠️";
            container = containers."Work".id;
            position = 2000;
          };
          "nix" = {
            id = "2441acc9-79b1-4afb-b582-ee88ce554ec0";
            icon = "❄️";
            container = containers."Personal".id;
            position = 3000;
            theme = {
              type = "gradient";
              colors = [
                {
                  red = 150;
                  green = 190;
                  blue = 230;
                  algorithm = "floating";
                  type = "explicit-lightness";
                }
              ];
              opacity = 0.2;
              texture = 0.5;
            };
          };
          "edu" = {
            id = "78aabdad-8aae-4fe0-8ff0-2a0c6c4ccc24";
            icon = "📚";
            container = containers."Personal".id;
            position = 4000;
          };
        };
        pins = {
          "GitHub" = {
            id = "9d8a8f91-7e29-4688-ae2e-da4e49d4a179";
            container = containers."Work".id;
            url = "https://github.com";
            isEssential = true;
            position = 101;
          };
          "YouTrack Timetrack" = {
            id = "8af62707-0722-4049-9801-bedced343333";
            container = containers."Work".id;
            url = "https://youtrack.protei.ru/timesheets";
            isEssential = true;
            position = 102;
          };
          "Folo" = {
            id = "fb316d70-2b5e-4c46-bf42-f4e82d635153";
            container = containers."Work".id;
            url = "https://portal.protei.ru";
            isEssential = true;
            position = 103;
          };
          "Nix awesome" = {
            id = "d85a9026-1458-4db6-b115-346746bcc692";
            workspace = spaces."nix".id;
            isGroup = true;
            isFolderCollapsed = false;
            editedTitle = true;
            position = 200;
          };
          "Nix Packages" = {
            id = "f8dd784e-11d7-430a-8f57-7b05ecdb4c77";
            workspace = spaces."nix".id;
            folderParentId = pins."Nix awesome".id;
            url = "https://search.nixos.org/packages";
            position = 201;
          };
          "Nix Options" = {
            id = "92931d60-fd40-4707-9512-a57b1a6a3919";
            workspace = spaces."nix".id;
            folderParentId = pins."Nix awesome".id;
            url = "https://search.nixos.org/options";
            position = 202;
          };
          "Home Manager Options" = {
            id = "2eed5614-3896-41a1-9d0a-a3283985359b";
            workspace = spaces."nix".id;
            folderParentId = pins."Nix awesome".id;
            url = "https://home-manager-options.extranix.com";
            position = 203;
          };
        };
        search = {
          force = true;
          default = "ddg"; # duckduckgo
          engines = {
            mynixos = {
              name = "My NixOS";
              urls = [
                {
                  template = "https://mynixos.com/search?q={searchTerms}";
                  params = [
                    {
                      name = "query";
                      value = "searchTerms";
                    }
                  ];
                }
              ];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@hx" ];
            };
            nix-packages = {
              name = "NixOS Search";
              urls = [
                {
                  template = "https://search.nixos.org/packages";
                  params = [
                    {
                      name = "type";
                      value = "packages";
                    }
                    {
                      name = "query";
                      value = "{searchTerms}";
                    }
                  ];
                }
              ];
              icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
              definedAliases = [ "@nix" ];
            };
            google.metaData.alias = "@goo";
            youtube.metaData.alias = "@you";
            wikipedia-ru.metaData.alis = "@wiki";
            yandex = {
              name = "Yandex";
              urls = [ { template = "https://ya.ru/search?text={searchTerms}"; } ];
              iconMapObj."16" = "https://yastatic.net/s3/home-static/_/3a/3aad4345be1368a10e2eaa78143a4cb5.png";
              definedAliases = [ "@ya" ];
            };
            translate = {
              name = "Yandex Translate";
              urls = [ { template = "https://translate.yandex.ru/?text={searchTerms}"; } ];
              iconMapObj."16" = "https://translate.yandex.ru/icons/favicon.ico";
              definedAliases = [ "@trans" ];
            };
          };
        };
      in
      {
        containersForce = true;
        pinsForce = true;
        spacesForce = true;
        inherit
          containers
          pins
          spaces
          search
          ;
        extensions.packages = with pkgs.firefox-addons; [
          ublock-origin
        ];
      };
  };
}
