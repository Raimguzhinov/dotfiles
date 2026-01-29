{ config, pkgs, ... }:

{
  programs.noctalia-shell = {
    enable = true;
    systemd.enable = true;
    settings = {
      bar = {
        density = "compact";
        position = "right";
        showCapsule = false;
        widgets = {
          left = [
            {
              id = "ControlCenter";
              useDistroLogo = true;
            }
            {
              id = "Volume";
            }
            {
              id = "VPN";
            }
            {
              id = "WiFi";
            }
            {
              id = "Bluetooth";
            }
          ];
          center = [
            {
              hideUnoccupied = false;
              id = "Workspace";
              labelMode = "none";
            }
            {
              id = "ActiveWindow";
              showIcon = false;
            }
          ];
          right = [
            {
              id = "KeyboardLayout";
              displayMode = "forceOpen";
            }
            {
              id = "Battery";
              displayMode = "alwaysShow";
              warningThreshold = 30;
              showPowerProfiles = true;
              showNoctaliaPerformance = true;
            }
            {
              formatHorizontal = "HH:mm";
              formatVertical = "HH mm";
              id = "Clock";
              useCustomFont = true;
              customFont = "Inter Nerd Font Display Black";
              usePrimaryColor = true;
            }
            {
              id = "Tray";
              pinned = [
                "AmneziaVPN"
                "Telegram Desktop"
                "MAX"
                "OBS Studio"
              ];
            }
          ];
        };
      };
      ui = {
        fontDefault = "Inter Nerd Font Display";
      };
      colorSchemes.predefinedScheme = "Rose Pine";
      general = {
        avatarImage = "/home/dias/.face";
        radiusRatio = 0.2;
      };
      location = {
        monthBeforeDay = true;
        name = "Novosibirsk, Russia";
      };
      wallpaper = {
        enable = true;
        overviewEnabled = true;
        directory = "/home/dias/dotfiles/wallpapers";
      };
      audio = {
        volumeOverdrive = true;
      };
      notifications = {
        enableKeyboardLayoutToast = false;
        lowUrgencyDuration = 2;
        normalUrgencyDuration = 5;
        criticalUrgencyDuration = 15;
      };
    };
    # this may also be a string or a path to a JSON file.
  };
}
