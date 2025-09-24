{ config, pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    settings = [
      {
        layer = "top";
        position = "right";
        width = 50;

        modules-left = [
          "custom/menu"
          "niri/workspaces"
        ];
        modules-center = [
          "niri/window"
        ];
        modules-right = [
          "tray"
          "niri/language"
          "clock"
          "wireplumber#sink"
          "battery"
          "cpu"
          "memory"
          "idle_inhibitor"
          "custom/color-picker"
          "custom/clipboard"
          "custom/power"
        ];

        "custom/menu" = {
          format = "";
          on-click = "exec nwg-drawer";
          tooltip = false;
        };

        "niri/workspaces" = {
          format = "{icon}";
          format-icons = {
            "active" = "";
            "focused" = "";
            "urgent" = "";
            "default" = "";
          };
          expand = true;
        };

        "niri/window" = {
          format = "{}";
          max-length = 20;
          tooltip = true;
          rotate = 270;
        };

        "tray" = {
          icon-size = 14;
          spacing = 10;
        };

        "niri/language" = {
          format = "  {}";
          on-click = "niri msg action switch-layout next";
          format-en = "en";
          format-ru = "ru";
          min-length = 5;
          tooltip = false;
        };

        "clock" = {
          tooltip = true;
          tooltip-format = "<big>{:%A %H:%M:%S}</big>\n<tt><small>{calendar}</small></tt>";
          interval = 1;
          calendar = {
            mode = "month";
            format = {
              "months" = "<span color='#ff6699'><b>{}</b></span>";
              "days" = "<span color='#cdd6f4'><b>{}</b></span>";
              "weekdays" = "<span color='#7CD37C'><b>{}</b></span>";
              "today" = "<span color='#ffcc66'><b>{}</b></span>";
            };
          };
        };

        "wireplumber#sink" = {
          format = "{icon} {volume}";
          format-muted = "";
          format-icons = [
            ""
            ""
            ""
          ];
          on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          on-scroll-down = "wpctl set-volume @DEFAULT_SINK@ 0.1%-";
          on-scroll-up = "wpctl set-volume @DEFAULT_SINK@ 0.1%+";
        };

        "battery" = {
          format = "{icon} {capacity}";
          format-icons = [
            "󰁻"
            "󰁾"
            "󰁿"
            "󰂁"
            "󰂄"
          ];
        };

        "cpu" = {
          interval = 5;
          format = " {usage}";
          states = {
            "warning" = 70;
            "critical" = 90;
          };
          on-click = "alacritty -e htop";
        };

        "memory" = {
          interval = 30;
          format = " {}";
          states = {
            "warning" = 70;
            "critical" = 90;
          };
          on-click = "alacritty -e htop";
        };

        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
            "activated" = "";
            "deactivated" = "";
          };
        };

        "custom/color-picker" = {
          format = "";
          on-click = "exec wl-color-picker";
          tooltip = false;
        };

        "custom/clipboard" = {
          format = "";
          interval = "once";
          return-type = "json";
          on-click = "swaymsg -q exec '$clipboard'; pkill -RTMIN+9 waybar";
          on-click-right = "swaymsg -q exec '$clipboard-del'; pkill -RTMIN+9 waybar";
          on-click-middle = "rm -f ~/.cache/cliphist/db; pkill -RTMIN+9 waybar";
          exec = "printf '{\"tooltip\":\"%s\"}' $(cliphist list | wc -l)' item(s) in the clipboard\r(Mid click to clear)'";
          exec-if = "[ -x \"$(command -v cliphist)\" ] && [ $(cliphist list | wc -l) -gt 0 ]";
          signal = 9;
        };

        "custom/power" = {
          format = "";
          on-click = "wlogout -p layer-shell";
        };

      }
    ];
    style = ''
      @define-color theme_selected_my_bg_color #2a2f41;
      @define-color theme_selected_my_fg_color #7fc8ff; /* old green version: #73daca */

      @keyframes blink {
          to {
              opacity: 0.6;
          }
      }

      @keyframes blink-warning {
          70% {
              color: @wm_icon_bg;
          }

          to {
              color: @wm_icon_bg;
              background-color: @warning_color;
          }
      }

      @keyframes blink-critical {
          70% {
              color: @wm_icon_bg;
          }

          to {
              color: @wm_icon_bg;
              background-color: @error_color;
          }
      }

      /* Reset all styles */
      * {
          border: none;
          border-radius: 4px;
          min-height: 0;
          margin: 0;
          padding: 0;
      }

      #window {
      	padding: 1px 0;
      }

      /* The whole bar */
      #waybar {
          background-color: #1f1e25;
          font-family: "UbuntuSans Nerd Font", "UbuntuSansMono NF";
          font-size: 14px;
      }

      #window {
          margin-left: 5px;
          margin-bottom: 30px;
      }

      window#waybar {
          margin-left: 10px;
          border-radius: 0;
      }

      window#waybar.solo {
          background-color: #161616;
      }

      window#waybar.hidden {
          opacity: 0.2;
      }

      /* Рабочие столы */
      #workspaces button {
          color: rgba(205, 214, 244, 0.6);
          transition: all 0.2s ease;
          padding: 0 0.5em;
          margin: 4px 2px;
      }
      #workspaces button:hover {
          color: #f5c2e7;
      }

      #workspaces button.active {
          color: @theme_selected_my_fg_color;
      }

      #workspaces button.urgent {
          color: #a6e3a1;
      }

      #mode {
          background: @background_color;
      }

      #clock,
      #custom-power,
      #custom-clipboard,
      #custom-menu,
      #battery,
      #cpu,
      #language,
      #memory,
      #wireplumber,
      #tray,
      #idle_inhibitor,
      #custom-color-picker {
          border-radius: 3px;
          padding-left: 5px;
          min-height: 35px;
          padding-right: 5px;
          margin: 2px 2px;
      }

      #clock {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #custom-power {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #custom-color-picker {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #custom-clipboard {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #custom-menu {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
          margin-bottom: 10px;
      }

      #battery {
          animation-timing-function: linear;
          animation-iteration-count: infinite;
          animation-direction: alternate;
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #battery.warning {
          color: @warning_color;
      }

      #battery.critical {
          color: @error_color;
      }

      #battery.warning.discharging {
          animation-name: blink-warning;
          animation-duration: 3s;
      }

      #battery.critical.discharging {
          animation-name: blink-critical;
          animation-duration: 2s;
      }

      label:focus {
          background-color: #000000;
      }

      #cpu {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #language {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #memory {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #wireplumber {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #wireplumber.muted {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #tray {
          background-color: transparent;
          padding-left: 10px;
          padding-right: 10px;
          margin-bottom: 10px;
      }

      #tray>.passive {
          -gtk-icon-effect: dim;
      }

      #tray>.needs-attention {
          -gtk-icon-effect: highlight;
          color: @red;
          border-bottom-color: @red;
      }

      #idle_inhibitor.activated {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #idle_inhibitor {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }
    '';
  };
}
