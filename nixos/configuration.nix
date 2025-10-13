# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  config,
  lib,
  pkgs,
  niri,
  nvf,
  zen-browser,
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
    options = "--delete-older-than 30d";
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
        home.stateVersion = "25.05";
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
        home.stateVersion = "25.05";
        home.packages = with pkgs; [
          amnezia-vpn
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

        services.mako = {
          enable = true;
          settings = {
            border-radius = 5;
            border-size = 3;
            default-timeout = 4000;
            ignore-timeout = 1;
            icons = 1;
            layer = "overlay";
            sort = "-time";
            "urgency=low" = {
              border-color = lib.mkForce "#cccccc";
            };
            "urgency=normal" = {
              border-color = lib.mkForce "#7fc8ff";
            };
            "urgency=high" = {
              border-color = lib.mkForce "#bf616a";
              default-timeout = 5000;
            };
            "category=mpd" = {
              default-timeout = 2000;
              group-by = "category";
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
          nvf.homeManagerModules.default
          zen-browser.homeModules.beta
          ./zen-browser.nix
          ./neovim.nix
          ./niri.nix
          ./waybar.nix
          ./rofi.nix
          ./jetbrains.nix
          ./development.nix
          ./chromium.nix
          ./tools.nix
        ];
      };
  };

  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
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
  };

  # Set your time zone.
  time.timeZone = "Asia/Novosibirsk";

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

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the GNOME Desktop Environment.
  services.xserver.displayManager.gdm.enable = true;

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

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # For global user
  users.defaultUserShell = pkgs.zsh;
  programs = {
    zsh.enable = true;
    wireshark.enable = true;
    amnezia-vpn.enable = true;
    thunderbird.enable = true;
    nm-applet.enable = true;
    virt-manager.enable = true;
  };

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.dias = {
    isNormalUser = true;
    description = "dias";
    extraGroups = [
      "networkmanager"
      "wheel"
      "docker"
      "wireshark"
    ];
    shell = pkgs.zsh;
  };

  security.polkit.enable = true; # polkit
  security.pam.services.swaylock = { };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    nerd-fonts.fira-code
    nerd-fonts.roboto-mono
    nerd-fonts.jetbrains-mono
    nerd-fonts.zed-mono
    nerd-fonts.ubuntu-sans
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  programs.mtr.enable = true;
  services.pcscd.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    pinentryPackage = pkgs.pinentry-gnome3;
  };

  # List services that you want to enable:
  services.gnome.gnome-keyring.enable = true;

  hardware.bluetooth.enable = true; # enables support for Bluetooth
  hardware.bluetooth.powerOnBoot = true; # powers up the default Bluetooth controller on boot

  services.blueman.enable = true;

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Nautilus
  services.gvfs.enable = true;
  environment.pathsToLink = [ "share/thumbnailers" ];

  virtualisation.docker.enable = true;

  virtualisation.libvirtd.enable = true;
  virtualisation.libvirtd.qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
  virtualisation.spiceUSBRedirection.enable = true;

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
  system.stateVersion = "25.05"; # Did you read the comment?

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
      alacritty
      alsa-utils
      apache-directory-studio
      brightnessctl
      chafa # terminal image viewer
      cliphist
      delve
      docker-compose
      firefoxpwa
      fzf
      gcc
      gdu
      git
      gnome-themes-extra
      gnumake
      gnupg
      gopass
      gtk3
      hicolor-icon-theme
      htop
      imagemagick
      jq
      lazygit
      libheif
      libheif.out
      libnotify
      libsForQt5.qt5.qtwayland # для Qt приложений
      nautilus
      nixfmt-rfc-style
      nurl # nix fetcher
      nwg-drawer
      obsidian
      papirus-icon-theme
      pfetch
      postgresql
      rr
      swaybg
      swayidle
      swaylock
      swww
      telegram-desktop
      tessen
      thinkfan
      unzip
      vim
      wget
      wireshark
      wl-clipboard
      wl-color-picker
      wlogout
      xwayland-satellite
      zip
    ];
}
