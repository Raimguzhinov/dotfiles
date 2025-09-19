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
          "niri/mode"
          "niri/window"
        ];
        modules-right = [
          "tray"
          "niri/language"
          "clock"
          "wireplumber#sink"
          "battery"
          # "cpu"
          # "memory"
          # "network"
          "idle_inhibitor"
          # "custom/color-picker"
          # "custom/notification"
          # "custom/clipboard"
          # "custom/power"
        ];

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

        "niri/language" = {
          format = "  {}";
          on-click = "niri msg action switch-layout next";
          format-en = "en";
          format-ru = "ru";
          min-length = 5;
          tooltip = false;
        };

        "niri/mode" = {
          format = "<span style=\"italic\">{}</span>";
          tooltip = false;
        };

        "niri/window" = {
          format = "{}";
          max-length = 20;
          tooltip = true;
          rotate = 270;
        };
	
        "idle_inhibitor" = {
          format = "{icon}";
          format-icons = {
            "activated" = "";
            "deactivated" = "";
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
          on-scroll-down = "wpctl set-volume @DEFAULT_SINK@ 1%-";
          on-scroll-up = "wpctl set-volume @DEFAULT_SINK@ 1%+";
        };

        "clock" = {
          tooltip-format = "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>";
          format-alt = "{:%Y-%m-%d}";
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

        "tray" = {
          icon-size = 16;
          spacing = 10;
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
          font-size: 12px;
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
      #custom-playerctl,
      #custom-power,
      #custom-weather,
      #custom-clipboard,
      #custom-menu,
      #battery,
      #cpu,
      #language,
      #memory,
      #network,
      #wireplumber,
      #tray,
      #mode,
      #idle_inhibitor,
      #custom-color-picker,
      #custom-notification {
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

      #custom-weather {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #custom-playerctl {
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

      #custom-gpu-usage {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #network {
          background: @theme_selected_my_bg_color;
          color: @theme_selected_my_fg_color;
      }

      #network.disconnected {
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

      #custom-wf-recorder {
          color: @error_color;
          padding-right: 5px;
      }

      #custom-notification {
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
