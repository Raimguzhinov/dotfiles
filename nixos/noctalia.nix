{ config, pkgs, ... }:

{
  programs.noctalia-shell = {
    enable = true;
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
              useMonospacedFont = true;
              usePrimaryColor = true;
            }
            {
              id = "ActiveWindow";
              showIcon = false;
            }
          ];
          center = [
            {
              hideUnoccupied = false;
              id = "Workspace";
              labelMode = "none";
            }
          ];
          right = [
            {
              id = "KeyboardLayout";
              displayMode = "forceOpen";
            }
            {
              id = "Bluetooth";
            }
            {
              id = "WiFi";
            }
            {
              id = "VPN";
            }
            {
              id = "Volume";
            }
            {
              id = "Tray";
              pinned = [
                "AmneziaVPN"
                "Telegram Desktop"
                "MAX"
              ];
            }
          ];
        };
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
      wallpapper = {
        enable = false;
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
