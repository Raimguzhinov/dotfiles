# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  inputs,
  hostname,
  username,
  version,
  ...
}:
{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

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

  # Flakes
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
    substituters = [
      "https://cache.nixos.org"
      "https://niri.cachix.org"
      "https://notashelf.cachix.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "notashelf.cachix.org-1:VTTBFNQWbfyLuRzgm2I7AWSDJdqAa11ytLXHBhrprZk="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # Garbage collector
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nix.registry.nixpkgs.flake = inputs.nixpkgs;
  nix.nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];

  # Niri
  niri-flake.cache.enable = true;
  programs.niri.enable = true;
  hardware.graphics.enable = true;
  services.dbus.enable = true;

  # Home Manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    sharedModules = [ inputs.sops-nix.homeManagerModules.sops ];
    extraSpecialArgs = {
      inherit pkgs-unstable;
      inherit username;
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
          ./neovim.nix
          ./tools.nix
        ];
      };
    users.${username} =
      { config, lib, ... }:
      {
        programs.home-manager.enable = true;
        home.username = username;
        home.stateVersion = version;
        home.homeDirectory = "/home/${username}";
        home.file."Pictures/Wallpapers".source = ../wallpapers;
        home.packages =
          (with pkgs-unstable; [
            telegram-desktop
          ])
          ++ (with pkgs; [
            alacritty
            amnezia-vpn
            cmatrix
            keypunch
            nautilus
            networkmanagerapplet
            obsidian
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
          text = ''
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

            ${pkgs.gopass-jsonapi}/bin/gopass-jsonapi listen

            exit $?
          '';
        };

        xdg.mimeApps = {
          enable = true;
          defaultApplications = {
            "text/html" = "zen-beta.desktop";
            "x-scheme-handler/http" = "zen-beta.desktop";
            "x-scheme-handler/https" = "zen-beta.desktop";
            "x-scheme-handler/about" = "zen-beta.desktop";
            "x-scheme-handler/unknown" = "zen-beta.desktop";
          };
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
        };

        programs.foot = {
          enable = true;
          server.enable = true;
          settings = {
            main = {
              term = "foot";
              shell = "${pkgs.zsh}/bin/zsh";
              login-shell = "no";
              app-id = "foot";
              title = "Terminal";
              locked-title = "no";
              font = "JetBrainsMono Nerd Font:size=10.5";
              dpi-aware = "no";
              bold-text-in-bright = "yes";
              selection-target = "primary";
            };
            csd.preferred = "none";
            scrollback.lines = 10000;
            key-bindings.clipboard-copy = "Control+c XF86Copy";
            colors = {
              alpha = 1.0;
              foreground = "ffffff";
              background = "181818";
              regular0 = "181818";
              regular1 = "f62b5a";
              regular2 = "47b413";
              regular3 = "e3c401";
              regular4 = "24acd4";
              regular5 = "f2affd";
              regular6 = "13c299";
              regular7 = "e6e6e6";
              bright0 = "616161";
              bright1 = "ff4d51";
              bright2 = "35d450";
              bright3 = "e9e836";
              bright4 = "5dc5f8";
              bright5 = "feabf2";
              bright6 = "24dfc4";
              bright7 = "ffffff";
            };
          };
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
          package = (
            pkgs.mpv-unwrapped.wrapper {
              scripts = with pkgs.mpvScripts; [
                uosc
                sponsorblock
              ];
              mpv = pkgs.mpv-unwrapped.override { waylandSupport = true; };
            }
          );
          config = {
            profile = "high-quality";
            ytdl-format = "bestvideo+bestaudio";
            cache-default = 4000000;
          };
        };

        imports = [
          inputs.noctalia.homeModules.default
          inputs.nvf.homeManagerModules.default
          inputs.zen-browser.homeModules.beta
          ./chromium.nix
          ./sops.nix
          ./development.nix
          ./jetbrains.nix
          ./neovim.nix
          ./niri.nix
          ./noctalia.nix
          ./rofi.nix
          ./tools.nix
          ./zed-editor.nix
          ./zen-browser.nix
          ./claude.nix
          ./thunderbird.nix
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
      };
    };
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
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
    plugins = with pkgs; [
      networkmanager-openvpn
      networkmanager-sstp
    ];
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

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Fingerprint reader (Goodix, XPS 13 Plus 9320)
  services.fprintd.enable = true;

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
    amnezia-vpn.enable = true;
    localsend.enable = true;
    nm-applet.enable = true;
    partition-manager.enable = true;
    virt-manager.enable = true;
    zsh.enable = true;
  };

  # Define a user account. Don’t forget to set a password with ‘passwd’.
  users.users.${username} = {
    isNormalUser = true;
    initialHashedPassword = # mkdpasswd <password>
      "$y$j9T$u06AsIj.fZtLVi2I0teH9.$IRF6NKQyvVgQKtr7r6PPAHO3CPnvp/nPHxVj.SBgBK4";
    description = username;
    openssh.authorizedKeys.keyFiles = [
      # after add new ssh key on github:
      # nix store prefetch-file --hash-type sha256 https://github.com/Raimguzhinov.keys
      (builtins.fetchurl {
        url = "https://github.com/Raimguzhinov.keys";
        sha256 = "sha256-ReZd2hD5+iS0jtrQhDTvuOXMMP1DO45LjFcsZuh2Wp4=";
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
  services.udev.packages = [ pkgs.yubikey-personalization ];
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
    terminal = "foot";
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
      # max-messanger.packages.${pkgs.stdenv.hostPlatform.system}.default TODO: repack from deb-pkg
      lmstudio.packages.${pkgs.stdenv.hostPlatform.system}.lmstudio
      niri-float-sticky.packages.${pkgs.stdenv.hostPlatform.system}.default
      tankionline.packages.${pkgs.stdenv.hostPlatform.system}.default
    ])
    ++ (with pkgs-unstable; [
      censor # PDF document redaction
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
      aichat
      alsa-utils
      brightnessctl
      bruno # lightweight insomnia
      chafa # terminal image viewer
      choose # cut → choose
      cliphist
      docker-buildx
      docker-compose
      docker-init
      dysk # df → dysk
      ffmpeg
      file-roller
      firefoxpwa
      gcc
      gdu # du -> ncdu/dust -> gdu
      gh
      glab
      glow
      gnome-settings-daemon
      gnumake
      gnupg
      gopass
      gopass-jsonapi
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
      nixfmt-rfc-style
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
      sops
      tessen
      thinkfan
      tig
      tlrc
      transmission_4-gtk
      unzip
      v4l-utils
      wget
      wl-clipboard
      wl-color-picker
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
}
