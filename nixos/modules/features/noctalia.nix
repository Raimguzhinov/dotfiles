{ ... }:
{
  flake.homeModules.noctalia =
    { config, pkgs, ... }:
    {
      programs.noctalia = {
        enable = true;
        settings = {
          # --- Shell ---
          shell = {
            font_family = "Inter Nerd Font Display";
            ui_scale = 1.0;
            corner_radius_scale = 0.2;
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
          };

          shell.animation = {
            enabled = true;
            speed = 1.5;
          };

          # --- Bar: right, compact ---
          bar = {
            order = [ "main" ];
          };

          bar.main = {
            position = "right";
            thickness = 28;
            background_opacity = 1.0;
            border_width = 0.0;
            shadow = true;
            panel_overlap = 1;
            radius = 12;
            margin_edge = 10;
            padding = 10;
            widget_spacing = 4;
            scale = 0.9;
            font_weight = "regular";
            capsule = false;
            reserve_space = true;

            start = [ "launcher" "wallpaper" "workspaces" ];
            center = [ "clock" ];
            end = [
              "media"
              "tray"
              "notifications"
              "clipboard"
              "network"
              "bluetooth"
              "volume"
              "brightness"
              "battery"
              "control-center"
              "session"
            ];
          };

          # --- Widgets ---
          widget.clock = {
            format = "{:%H:%M}";
            vertical_format = "{:%H\n%M}";
            font_weight = 700;
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
            pinned = [
              "AmneziaVPN"
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

          # --- Control Center ---
          control_center = {
            sidebar = "compact";
          };

          control_center.shortcuts = [
            { type = "wifi"; }
            { type = "bluetooth"; }
            { type = "wallpaper"; }
            { type = "nightlight"; }
            { type = "notification"; }
            { type = "dark_mode"; }
            { type = "power_profile"; }
            { type = "caffeine"; }
            { type = "screen_recorder"; }
          ];

          # --- Theme / ColorSchemes ---
          theme = {
            mode = "dark";
            source = "builtin";
            builtin = "Rosé Pine";
          };

          # --- Wallpaper ---
          wallpaper = {
            enabled = true;
            directory = "${config.home.homeDirectory}/dotfiles/wallpapers";
            fill_mode = "crop";
          };

          wallpaper.automation = {
            enabled = false;
          };

          # --- Notifications ---
          notification = {
            enable_daemon = true;
            position = "top_right";
            show_app_name = true;
            show_actions = true;
          };

          # --- Audio ---
          audio = {
            enable_overdrive = true;
            enable_sounds = false;
          };

          # --- Dock ---
          dock = {
            enabled = false;
          };

          # --- App Launcher ---
          shell.panel = {
            launcher_compact = false;
            launcher_categories = true;
            launcher_placement = "centered";
          };

          # --- Lock Screen ---
          lockscreen = {
            blurred_desktop = false;
          };

          # --- Location ---
          location = {
            auto_locate = false;
            address = "Novosibirsk, Russia";
          };

          # --- OSD ---
          osd = {
            position = "top_center";
            orientation = "horizontal";
          };

          osd.kinds = {
            volume = true;
            brightness = true;
            wifi = true;
            bluetooth = true;
            power_profile = true;
            caffeine = true;
            notification = true;
            keyboard_layout = true;
          };
        };
      };
    };
}
