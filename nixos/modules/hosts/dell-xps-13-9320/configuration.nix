# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running 'nixos-help').
{ ... }:
{
  flake.nixosModules.configDellXps =
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

      # Bootloader.
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;

      # Systemd initrd + YubiKey FIDO2 unlock for LUKS systems
      boot.initrd.systemd.enable = true;
      boot.initrd.luks.devices =
        lib.mkIf (lib.hasPrefix "/dev/mapper/" (config.fileSystems."/".device or ""))
          {
            "cryptroot".crypttabExtraOpts = [
              "fido2-device=auto"
              "fido2-with-client-pin"
              "token-timeout=10"
            ];
          };

      # Flakes — experimental features must be in nix.settings for CLI commands
      # (flake.nix nixConfig only applies during flake evaluation)
      nix.settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
        auto-optimise-store = true;
      };
      nix.settings.trusted-users = [ username ];

      # Garbage collector
      nix.gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 14d";
      };

      nix.registry.nixpkgs.flake = inputs.nixpkgs;
      nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

      # Chromium policies
      programs.chromium.enable = true;
      programs.chromium.extraOpts = {
        DefaultBrowserSettingEnabled = false;
        TranslationEnabled = false;
        MetricsReportingEnabled = false;
        PasswordManagerEnabled = false;
        PasswordSharingEnabled = false;
        PasswordLeakDetectionEnabled = true;
        WebAppInstallForceList = [
          {
            url = "https://tankionline.com/play/";
            default_launch_container = "window";
          }
          {
            url = "https://uc.protei.ru";
            default_launch_container = "window";
          }
          {
            url = "https://web.max.ru/";
            default_launch_container = "window";
          }
          {
            url = "https://web.vk.me/";
            default_launch_container = "window";
          }
        ];
      };

      # Niri
      niri-flake.cache.enable = false;
      programs.niri.enable = true;
      hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          intel-compute-runtime
        ];
      };
      services.dbus.enable = true;

      # Home Manager configuration
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        sharedModules = [
          inputs.sops-nix.homeManagerModules.sops
        ];
        extraSpecialArgs = {
          inherit inputs;
          inherit pkgs-unstable;
          pkgs-jetbrains = import inputs.nixpkgs-jetbrains {
            system = pkgs.stdenv.hostPlatform.system;
            config.allowUnfree = true;
          };
          inherit username;
          inherit hostname;
        };
        users.root =
          { config, lib, ... }:
          {
            programs.home-manager.enable = true;
            home.username = "root";
            home.homeDirectory = "/root";
            home.stateVersion = version;
            imports = [
              inputs.nvf.homeManagerModules.default
              homeModules.neovim
              homeModules.tools
            ];
          };
        users.${username} =
          { config, lib, ... }:
          let
            yaziOpen = pkgs.writeShellApplication {
              name = "yazi-open";
              runtimeInputs = [
                pkgs.coreutils
                pkgs.findutils
                pkgs.xdg-terminal-exec
                config.programs.yazi.package
              ];
              text = # bash
                ''
                  target="''${1:-$HOME}"
                  [ -d "$target" ] || target="$(dirname "$target")"

                  key="$(printf '%s' "$target" | md5sum | cut -d' ' -f1)"
                  lock="''${XDG_RUNTIME_DIR:-/tmp}/yazi-open.$key.lock"

                  if [ -d "$lock" ] && [ -n "$(find "$lock" -maxdepth 0 -mmin +1)" ]; then
                    rmdir "$lock" || true
                  fi

                  mkdir "$lock" 2>/dev/null || exit 0
                  ( sleep 2; rmdir "$lock" 2>/dev/null || true ) &

                  exec xdg-terminal-exec yazi "$target"
                '';
            };

            yaziFileManager1 =
              let
                python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ]);
              in
              pkgs.writeTextFile {
                name = "yazi-filemanager1";
                executable = true;
                destination = "/bin/yazi-filemanager1";
                meta.mainProgram = "yazi-filemanager1";
                text = # python
                  ''
                    #!${python}/bin/python3
                    import os
                    import subprocess
                    import sys
                    from urllib.parse import unquote, urlparse

                    import gi

                    gi.require_version("Gio", "2.0")
                    from gi.repository import Gio, GLib

                    LAUNCHER = "${lib.getExe yaziOpen}"
                    NAME = "org.freedesktop.FileManager1"
                    OBJECT = "/org/freedesktop/FileManager1"

                    IFACE_XML = (
                        "<node><interface name='org.freedesktop.FileManager1'>"
                        "<method name='ShowFolders'>"
                        "<arg type='as' name='URIs' direction='in'/>"
                        "<arg type='s' name='StartupId' direction='in'/>"
                        "</method>"
                        "<method name='ShowItems'>"
                        "<arg type='as' name='URIs' direction='in'/>"
                        "<arg type='s' name='StartupId' direction='in'/>"
                        "</method>"
                        "<method name='ShowItemProperties'>"
                        "<arg type='as' name='URIs' direction='in'/>"
                        "<arg type='s' name='StartupId' direction='in'/>"
                        "</method>"
                        "</interface></node>"
                    )

                    NODE = Gio.DBusNodeInfo.new_for_xml(IFACE_XML)


                    def to_path(uri):
                        parsed = urlparse(uri)
                        if not parsed.scheme:
                            return uri
                        if parsed.scheme != "file":
                            return None
                        return unquote(parsed.path)


                    def handle(conn, sender, path, iface, method, params, invocation):
                        uris, _startup = params.unpack()
                        targets = []
                        for uri in uris:
                            target = to_path(uri)
                            if target is None:
                                continue
                            if method != "ShowFolders":
                                target = os.path.dirname(target.rstrip("/")) or "/"
                            if target not in targets:
                                targets.append(target)
                        for target in targets:
                            subprocess.Popen([LAUNCHER, target], start_new_session=True)
                        invocation.return_value(None)


                    def on_acquired(conn, name):
                        conn.register_object(OBJECT, NODE.interfaces[0], handle, None, None)


                    def on_lost(conn, name):
                        print("could not own " + name, file=sys.stderr, flush=True)
                        sys.exit(1)


                    Gio.bus_own_name(
                        Gio.BusType.SESSION,
                        NAME,
                        Gio.BusNameOwnerFlags.NONE,
                        on_acquired,
                        None,
                        on_lost,
                    )
                    GLib.MainLoop().run()
                  '';
              };

            yaziMimeTypes = [
              "inode/directory"
              "x-directory/normal"
            ];
            nvimMimeTypes = [
              "text/plain"
              "application/json"
              "application/schema+json"
              "application/ld+json"
              "application/toml"
              "application/yaml"
              "application/xml"
              "application/xml-dtd"
              "application/sql"
              "text/x-systemd-unit"
              "application/x-desktop"
              "text/markdown"
              "text/x-rst"
              "text/x-tex"
              "text/x-bibtex"
              "text/x-typst"
              "text/org"
              "text/troff"
              "application/x-shellscript"
              "application/x-csh"
              "application/x-fishscript"
              "application/x-awk"
              "application/x-m4"
              "text/x-python"
              "text/x-python3"
              "application/x-perl"
              "application/x-ruby"
              "application/x-php"
              "text/x-lua"
              "text/x-csrc"
              "text/x-chdr"
              "text/x-c++src"
              "text/x-c++hdr"
              "text/x-objcsrc"
              "text/x-objc++src"
              "text/x-java"
              "text/x-go"
              "text/rust"
              "text/javascript"
              "text/x-scala"
              "text/x-kotlin"
              "text/x-haskell"
              "text/x-literate-haskell"
              "text/x-elixir"
              "text/x-erlang"
              "text/x-ocaml"
              "text/x-crystal"
              "text/x-nim"
              "text/x-vala"
              "text/x-fortran"
              "text/x-pascal"
              "text/x-adasrc"
              "text/x-common-lisp"
              "text/x-scheme"
              "text/x-emacs-lisp"
              "text/tcl"
              "text/julia"
              "text/x-verilog"
              "text/x-vhdl"
              "text/x-qml"
              "application/vnd.dart"
              "application/x-gdscript"
              "application/vnd.coffeescript"
              "text/css"
              "text/x-scss"
              "text/x-sass"
              "text/x-makefile"
              "text/x-cmake"
              "text/x-meson"
              "text/x-rpm-spec"
              "text/x-patch"
              "text/x-gettext-translation"
              "text/x-gettext-translation-template"
              "text/x-devicetree-source"
              "text/x-iptables"
              "text/vnd.graphviz"
              "text/x-readme"
              "text/x-changelog"
              "text/x-copying"
              "text/x-authors"
              "text/x-credits"
              "text/x-install"
              "text/x-todo-txt"
              "text/x-log"
            ];
          in
          {
            programs.home-manager.enable = true;
            home.username = username;
            home.stateVersion = version;
            home.homeDirectory = "/home/${username}";
            home.file."Pictures/Wallpapers".source = ../../../../wallpapers;
            home.packages =
              (with pkgs-unstable; [
                telegram-desktop
              ])
              ++ (with pkgs; [
                alacritty
                cmatrix
                keypunch
                nautilus
                networkmanagerapplet
                pfetch
                pinta
                spotify
              ]);

            xdg.configFile."gopass/config".text = ''
              [mounts]
                  path = /home/${username}/.password-store
            '';
            xdg.configFile."gopass/gopass_wrapper.sh" = {
              executable = true;
              text = # bash
                ''
                  #!/bin/sh

                  export PATH="$PATH:$HOME/.nix-profile/bin" # required for Nix
                  export GPG_TTY="$(tty)"

                  # Uncomment to debug gopass-jsonapi
                  # export GOPASS_DEBUG_LOG=/tmp/gopass-jsonapi.log

                  if [ -f ~/.gpg-agent-info ] && [ -n "$(pgrep gpg-agent)" ]; then
                  	source ~/.gpg-agent-info
                  	export GPG_AGENT_INFO
                  else
                  	eval $(gpg-agent --daemon)
                  fi

                  export PATH="$PATH:/usr/local/bin"

                  ${lib.getExe pkgs.gopass-jsonapi} listen

                  exit $?
                '';
            };

            xdg.desktopEntries = {
              yazi = {
                name = "Yazi";
                genericName = "File Manager";
                comment = "Blazing fast terminal file manager";
                exec = "${lib.getExe yaziOpen} %f";
                icon = "yazi";
                categories = [
                  "System"
                  "FileTools"
                  "FileManager"
                ];
                mimeType = yaziMimeTypes;
                settings.Keywords = "File;Manager;Explorer;Browser;";
              };

              nvim = {
                name = "Neovim";
                genericName = "Text Editor";
                comment = "Edit text files";
                exec = "${lib.getExe config.programs.nvf.finalPackage} %F";
                icon = "nvim";
                terminal = true;
                startupNotify = false;
                categories = [
                  "Utility"
                  "TextEditor"
                  "Development"
                ];
                mimeType = nvimMimeTypes;
                settings.Keywords = "Text;editor;";
              };
            };

            systemd.user.services.yazi-filemanager1 = {
              Unit = {
                Description = "FileManager1 D-Bus service backed by yazi";
                PartOf = [ "graphical-session.target" ];
                After = [ "graphical-session.target" ];
              };
              Service = {
                Type = "simple";
                ExecStart = lib.getExe yaziFileManager1;
                Restart = "on-failure";
                RestartSec = 2;
              };
              Install.WantedBy = [ "graphical-session.target" ];
            };

            xdg.mimeApps = {
              enable = true;
              defaultApplications = {
                "text/html" = "zen-beta.desktop";
                "x-scheme-handler/http" = "zen-beta.desktop";
                "x-scheme-handler/https" = "zen-beta.desktop";
                "x-scheme-handler/about" = "zen-beta.desktop";
                "x-scheme-handler/unknown" = "zen-beta.desktop";
              }
              // lib.genAttrs yaziMimeTypes (_: [ "yazi.desktop" ])
              // lib.genAttrs nvimMimeTypes (_: [ "nvim.desktop" ]);
            };

            xdg.userDirs = {
              enable = true;
              createDirectories = true;
              desktop = "${config.home.homeDirectory}/Desktop";
              documents = "${config.home.homeDirectory}/Documents";
              download = "${config.home.homeDirectory}/Downloads";
              music = "${config.home.homeDirectory}/Music";
              pictures = "${config.home.homeDirectory}/Pictures";
              publicShare = "${config.home.homeDirectory}/Public";
              templates = "${config.home.homeDirectory}/Templates";
              videos = "${config.home.homeDirectory}/Videos";
            };

            dconf = {
              enable = true;
              settings = {
                "org/gnome/desktop/interface" = {
                  color-scheme = "prefer-dark";
                  gtk-enable-primary-paste = false;
                };
                "org/virt-manager/virt-manager/connections" = {
                  autoconnect = [ "qemu:///system" ];
                  uris = [ "qemu:///system" ];
                };
                "org/gnome/nautilus/preferences" = {
                  fts-enabled = false;
                };
              };
            };

            gtk = {
              enable = true;
              gtk2.theme = {
                package = pkgs.adw-gtk3;
                name = "adw-gtk3-dark";
              };
              gtk3.theme = {
                package = pkgs.adw-gtk3;
                name = "adw-gtk3-dark";
              };
              gtk4.extraConfig = {
                gtk-theme-name = "adw-gtk3-dark";
              };
              colorScheme = "dark";
              iconTheme = {
                name = "Papirus-Dark";
                package = pkgs.papirus-icon-theme;
              };
            };

            qt = rec {
              enable = true;
              style.name = "Adwaita-Dark";
              qt5ctSettings = {
                Appearance = {
                  style = "Adwaita-Dark";
                  icon_theme = "Papirus-Dark";
                  standard_dialogs = "default";
                };
                Fonts = {
                  fixed = "\"JetBrainsMono NF, 10\"";
                  general = "\"Inter, 10\"";
                };
              };
              qt6ctSettings = qt5ctSettings;
            };

            programs.gpg.enable = true;
            services.gpg-agent = {
              enable = true;
              enableZshIntegration = true;
              enableBashIntegration = true;
              enableSshSupport = true;
              pinentry.package = pkgs.pinentry-gnome3;
              extraConfig = ''
                pinentry-timeout 10
              '';
            };

            programs.obs-studio = {
              enable = true;
              plugins = with pkgs.obs-studio-plugins; [
                wlrobs
                obs-backgroundremoval
                obs-pipewire-audio-capture
              ];
            };

            programs.mpv = {
              enable = true;
              package = pkgs.mpv.override {
                scripts = with pkgs.mpvScripts; [
                  uosc
                  sponsorblock
                ];
              };
              config = {
                profile = "high-quality";
                ytdl-format = "bestvideo+bestaudio";
                cache-default = 4000000;
              };
            };

            programs.vscode = {
              enable = true;
              profiles.default.extensions = with pkgs.vscode-extensions; [
                drblury.protobuf-vsc
                jnoortheen.nix-ide
                k--kato.intellij-idea-keybindings
                mhutchie.git-graph
                ms-azuretools.vscode-containers
                ms-azuretools.vscode-docker
                ms-python.python
                ms-vscode-remote.remote-ssh
                ms-vscode.makefile-tools
                vscodevim.vim
                yzhang.markdown-all-in-one
              ];
            };

            imports = [
              inputs.noctalia.homeModules.default
              inputs.nvf.homeManagerModules.default
              inputs.zen-browser.homeModules.beta
              homeModules.aiUsagebar
              homeModules.chromium
              homeModules.claude
              homeModules.development
              homeModules.git
              homeModules.herdr
              homeModules.jetbrains
              homeModules.kitty
              homeModules.llamaCpp
              homeModules.neovim
              homeModules.niri
              homeModules.noctalia
              homeModules.obsidian
              homeModules.opencode
              homeModules.pi
              homeModules.rofi
              homeModules.sops
              homeModules.thunderbird
              homeModules.tools
              homeModules.zed
              homeModules.zenBrowser
            ];
          };
      };

      xdg.portal = {
        enable = true;
        config = {
          #common.default = "*";
          common = {
            default = [
              "gnome"
              "gtk"
            ];
            "org.freedesktop.impl.portal.ScreenCast" = "gnome";
            "org.freedesktop.impl.portal.Screenshot" = "gnome";
            "org.freedesktop.impl.portal.RemoteDesktop" = "gnome";
            # Camera access dialog must go to gtk — gnome backend requires GNOME shell
            # (unavailable in niri), causing silent denial without dialog
            "org.freedesktop.impl.portal.Access" = "gtk";
            # yazi вместо GTK-диалога выбора файлов (см. tools.nix)
            "org.freedesktop.impl.portal.FileChooser" = "termfilechooser";
          };
        };
        xdgOpenUsePortal = true;
        extraPortals = with pkgs; [
          xdg-desktop-portal
          xdg-desktop-portal-gtk
          xdg-desktop-portal-gnome
          xdg-desktop-portal-termfilechooser
        ];
      };

      networking.hostName = hostname;
      # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

      # Configure network proxy if necessary
      # networking.proxy.default = "http://user:password@proxy:port/";
      # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

      # Enable networking
      networking.networkmanager = {
        enable = true;
        wifi.powersave = true;
      };

      # Set your time zone.
      time.timeZone = "Asia/Novosibirsk";
      # services.automatic-timezoned.enable = true;

      # Select internationalisation properties.
      i18n.defaultLocale = "ru_RU.UTF-8";

      i18n.extraLocaleSettings = {
        LC_ADDRESS = "ru_RU.UTF-8";
        LC_IDENTIFICATION = "ru_RU.UTF-8";
        LC_MEASUREMENT = "ru_RU.UTF-8";
        LC_MONETARY = "ru_RU.UTF-8";
        LC_NAME = "ru_RU.UTF-8";
        LC_NUMERIC = "ru_RU.UTF-8";
        LC_PAPER = "ru_RU.UTF-8";
        LC_TELEPHONE = "ru_RU.UTF-8";
        LC_TIME = "ru_RU.UTF-8";
      };

      # Enable the Ly Display Manager.
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

      # LLama CPP
      systemd.services.llama-cpp = {
        environment = {
          XDG_CACHE_HOME = "/var/cache/llama-cpp";
          MESA_SHADER_CACHE_DIR = "/var/cache/llama-cpp";
        };
      };

      # Enable CUPS to print documents.
      services.avahi = {
        enable = true;
        nssmdns4 = true;
        openFirewall = true;
      };
      services.printing = {
        enable = true;
        drivers = with pkgs; [
          cups-filters
          cups-browsed
        ];
      };

      # Fingerprint reader (Goodix, XPS 13 Plus 9320)
      services.fprintd.enable = true;

      # fprintd is D-Bus activated by default and may start "late" on first use.
      # Pre-start it to reduce races and make fingerprint prompts predictable.
      systemd.services.fprintd = {
        wantedBy = [ "multi-user.target" ];
        after = [ "dbus.socket" ];
        wants = [ "dbus.socket" ];
      };
      systemd.services.display-manager.wants = [ "fprintd.service" ];
      systemd.services.display-manager.after = [ "fprintd.service" ];

      # NOTE: `ly` shows only a password form, but PAM modules like pam_fprintd may
      # still run and block. To allow both "password OR fingerprint" without long
      # blocking, we override PAM stacks for ly and noctalia with short
      # pam_fprintd timeouts.
      security.pam.services.ly.fprintAuth = false;
      security.pam.services.ly.text = ''
        # Account management.
        account required ${pkgs.pam}/lib/security/pam_unix.so

        # Authentication management.
        auth [success=done default=ignore] ${pkgs.fprintd}/lib/security/pam_fprintd.so max_tries=1 timeout=3
        auth optional ${pkgs.pam}/lib/security/pam_unix.so likeauth
        auth optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so
        auth sufficient ${pkgs.pam}/lib/security/pam_unix.so likeauth try_first_pass
        auth required ${pkgs.pam}/lib/security/pam_deny.so

        # Password management.
        password sufficient ${pkgs.pam}/lib/security/pam_unix.so nullok yescrypt
        password optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so use_authtok

        # Session management.
        session required ${pkgs.pam}/lib/security/pam_env.so conffile=/etc/pam/environment readenv=0
        session required ${pkgs.pam}/lib/security/pam_unix.so
        session required ${pkgs.pam}/lib/security/pam_loginuid.so
        session optional ${pkgs.systemd}/lib/security/pam_systemd.so
        session required ${pkgs.pam}/lib/security/pam_limits.so
        session optional ${pkgs.gnome-keyring}/lib/security/pam_gnome_keyring.so auto_start
      '';

      security.pam.services.noctalia.fprintAuth = false;
      security.pam.services.noctalia.text = ''
        # Account management.
        account required ${pkgs.pam}/lib/security/pam_unix.so

        # Authentication management.
        auth [success=done default=ignore] ${pkgs.fprintd}/lib/security/pam_fprintd.so max_tries=1 timeout=3
        auth sufficient ${pkgs.pam}/lib/security/pam_unix.so likeauth try_first_pass
        auth required ${pkgs.pam}/lib/security/pam_deny.so

        # Password management.
        password sufficient ${pkgs.pam}/lib/security/pam_unix.so nullok yescrypt

        # Session management.
        session required ${pkgs.pam}/lib/security/pam_env.so conffile=/etc/pam/environment readenv=0
        session required ${pkgs.pam}/lib/security/pam_unix.so
        session required ${pkgs.pam}/lib/security/pam_limits.so
      '';

      # Allow fingerprint for sudo + polkit prompts (via PAM).
      # Use explicit PAM stacks to keep behavior consistent on cold start.
      security.pam.services.sudo.fprintAuth = false;
      security.pam.services.sudo.text = ''
        # Account management.
        account required ${pkgs.pam}/lib/security/pam_unix.so

        # Authentication management.
        auth [success=done default=ignore] ${pkgs.fprintd}/lib/security/pam_fprintd.so max_tries=1 timeout=15
        auth sufficient ${pkgs.pam}/lib/security/pam_unix.so likeauth try_first_pass
        auth required ${pkgs.pam}/lib/security/pam_deny.so

        # Password management.
        password sufficient ${pkgs.pam}/lib/security/pam_unix.so nullok yescrypt

        # Session management.
        session required ${pkgs.pam}/lib/security/pam_env.so conffile=/etc/pam/environment readenv=0
        session required ${pkgs.pam}/lib/security/pam_unix.so
        session required ${pkgs.pam}/lib/security/pam_limits.so
      '';

      security.pam.services.polkit-1.fprintAuth = true;

      services.logind.settings.Login = {
        HandlePowerKey = "suspend-then-hibernate";
        HandlePowerKeyLongPress = "poweroff";
        HandleLidSwitch = "hibernate";
        HandleLidSwitchExternalPower = "hibernate";
      };

      # Enable sound with pipewire.
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
        wireplumber.extraConfig = {
          # Disable V4L2 monitor — use only libcamera for IPU6 webcam
          "monitor.v4l2" = {
            "monitor.v4l2.disable" = true;
          };
        };
      };

      # Thunderbolt and color management
      services.hardware.bolt.enable = true;
      services.colord.enable = true;
      # Cron: отключён. Пример добавления задачи:
      # services.cron = {
      #   enable = true;
      #   systemCronJobs = [
      #     "0 2 * * * root /path/to/backup.sh  # каждую ночь в 2:00"
      #   ];
      # };

      # For global user
      users.defaultUserShell = pkgs.zsh;
      programs = {
        localsend.enable = true;
        nm-applet.enable = true;
        partition-manager.enable = true;
        virt-manager.enable = true;
        zsh.enable = true;
      };

      # Define a user account. Don’t forget to set a password with ‘passwd’.
      users.users.${username} = {
        isNormalUser = true;
        initialHashedPassword = # mkpasswd <password>
          "$y$j9T$u06AsIj.fZtLVi2I0teH9.$IRF6NKQyvVgQKtr7r6PPAHO3CPnvp/nPHxVj.SBgBK4";
        description = username;
        openssh.authorizedKeys.keyFiles = [
          # after add new ssh key on github:
          # nix store prefetch-file --hash-type sha256 https://github.com/Raimguzhinov.keys
          (builtins.fetchurl {
            url = "https://github.com/Raimguzhinov.keys";
            sha256 = "sha256-E28I38AJMh0nynp6FCPf1WhOInZHHIe6D5GyBDyjMvA=";
          })
        ];
        extraGroups = [
          "nixosvmtest"
          "networkmanager"
          "wheel"
          "docker"
          "wireshark"
          "libvirtd"
          "kvm"
          "camera"
          "video"
        ];
        shell = pkgs.zsh;
      };

      # Yubikey
      services.udev.packages = [
        pkgs.yubikey-personalization
        # Entropy проверяет именно этот файл и маркеры внутри (v2)
        (pkgs.writeTextFile {
          name = "vial-udev-rules";
          destination = "/etc/udev/rules.d/59-vial.rules";
          text = ''
            # Entropy Vial hidraw access v2
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", KERNELS=="0005:E126:*", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
          '';
        })
      ];
      services.pcscd.enable = true;
      services.yubikey-agent.enable = true;
      hardware.gpgSmartcards.enable = true;

      # Polkit agent
      security.polkit.enable = true;
      systemd.user.services.niri-flake-polkit.enable = false;
      security.soteria.enable = true;

      # Sudo
      security.sudo = {
        extraConfig = ''
          Defaults env_keep += "PATH"
        '';
        extraRules = [
          {
            users = [ username ];
            commands = [
              {
                command = "${pkgs.systemd}/bin/systemctl start camera-bridge.service";
                options = [ "NOPASSWD" ];
              }
              {
                command = "${pkgs.systemd}/bin/systemctl stop camera-bridge.service";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];
      };

      # Fonts
      fonts = {
        fontconfig.enable = true;
        fontDir.enable = true;
        packages = with pkgs; [
          inter-nerdfont
          nerd-fonts.fira-code
          nerd-fonts.jetbrains-mono
          nerd-fonts.roboto-mono
          nerd-fonts.ubuntu-sans
          nerd-fonts.zed-mono
        ];
      };

      # Appimage
      programs.appimage = {
        enable = true;
        binfmt = true;
      };

      # Some programs need SUID wrappers, can be configured further or are
      # started in user sessions.
      programs.mtr.enable = true;

      # Password store
      services.gnome.gnome-keyring.enable = true;

      # VPN
      networking.networkmanager.plugins = with pkgs; [
        networkmanager-openvpn
        networkmanager-sstp
      ];
      programs.amnezia-vpn = {
        enable = true;
        package = pkgs-unstable.amnezia-vpn;
      };
      # services.v2raya.enable = true;
      programs.clash-verge = {
        enable = true;
        tunMode = true;
        serviceMode = true;
        autoStart = false;
      };

      # Bluetooth
      hardware.bluetooth.enable = true; # enables support for Bluetooth
      hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
      services.blueman.enable = true;

      # Power
      services.tuned.enable = true;
      services.upower.enable = true;
      services.fwupd.enable = true;

      services.fstrim.enable = true; # SSD TRIM (weekly)

      # Enable the OpenSSH daemon.
      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          PermitRootLogin = "no";
        };
      };
      programs.ssh.extraConfig = ''
        Host *
            SetEnv TERM=xterm-256color
            RequestTTY auto
            ServerAliveInterval 60
      '';

      # Nautilus
      services.gvfs.enable = true;
      environment.pathsToLink = [ "share/thumbnailers" ];
      services.gnome.sushi.enable = true;
      programs.nautilus-open-any-terminal = {
        enable = true;
        terminal = "kitty";
      };

      # Wireshark
      programs.wireshark = {
        enable = true;
        package = pkgs.wireshark;
      };

      # pppd (sstp-client) needs /etc/ppp to write resolv.conf
      systemd.tmpfiles.rules = [ "d /etc/ppp 0755 root root -" ];

      # Logging
      services.logrotate = {
        enable = true;
        configFile = pkgs.writeText "logrotate.conf" ''
          /tmp/niri-float-sticky.log {
              daily
              rotate 5
              compress
              missingok
              notifempty
              copytruncate
              maxsize 10M
              su root root
          }
        '';
      };

      # Virtualisation
      virtualisation = {
        docker = {
          enable = true;
          daemon.settings = {
            builder.gc = {
              enabled = true;
              defaultKeepStorage = "20GB";
            };
          };
        };
        libvirtd = {
          enable = true;
          qemu = {
            package = pkgs.qemu_kvm;
            runAsRoot = true;
            swtpm.enable = true;
            vhostUserPackages = with pkgs; [ virtiofsd ];
          };
          # SPICE display
          # virsh edit {vmname}
          /*
            <graphics type='spice' port='5900' autoport='no' listen='0.0.0.0' defaultMode='insecure'>
              <listen type='address' address='0.0.0.0'/>
              <image compression='auto_lz'/>
            </graphics>
          */
        };
        spiceUSBRedirection.enable = true;
        # sudo nixos-rebuild build-vm-with-bootloader --flake ~/dotfiles/nixos
        # ~/result/bin/run-*-vm -device virtio-vga
        vmVariantWithBootLoader = {
          virtualisation = {
            memorySize = 8192; # Use 8GiB memory.
            cores = 4;
            qemu.options = [
              "-device virtio-vga-gl"
              "-display gtk,gl=on"
            ];
          };
        };
      };
      systemd.services.libvirtd.postStart = ''
        ${pkgs.libvirt}/bin/virsh net-autostart default
        ${pkgs.libvirt}/bin/virsh net-start default || true
      '';
      users.groups.libvirtd.members = [ username ];
      # services.qemuGuest.enable = true;
      services.spice-vdagentd.enable = true;
      services.spice-autorandr.enable = true;

      # Open ports in the firewall.
      networking.firewall.allowedTCPPorts = [
        8081
        8082
        8083
      ];
      # networking.firewall.allowedUDPPorts = [ ... ];
      # Or disable the firewall altogether.
      # networking.firewall.enable = false;

      # Allow libvirt VM (virbr0) forwarding past docker's FORWARD DROP policy.
      networking.nat = {
        enable = true;
        internalInterfaces = [ "virbr0" ];
      };

      # This value determines the NixOS release from which the default
      # settings for stateful data, like file locations and database versions
      # on your system were taken. It’s perfectly fine and recommended to leave
      # this value at the release version of the first install of this system.
      # Before changing this value read the documentation for this option
      # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
      system.stateVersion = version; # Did you read the comment?

      # List packages installed in system profile. To search, run:
      # $ nix search wget
      environment.systemPackages =
        (with inputs; [
          niri-float-sticky.packages.${pkgs.stdenv.hostPlatform.system}.default
        ])
        ++ (with pkgs-unstable; [
          ergohaven-entropy
          handy
        ])
        ++ (with pkgs.gst_all_1; [
          gst-libav
          gst-plugins-bad
          gst-plugins-base
          gst-plugins-good
          gst-plugins-ugly
          gst-vaapi
          gstreamer
        ])
        ++ (with pkgs; [
          adw-gtk3
          adwaita-icon-theme
          adwaita-qt6
          alsa-utils
          brightnessctl
          bruno # lightweight insomnia
          censor # PDF document redaction
          chafa # terminal image viewer
          choose # cut → choose
          cliphist
          codex
          ddgr
          docker-buildx
          docker-compose
          docker-init
          dysk # df → dysk
          fastfetch
          ffmpeg
          file-roller
          firefoxpwa
          gcc
          gdlv
          gdu # du -> ncdu/dust -> gdu
          gh
          gitlab-ci-local
          glab
          glow
          gnome-settings-daemon
          gnumake
          gnupg
          gopass
          gopass-jsonapi
          gpu-screen-recorder
          gtk-layer-shell
          gtk3
          hicolor-icon-theme
          htop-vim
          imagemagick
          jq
          kdePackages.kpat
          kdePackages.qt6ct
          lazydocker
          lazyssh
          libcamera
          libheif
          libnotify
          libpng
          libsForQt5.qt5.qtwayland # for Qt apps
          libwebp
          loupe # image viewer
          lsof
          nettools
          nix-ld
          nixfmt
          nurl # nix fetcher
          nwg-drawer
          onlyoffice-desktopeditors
          papers
          papirus-icon-theme
          pdfchain # pdftk GUI
          popsicle # USB flasher
          postgresql
          procs # ps → procs
          psmisc
          python3
          qrencode
          scrcpy # android screen mirroring
          sops
          sshfs
          tessen
          tig
          tlrc
          transmission_4-gtk
          tuir
          unzip
          uv
          v4l-utils
          vulkan-loader
          wget
          wl-clipboard
          wl-color-picker
          wtype
          xdg-desktop-portal-gnome
          xdg-desktop-portal-gtk
          xh # curl/httpie → xh
          xwayland-satellite
          yq-go
          yubikey-manager
          yubikey-personalization
          yubioath-flutter
          zip
        ]);
    };
}
