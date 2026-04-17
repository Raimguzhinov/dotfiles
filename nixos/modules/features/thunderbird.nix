{ ... }:
{
  perSystem =
    { pkgs, ... }:
    {
      packages.thunderbird = pkgs.thunderbird;
    };

  flake.homeModules.thunderbird =
    {
      config,
      pkgs,
      lib,
      ...
    }:
    let
      providers = {
        mail-ru = {
          imapHost = "imap.mail.ru";
          smtpHost = "smtp.mail.ru";
        };
        gmail = {
          imapHost = "imap.gmail.com";
          smtpHost = "smtp.gmail.com";
          smtpPort = 587;
        };
        yandex = {
          imapHost = "imap.yandex.ru";
          smtpHost = "smtp.yandex.ru";
          useStartTls = false;
          authMethod = 3;
        };
      };

      mkEmailAccount =
        {
          primary ? false,
          realName,
          address,
          userName ? address,
          imapHost,
          imapPort ? 993,
          smtpHost,
          smtpPort ? 465,
          useStartTls ? true,
          passwordCommand ? null,
          authMethod ? 10,
        }:
        {
          inherit
            primary
            realName
            address
            userName
            ;
        }
        // lib.optionalAttrs (passwordCommand != null) { inherit passwordCommand; }
        // {
          imap = {
            host = imapHost;
            port = imapPort;
            tls.enable = true;
          };
          smtp = {
            host = smtpHost;
            port = smtpPort;
            tls = {
              enable = true;
              useStartTls = useStartTls;
            };
          };
          thunderbird = {
            enable = true;
            profiles = [ "default" ];
            settings = id: {
              "mail.server.server_${id}.authMethod" = authMethod;
              "mail.smtpserver.smtp_${id}.authMethod" = authMethod;
            };
          };
        };

      mkProviderAccount = provider: args: mkEmailAccount (providers.${provider} // args);

    in
    {
      programs.thunderbird = {
        enable = true;
        settings."privacy.donottrackheader.enabled" = true;
        profiles."default" = {
          isDefault = true;
          settings = {
            "mail.spam.manualMark" = true;
            # Force light mode in email content
            "layout.css.prefers-color-scheme.content-override" = 1;
            "mail.folderpane.mode" = 4; # Unified (Smart) folders
            # Sort: oldest first, newest at bottom
            "mailnews.default_sort_order" = 1; # ascending
            "mailnews.default_sort_type" = 18; # by date
            "extensions.autoDisableScopes" = 0;
            "extensions.langpacks.signatures.required" = false;
            "intl.locale.requested" = "ru,en-US";
            # Telemetry
            "datareporting.healthreport.uploadEnabled" = false;
            "datareporting.policy.dataSubmissionEnabled" = false;
            "toolkit.telemetry.enabled" = false;
            "toolkit.telemetry.unified" = false;
            # Password manager — must stay enabled for mail account auth
            "signon.rememberSignons" = true;
            # Translator
            "extensions.translations.disabled" = true;
            # Allow remote content in messages
            "mailnews.message_display.disable_remote_image" = false;
          };
          accountsOrder = [
            "mail-ru"
            "protei"
            "google-new"
            "google-old"
            "yandex"
          ];
        };
      };

      home.file.".thunderbird/default/extensions/langpack-ru@thunderbird.mozilla.org.xpi".source =
        pkgs.fetchurl
          {
            url = "https://releases.mozilla.org/pub/thunderbird/releases/${pkgs.thunderbird.unwrapped.version}/linux-x86_64/xpi/ru.xpi";
            sha256 = "sha256-ZiHKhxu+70Og7kgojgjVJmq8JPaqLZO0YPSWJjohnkc=";
          };

      accounts.email.accounts = {
        "mail-ru" = mkProviderAccount "mail-ru" {
          primary = true;
          realName = "Диас Раймгужинов";
          address = "dias.raim@mail.ru";
        };
        "protei" = mkEmailAccount {
          imapHost = "imap.protei-lab.ru";
          smtpHost = "smtp.protei-lab.ru";
          useStartTls = false;
          authMethod = 3;
          realName = "Dias Raimguzhinov";
          address = "raimguzhinov@protei-lab.ru";
          passwordCommand = "${pkgs.gopass}/bin/gopass show protei.ru/raimguzhinov email-password";
        };
        "google-new" = mkProviderAccount "gmail" {
          realName = "Dias Raimguzhinov";
          address = "disas.raim@gmail.com";
        };
        "google-old" = mkProviderAccount "gmail" {
          realName = "Ra1m";
          address = "iron.men0333@gmail.com";
        };
        "yandex" = mkProviderAccount "yandex" {
          realName = "Диас Раймгужинов";
          address = "diasraim@yandex.ru";
          passwordCommand = "${pkgs.gopass}/bin/gopass show yandex.ru/diasraim@yandex.ru thunderbird";
        };
      };
    };
}
