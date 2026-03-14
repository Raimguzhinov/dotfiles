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
              id = "Launcher";
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
              id = "plugin:sticky-notes";
            }
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
            }
            {
              id = "plugin:timer";
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
        directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
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
      dock = {
        enabled = false;
      };
      appLauncher = {
        enableClipboardHistory = true;
        autoPasteClipboard = false;
        enableClipPreview = true;
        clipboardWrapText = true;
        clipboardWatchTextCommand = "wl-paste --type text --watch cliphist store";
        clipboardWatchImageCommand = "wl-paste --type image --watch cliphist store";
        position = "center";
        pinnedApps = [ ];
        useApp2Unit = false;
        sortByMostUsed = true;
        terminalCommand = "alacritty -e";
        customLaunchPrefixEnabled = false;
        customLaunchPrefix = "";
        viewMode = "grid";
        showCategories = true;
        iconMode = "native";
        showIconBackground = false;
        enableSettingsSearch = true;
        enableWindowsSearch = true;
        enableSessionSearch = true;
        ignoreMouseInput = false;
        screenshotAnnotationTool = "";
        overviewLayer = true;
        density = "default";
      };
      plugins = {
        autoUpdate = true;
        sources = [
          {
            enabled = true;
            name = "Official Source";
            url = "https://github.com/noctalia-dev/noctalia-plugins";
          }
        ];
        states = {
          timer = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
          sticky-notes = {
            enabled = true;
            sourceUrl = "https://github.com/noctalia-dev/noctalia-plugins";
          };
        };
        version = 1;
      };
    };
    pluginSettings = {
      timer = {
        defaulltDuration = 0;
        compactMode = true;
        iconColor = "tertiary";
        textColor = "tertiary";
      };
    };
    # this may also be a string or a path to a JSON file.
  };
}
