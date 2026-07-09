{ ... }:
{
  flake.homeModules.noctalia =
    { config, pkgs, ... }:
    {
      programs.noctalia = {
        enable = true;
        settings = {
          dock.enabled = false;
          backdrop.enabled = true;

          shell = {
            font_family = "Inter Nerd Font Display";
            ui_scale = 1.0;
            time_format = "{:%H:%M}";
            date_format = "%A, %x";
            offline_mode = false;
            telemetry_enabled = false;
            show_location = true;
            clipboard_enabled = true;
            clipboard_auto_paste = "auto";
            clipboard_history_max_entries = 50;
            avatar_path = "${config.home.homeDirectory}/.face";
            lang = "ru";
            polkit_agent = false;
            settings_show_advanced = false;
            password_style = "default";
            animation = {
              enabled = true;
              speed = 1.5;
            };
          };

          bar = {
            order = [ "main" ];
            main = {
              position = "right";
              thickness = 35;
              background_opacity = 1.0;
              border_width = 0.0;
              shadow = false;
              panel_overlap = 1;
              radius = 0;
              margin_ends = 0;
              margin_edge = 0;
              padding = 6;
              widget_spacing = 8;
              scale = 1.0;
              font_weight = "regular";
              capsule = true;
              capsule_fill = "surface_variant";
              capsule_radius = 6.0;
              capsule_opacity = 0.85;
              reserve_space = true;
              start = [
                "control-center"
                "launcher"
                "volume"
                "network"
                "bluetooth"
              ];
              center = [
                "workspaces"
                "active_window"
              ];
              end = [
                "screen_recorder"
                "keyboard_layout"
                "battery"
                "clock"
                "tray"
                "session"
              ];
            };
          };

          widget.clock = {
            format = "{:%H:%M}";
            vertical_format = "{:%H\n%M}";
            scale = 1.0;
          };

          widget.workspaces = {
            display = "id";
            minimal = false;
            max_label_chars = 1;
            focused_color = "primary";
            occupied_color = "secondary";
            empty_color = "secondary";
          };

          widget.tray = {
            drawer = true;
            pinned = [
              "AmneziaVPN"
              "Clash-verge"
              "Handy"
              "MAX"
              "OBS Studio"
              "Telegram Desktop"
              "spotify-client"
            ];
          };

          widget.volume = {
            device = "output";
            scroll_step = 5;
            show_label = true;
          };

          control_center = {
            sidebar = "compact";
          };

          theme = {
            mode = "dark";
            source = "builtin";
            builtin = "Rosé Pine";
          };

          wallpaper = {
            enabled = true;
            directory = "${config.home.homeDirectory}/dotfiles/wallpapers";
            default = {
              path = "${config.home.homeDirectory}/dotfiles/wallpapers/nixos.png";
            };
          };

          notification = {
            enable_daemon = true;
            position = "top_right";
            show_app_name = true;
            show_actions = false;
            layer = "overlay";
            scale = 0.95;
          };

          audio = {
            enable_overdrive = true;
            enable_sounds = true;
          };

          shell.panel = {
            open_near_click_control_center = true;
            launcher_compact = false;
            launcher_categories = true;
            launcher_placement = "centered";
            session_placement = "centered";
          };

          lockscreen = {
            blurred_desktop = false;
          };

          location = {
            auto_locate = false;
            address = "Novosibirsk, Russia";
          };

          osd = {
            position = "top_right";
            orientation = "horizontal";
          };

          osd.kinds = {
            volume = true;
            brightness = true;
            wifi = true;
            bluetooth = true;
            power_profile = true;
            caffeine = true;
            dnd = true;
            lock_keys = true;
            keyboard_layout = false;
          };
        };
      };
    };
}
