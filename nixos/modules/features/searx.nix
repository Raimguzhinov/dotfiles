{ ... }:
{
  flake.nixosModules.searx =
    {
      lib,
      pkgs,
      pkgs-unstable,
      ...
    }:

    let
      searxSecretFile = "/var/lib/searx-secret/env";
    in
    {
      config = {
        users.users.searx.uid = 989;

        systemd.services.searx-secret = {
          requiredBy = [
            "searx-init.service"
            "searx.service"
          ];
          before = [
            "searx-init.service"
            "searx.service"
          ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            StateDirectory = "searx-secret";
            StateDirectoryMode = "0700";
            UMask = "0077";
          };
          script = /* bash */ ''
            if [[ ! -s ${searxSecretFile} ]]; then
              printf 'SEARXNG_SECRET=%s\n' \
                "$(${lib.getExe pkgs.openssl} rand -hex 32)" > ${searxSecretFile}
            fi
          '';
        };

        services.searx = {
          enable = true;
          package = pkgs-unstable.searxng;
          domain = "localhost";
          environmentFile = searxSecretFile;
          settings = {
            server = {
              port = 8899;
              bind_address = "127.0.0.1";
              secret_key = "$SEARXNG_SECRET";
            };
            search = {
              formats = [
                "html"
                "json"
              ];
              default_lang = "en-US";
              suspended_times = {
                SearxEngineAccessDenied = 900;
                SearxEngineCaptcha = 3600;
                SearxEngineTooManyRequests = 900;
                cf_SearxEngineCaptcha = 86400;
                cf_SearxEngineAccessDenied = 3600;
                recaptcha_SearxEngineCaptcha = 86400;
              };
            };
            engines = [
              {
                name = "google";
                disabled = false;
              }
              {
                name = "bing";
                disabled = false;
              }
              {
                name = "yandex";
                disabled = false;
              }
              {
                name = "brave";
                disabled = true;
              }
            ];
          };
        };
      };
    };
}
