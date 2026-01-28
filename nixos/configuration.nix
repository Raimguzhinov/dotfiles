# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  pkgs,
  niri,
  nvf,
  max-messanger,
  niri-float-sticky,
  zen-browser,
  noctalia,
  home-manager,
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

  # Flakes
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  # Garbage collector
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Niri
  niri-flake.cache.enable = true;
  programs.niri.enable = true;
  # nixpkgs.overlays = [niri.overlays.niri];

  # Home Manager configuration
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
    users.root =
      { config, lib, ... }:
      {
        programs.home-manager.enable = true;
        home.username = "root";
        home.homeDirectory = "/root";
        home.stateVersion = "25.11";
        imports = [
          nvf.homeManagerModules.default
          ./neovim.nix
          ./tools.nix
        ];
      };
    users.dias =
      { config, lib, ... }:
      {
        programs.home-manager.enable = true;
        home.username = "dias";
        home.homeDirectory = "/home/dias";
        home.stateVersion = "25.11";
        home.packages = with pkgs; [
          amnezia-vpn
          nautilus
          networkmanagerapplet
        ];

        dconf = {
          enable = true;
          settings = {
            "org/gnome/desktop/interface" = {
              color-scheme = "prefer-dark";
            };
          };
        };

        gtk = {
          enable = true;
          theme = {
            name = "Adwaita-dark";
            package = pkgs.gnome-themes-extra;
          };
          iconTheme = {
            name = "Papirus-Dark";
            package = pkgs.papirus-icon-theme;
          };
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

        imports = [
          noctalia.homeModules.default
          nvf.homeManagerModules.default
          zen-browser.homeModules.beta
          ./chromium.nix
          ./development.nix
          ./jetbrains.nix
          ./neovim.nix
          ./niri.nix
          ./noctalia.nix
          ./rofi.nix
          ./tools.nix
          ./zed-editor.nix
          ./zen-browser.nix
        ];
      };
  };

  qt = {
    enable = true;
    platformTheme = "qt5ct";
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
      };
    };
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal
      xdg-desktop-portal-gtk
      xdg-desktop-portal-gnome
    ];
  };

  networking.hostName = "raimguzhinov"; # Define your hostname.
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

  services.dbus.enable = true;

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

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };
  services.cron = {
    enable = true;
  };

  # For global user
  users.defaultUserShell = pkgs.zsh;
  programs = {
    zsh.enable = true;
    wireshark.enable = true;
    amnezia-vpn.enable = true;
    thunderbird.enable = true;
    nm-applet.enable = true;
    virt-manager.enable = true;
    localsend.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.dias = {
    isNormalUser = true;
    description = "dias";
    extraGroups = [
      "nixosvmtest"
      "networkmanager"
      "wheel"
      "docker"
      "wireshark"
      "libvirtd"
      "kvm"
      "qemu"
    ];
    shell = pkgs.zsh;
  };

  # Yubikey
  services.udev.packages = [ pkgs.yubikey-personalization ];
  services.pcscd.enable = true;
  services.yubikey-agent.enable = true;

  security.polkit.enable = true; # polkit

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

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
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };
  services.gnome.gnome-keyring.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot
  services.blueman.enable = true;

  # Power
  services.tuned.enable = true;
  services.upower.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
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
    docker.enable = true;
    libvirtd.enable = true;
    libvirtd.qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
    spiceUSBRedirection.enable = true;
    # sudo nixos-rebuild build-vm-with-bootloader --flake ~/dotfiles/nixos
    vmVariantWithBootLoader = {
      virtualisation = {
        memorySize = 8192; # Use 8GiB memory.
        cores = 4;
      };
    };
  };
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  services.spice-autorandr.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "25.11"; # Did you read the comment?

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages =
    with pkgs;
    let
      rr = writeShellScriptBin "rr" ''
        tmp="$(mktemp -t "yazi-cwd.XXXXX")"
        yazi "$@" --cwd-file="$tmp"
        if cwd="$(cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
            builtin cd -- "$cwd"
        fi
        rm -f -- "$tmp"
      '';
    in
    [
      aichat
      alacritty
      alsa-utils
      brightnessctl
      bruno # lightweight insomnia
      chafa # terminal image viewer
      cliphist
      cmatrix
      docker-compose
      file-roller
      firefoxpwa
      fzf
      gcc
      gdu
      gimp2
      git
      gnome-themes-extra
      gnome-settings-daemon
      gnumake
      gnupg
      gopass
      gtk3
      hicolor-icon-theme
      htop
      httpie
      imagemagick
      jq
      krita
      lazygit
      libheif
      libheif.out
      libnotify
      libpng
      libsForQt5.qt5.qtwayland # для Qt приложений
      libwebp
      loupe # image viewer
      max-messanger.packages.${stdenv.hostPlatform.system}.default
      nettools
      niri-float-sticky.packages.${stdenv.hostPlatform.system}.default
      nixfmt-rfc-style
      nurl # nix fetcher
      nwg-drawer
      obsidian
      onlyoffice-desktopeditors
      papers
      papirus-icon-theme
      pfetch
      postgresql
      rr
      showtime
      spotify
      telegram-desktop
      tessen
      thinkfan
      tig
      tlrc
      unzip
      vim
      wget
      wireshark
      wl-clipboard
      wl-color-picker
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      xwayland-satellite
      yubikey-manager
      yubikey-personalization
      yubioath-flutter
      zip
    ];
}
