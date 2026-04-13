{ config, pkgs, ... }:

{
  home.file.".config/zen/native-messaging-hosts/com.add0n.node.json".text = ''
    {
      "name": "com.add0n.node",
      "description": "Node Host for Native Messaging",
      "path": "${config.home.homeDirectory}/.config/com.add0n.node/run.sh",
      "type": "stdio",
      "allowed_extensions": [
        "{b8fa78dd-dae1-4839-9d0e-ce5e213083ce}",
        "{5610edea-88c1-4370-b93d-86aa131971d1}",
        "{94782f74-1a58-4332-a803-00006221a9d0}",
        "{3128fe8f-f039-42ea-8b12-126f78387074}",
        "{8db82a75-48fd-452a-81cf-bd40b2e60dac}",
        "{42dce5a2-467b-4d7b-ad11-50f4ab3d03cf}",
        "{086f665e-6a55-4107-9147-f9a14e72b137}",
        "{0bcb72f8-7da8-4071-905c-2de13f5aad3a}",
        "{15a602dd-abe0-4cff-875b-c5acd77727b6}",
        "{5cf4e3be-dd11-4589-befe-1b9e5037792b}",
        "{9d3b260b-886d-4263-b9d6-81d756ee4929}",
        "{4d3bd246-4326-4ec1-bb49-a27cfd57ca08}",
        "{0ff128a1-c286-4e73-bffa-9ae879b244d5}",
        "{65b77238-bb05-470a-a445-ec0efe1d66c4}",
        "{6b954d17-d17c-4a19-8fe6-ee8052a562d6}",
        "{9a71ec90-d0b6-44af-833f-efe418ff8454}",
        "{f73df109-8fb4-453e-8373-f59e61ca4da3}",
        "{d22a1484-dcef-44e9-ab52-80f0f4a331a3}",
        "{0d3afca0-aedf-491f-b0f9-9ffc22113ea8}",
        "{802a552e-13d1-4683-a40a-1e5325fba4bb}",
        "{3e8ae4b2-678d-4a63-8104-4d4d8d3b4f46}",
        "{cd04e15e-6b23-4648-860d-0057602a5c2a}",
        "{8e409c88-e088-4ce8-8506-5a91e6c502a8}",
        "{655859e0-3c86-43a1-9794-88721dacc481}",
        "{00186e07-f704-41ce-90aa-b09d4f49a7db}",
        "{c88f6be2-3757-446b-be27-27eedddbcae0}",
        "{73e2414b-dc86-4e63-8ac6-231e8efe870c}"
      ]
    }
  '';
  home.file.".config/zen/native-messaging-hosts/com.justwatch.gopass.json".text = ''
    {
      "name": "com.justwatch.gopass",
      "description": "Gopass wrapper to search and return passwords",
      "path": "${config.home.homeDirectory}/.config/gopass/gopass_wrapper.sh",
      "type": "stdio",
      "allowed_extensions": [
        "{eec37db0-22ad-4bf1-9068-5ae08df8c7e9}"
      ]
    }
  '';

  programs.zen-browser = {
    enable = true;
    nativeMessagingHosts = [ pkgs.firefoxpwa ];
    policies = {
      AutofillAddressEnabled = true;
      AutofillCreditCardEnabled = false;
      DisableAppUpdate = true;
      DisableFeedbackCommands = true;
      DisableFirefoxStudies = true;
      DisablePocket = true;
      DefaultBrowserSettingEnabled = true;
      DisableTelemetry = true;
      DontCheckDefaultBrowser = false;
      NoDefaultBookmarks = true;
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
      TranslateEnabled = false;
      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        Fingerprinting = true;
      };
    };
    profiles.default =
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
            theme = {
              type = "gradient";
              colors = [
                {
                  red = 200;
                  green = 200;
                  blue = 200;
                  algorithm = "floating";
                  type = "explicit-lightness";
                }
              ];
              opacity = 0.2;
              texture = 0.3;
            };
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
          "YouTube (fun)" = {
            id = "56dee82e-0031-4a6d-987f-5e260984f6f1";
            workspace = spaces."tmp".id;
            url = "https://youtube.com";
            isEssential = true;
            position = 101;
          };
          "VK Video" = {
            id = "e26521a5-8680-44b6-84fe-237eba982988";
            workspace = spaces."tmp".id;
            url = "https://vkvideo.ru/";
            isEssential = true;
            position = 102;
          };
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
          "Portal" = {
            id = "fb316d70-2b5e-4c46-bf42-f4e82d635153";
            container = containers."Work".id;
            url = "https://portal.protei.ru";
            isEssential = true;
            position = 103;
          };
          "Cloud" = {
            id = "0412dc27-50b0-436b-9672-484826c16a4a";
            container = containers."Work".id;
            url = "https://cloud.protei.ru";
            isEssential = true;
            position = 104;
          };
          "Work AI" = {
            id = "5cb769dd-b81c-448f-8d49-db3b7b21f382";
            container = containers."Work".id;
            url = "https://chat.ai.protei.ru";
            isEssential = true;
            position = 105;
          };
          "Prosto Retro" = {
            id = "94358878-dd2e-452a-8a5e-9d640b7a16ca";
            container = containers."Work".id;
            url = "https://prostoretro.ru";
            isEssential = true;
            position = 106;
          };
          "Mermaid" = {
            id = "627c9c45-b667-4407-ae76-89946defcc30";
            container = containers."Work".id;
            url = "https://mermaid.ai";
            isEssential = true;
            position = 107;
          };
          "Claude" = {
            id = "c443f4f7-053c-470c-81fe-f5d027ab7e2a";
            container = containers."Work".id;
            url = "https://claude.ai";
            isEssential = true;
            position = 108;
          };
          "Local UC" = {
            id = "9274bec7-62f9-410d-b069-7f473e0c2771";
            workspace = spaces."dev".id;
            isGroup = true;
            isFolderCollapsed = true;
            editedTitle = true;
            position = 200;
          };
          "UC DEV 1" = {
            id = "dafd26a1-a8a7-43d2-b35f-afd9041548c2";
            workspace = spaces."dev".id;
            folderParentId = pins."Local UC".id;
            url = "https://localhost:8443";
            position = 201;
          };
          "UC DEV 2" = {
            id = "0145e878-e08b-4416-9359-f358772abfa7";
            workspace = spaces."dev".id;
            folderParentId = pins."Local UC".id;
            url = "https://localhost:28443";
            position = 201;
          };
          "Rapidoc" = {
            id = "316f559c-98cc-4943-bf06-8e91cf50e2eb";
            workspace = spaces."dev".id;
            folderParentId = pins."Local UC".id;
            url = "http://localhost:8088";
            position = 202;
          };
          "Swagger" = {
            id = "c9861491-6a28-4768-b8aa-f31775f8a210";
            workspace = spaces."dev".id;
            folderParentId = pins."Local UC".id;
            url = "http://localhost:8089";
            position = 202;
          };
          "LDAP DEV 1" = {
            id = "a177da02-d0bb-4ba0-bd3a-b13f01d625b1";
            workspace = spaces."dev".id;
            folderParentId = pins."Local UC".id;
            url = "http://localhost:20080";
            position = 203;
          };
          "LDAP DEV 2" = {
            id = "c4e42ddb-bfe1-4e65-8fc5-ecf94b8fb2f1";
            workspace = spaces."dev".id;
            folderParentId = pins."Local UC".id;
            url = "http://localhost:22080";
            position = 203;
          };
          "YouTube" = {
            id = "4de8d683-27cd-46fa-81be-916aba7cbbf9";
            container = containers."Personal".id;
            url = "https://youtube.com";
            isEssential = true;
            position = 101;
          };
          "ChatGPT" = {
            id = "d16715d1-32ee-42ff-9702-82484d8a1e98";
            container = containers."Personal".id;
            url = "https://chatgpt.com";
            isEssential = true;
            position = 102;
          };
          "Netcraze" = {
            id = "45920e9d-5d99-47d9-ad36-eceb174ca236";
            container = containers."Personal".id;
            url = "https://nixos.netcraze.pro";
            isEssential = true;
            position = 103;
          };
          "Amnezia" = {
            id = "19a42484-1174-4215-b27d-5033be52b877";
            container = containers."Personal".id;
            url = "https://m-3-3w5hsuiikq-ma.a.run.app/ru";
            isEssential = true;
            position = 104;
          };
          "Nix awesome" = {
            id = "d85a9026-1458-4db6-b115-346746bcc692";
            workspace = spaces."nix".id;
            isGroup = true;
            isFolderCollapsed = false;
            editedTitle = true;
            position = 200;
          };
          "Vimjoyer" = {
            id = "f2109d9f-ce16-47ab-959b-81536692d158";
            workspace = spaces."nix".id;
            folderParentId = pins."Nix awesome".id;
            url = "https://www.vimjoyer.com";
            position = 201;
          };
          "Nix Packages" = {
            id = "f8dd784e-11d7-430a-8f57-7b05ecdb4c77";
            workspace = spaces."nix".id;
            folderParentId = pins."Nix awesome".id;
            url = "https://search.nixos.org/packages";
            position = 202;
          };
          "Nix Options" = {
            id = "92931d60-fd40-4707-9512-a57b1a6a3919";
            workspace = spaces."nix".id;
            folderParentId = pins."Nix awesome".id;
            url = "https://search.nixos.org/options";
            position = 203;
          };
          "Home Manager Options" = {
            id = "2eed5614-3896-41a1-9d0a-a3283985359b";
            workspace = spaces."nix".id;
            folderParentId = pins."Nix awesome".id;
            url = "https://home-manager-options.extranix.com";
            position = 204;
          };
        };
        search = {
          force = true;
          default = "ddg"; # duckduckgo
          engines = {
            google.metaData.alias = "@goo";
            wikipedia-ru.metaData.alias = "@wiki";
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
              definedAliases = [ "@hm" ];
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
            youtube = {
              name = "YouTube";
              urls = [ { template = "https://www.youtube.com/results?search_query={searchTerms}"; } ];
              iconMapObj."16" = "https://www.youtube.com/favicon.ico";
              definedAliases = [ "@you" ];
            };
            habr = {
              name = "Habr";
              urls = [ { template = "https://habr.com/ru/search/?q={searchTerms}"; } ];
              iconMapObj."16" = "https://habr.com/favicon.ico";
              definedAliases = [ "@habr" ];
            };
            github = {
              name = "GitHub";
              urls = [ { template = "https://github.com/search?q={searchTerms}"; } ];
              iconMapObj."16" = "https://github.com/favicon.ico";
              definedAliases = [
                "@gh"
                "@git"
              ];
            };
            gitlab = {
              name = "GitLab";
              urls = [ { template = "https://git.protei.ru/search?q={searchTerms}"; } ];
              iconMapObj."16" = "https://gitlab.com/favicon.ico";
              definedAliases = [ "@glab" ];
            };
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
        pinsForce = false;
        spacesForce = true;
        inherit
          containers
          pins
          spaces
          search
          ;
        settings = {
          "extensions.autoDisableScopes" = 0;
          "intl.locale.requested" = "ru,en-US";
          # Use PipeWire camera portal (xdg-desktop-portal) instead of V4L2
          "media.webrtc.camera.allow-pipewire" = true;

          # Addons settings
          "uBlock0@raymondhill.net".settings = {
            selectedFilterLists = [
              "ublock-filters"
              "ublock-badware"
              "ublock-privacy"
              "ublock-unbreak"
              "ublock-quick-fixes"
            ];
          };
        };
        keyboardShortcuts = [
          {
            # Enable the quit shortcut to prevent accidental closes
            id = "key_quitApplication";
            disabled = false;
          }
        ];
        # Search addons:
        # nix run github:osipog/nix-firefox-addons#search-addon ublock
        extensions.packages = with pkgs.firefoxAddons; [
          cookies-txt
          duckduckgo-for-firefox
          gopass-bridge
          gsconnect
          nighttab
          privacy-badger17
          sponsorblock
          tampermonkey
          traduzir-paginas-web
          ublock-origin
          vimium-ff
          web-clipper-obsidian
        ];
      };
  };
}
