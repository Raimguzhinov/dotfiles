{ config, pkgs, ... }:

{
  programs.niri.settings = {
    environment = {
      CLUTTER_BACKEND = "wayland";
      DISPLAY = null;
      GTK_BACKEND = "wayland,x11";
      MOZ_ENABLE_WAYLAND = "1";
      NIXOS_OZONE_WL = "1";
      QT_QPA_PLATFORM = "wayland;xcb";
      QT_WAYLAND_DISABLE_WINDOWDECORATION = "1";
      SDL_VIDEODRIVER = "wayland";
    };
    input = {
      keyboard.xkb = {
        layout = "us,ru";
        options = "grp:alt_space_toggle,grp:ralt_space_toggle";
      };
      # mouse.accel-speed = 1.0;
      touchpad = {
        tap = false;
        dwt = true;
        natural-scroll = true;
        accel-speed = 0.2;
        click-method = "clickfinger";
      };
    };
    prefer-no-csd = true;
    spawn-at-startup = [
      { command = [ "waybar" ]; }
      { command = [ "mako" ]; }
      # { argv = ["swaybg" "--image" "/path/to/wallpaper.jpg"]; }
      # { argv = ["~/.config/niri/scripts/startup.sh"]; }
      # { sh = "echo $NIRI_SOCKET > ~/.niri-socket"; }
    ];
    binds =
      with pkgs.lib;
      let
        binds =
          {
            suffixes,
            prefixes,
            substitutions ? { },
          }:
          let
            replacer = replaceStrings (attrNames substitutions) (attrValues substitutions);
            mapper =
              { prefix, suffix }:
              let
                actual-suffix =
                  if isList suffix.value then
                    {
                      action = head suffix.value;
                      args = tail suffix.value;
                    }
                  else
                    {
                      action = suffix.value;
                      args = [ ];
                    };
                action = replacer "${prefix.value}-${actual-suffix.action}";
              in
              {
                name = "${prefix.name}+${suffix.name}";
                value.action.${action} = actual-suffix.args;
              };
          in
          listToAttrs (
            mapCartesianProduct mapper {
              prefix = attrsToList prefixes;
              suffix = attrsToList suffixes;
            }
          );
      in
      with config.lib.niri.actions;
      mergeAttrsList [
        {
          "Mod+Shift+Slash".action = show-hotkey-overlay;
          "Mod+Return".action = spawn "alacritty";
          "Mod+A".action = spawn "fuzzel";
          # "Mod+L".action = spawn "swaylock";

          XF86AudioRaiseVolume = {
            action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1+";
            allow-when-locked = true;
          };
          XF86AudioLowerVolume = {
            action = spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "0.1-";
            allow-when-locked = true;
          };
          XF86AudioMute = {
            action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle";
            allow-when-locked = true;
          };
          XF86AudioMicMute = {
            action = spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SOURCE@" "toggle";
            allow-when-locked = true;
          };
          "XF86MonBrightnessUp".action = spawn "brightnessctl" "set" "+10%";
          "XF86MonBrightnessDown".action = spawn "brightnessctl" "set" "10%-";
          "Mod+B".action = spawn "rfkill" "toggle" "bluetooth";

          "Mod+Q".action = close-window;

          "Mod+Tab".action = focus-window-down-or-column-right;
          "Mod+Shift+Tab".action = focus-window-up-or-column-left;

          "Mod+Comma".action = consume-window-into-column;
          "Mod+Period".action = expel-window-from-column;

          "Mod+R".action = switch-preset-column-width;
          "Mod+F".action = toggle-window-floating;
          "Mod+Shift+F".action = fullscreen-window;
          "Alt+Return".action = maximize-column;
          "Mod+C".action = center-column;

          "Mod+Minus".action = set-column-width "-10%";
          "Mod+Equal".action = set-column-width "+10%";
          "Mod+Shift+Minus".action = set-window-height "-10%";
          "Mod+Shift+Equal".action = set-window-height "+10%";

          Print.action = screenshot;
          "Ctrl+Print".action.screenshot-screen = [ ];
          "Alt+Print".action = screenshot-window;

          # "Mod+Shift+E".action = quit;
          # "Mod+Shift+P".action = power-off-monitors;
        }
        (binds {
          suffixes.H = "column-left";
          suffixes.L = "column-right";
          prefixes.Mod = "focus";
          prefixes."Mod+Alt" = "move";
          prefixes."Mod+Shift" = "focus-monitor";
          prefixes."Mod+Shift+Alt" = "move-window-to-monitor";
          substitutions."monitor-column" = "monitor";
          substitutions."monitor-window" = "monitor";
        })
        (binds {
          suffixes.J = "down";
          prefixes.Mod = "focus-window-or-workspace";
          prefixes."Mod+Alt" = "move-window-down-or-to-workspace";
          prefixes."Mod+Shift" = "focus-monitor";
          prefixes."Mod+Shift+Alt" = "move-window-to-monitor";
          substitutions."monitor-column" = "monitor";
          substitutions."monitor-window" = "monitor";
        })
        (binds {
          suffixes.K = "up";
          prefixes.Mod = "focus-window-or-workspace";
          prefixes."Mod+Alt" = "move-window-up-or-to-workspace";
          prefixes."Mod+Shift" = "focus-monitor";
          prefixes."Mod+Shift+Alt" = "move-window-to-monitor";
          substitutions."monitor-column" = "monitor";
          substitutions."monitor-window" = "monitor";
        })
        (binds {
          suffixes = builtins.listToAttrs (
            map (n: {
              name = toString n;
              value = [
                "workspace"
                n
              ];
            }) (range 1 9)
          );
          prefixes.Mod = "focus";
          prefixes."Mod+Alt" = "move-window-to";
        })
      ];
  };

  #  environment.systemPackages = with pkgs; [
  #    alacritty
  #    amnezia-vpn
  #    chafa # terminal image viewer
  #    docker-compose
  #    fuzzel
  #    gcc
  #    gdu
  #    git
  #    gnumake
  #    imagemagick
  #    mako
  #    neovim
  #    obs-studio
  #    obsidian
  #    pfetch
  #    swaybg
  #    swayidle
  #    swaylock
  #    telegram-desktop
  #    thinkfan
  #    vim
  #    vk-messenger
  #    waybar
  #    wget
  #    wl-clipboard
  #    xwayland-satellite
  #    wireshark
  #  ];
}
