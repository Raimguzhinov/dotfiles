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
                "notes"
                "timer"
              ];
              center = [
                "ai_usage"
                "workspaces"
                "active_window"
              ];
              end = [
                "screen_recorder"
                "keyboard_layout"
                "battery"
                "world_clock"
                "clock"
                "tray"
                "session"
              ];
            };
          };

          plugins = {
            enabled = [
              "noctalia/notes"
              "noctalia/screen_recorder"
              "noctalia/timer"
              "noctalia/world_clock"

              "felipeartur/ai-usagebar"
            ];
            auto_update = "all";
            source = [
              {
                name = "official";
                kind = "git";
                location = "https://github.com/noctalia-dev/official-plugins";
                enabled = true;
              }
              {
                name = "community";
                kind = "git";
                location = "https://github.com/noctalia-dev/community-plugins";
                enabled = true;
              }
            ];
          };

          widget.clock = {
            format = "{:%H:%M}";
            vertical_format = "{:%H\n%M}";
            tooltip_format = "{:%A, %d %B %Y}\n{:%H:%M:%S}";
            scale = 1.0;
          };

          widget.workspaces = {
            label_source = "id";
            style = "regular";
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
            show_label = true;
          };

          # Плагины подтягиваются автоматически из plugins.source; в бар
          # подключаются именованными инстансами (type = "author/plugin:entry")
          widget.screen_recorder = {
            type = "noctalia/screen_recorder:recorder";
          };

          plugin_settings."noctalia/screen_recorder" = {
            audio_source = "both";
          };

          widget.notes = {
            type = "noctalia/notes:notes";
          };

          # Бар-виджет плагина рисует ui.row и не влезает в вертикальный бар
          # (35px), поэтому в баре — статичная иконка, а данные в панели плагина.
          widget.ai_usage = {
            type = "custom_button";
            glyph = "brain";
            tooltip = "Использование AI-планов";
            actions = {
              left = "panel-toggle felipeartur/ai-usagebar:panel";
              right = "exec kitty -e ai-usagebar-tui";
            };
          };

          widget.timer = {
            type = "noctalia/timer:bar";
          };

          widget.world_clock = {
            type = "noctalia/world_clock:bar";
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
            launcher_placement = "floating";
            launcher_position = "center";
            session_placement = "floating";
            session_position = "center";
          };

          shell.launcher = {
            categories = true;
            compact = false;
          };

          accessibility = {
            ui_scale = 1.0;
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
