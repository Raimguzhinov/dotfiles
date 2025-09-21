{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkForce;
  inherit (config.lib.formats.rasi) mkLiteral;
in
{
  programs.rofi = {
    enable = true;
    cycle = false;

    package = pkgs.rofi-wayland;

    plugins = with pkgs; [
      rofi-calc
    ];

    extraConfig = {
      modi = "drun,run,filebrowser,window";
      font = "JetBrains Mono Nerd Font 10";
      show-icons = true;
      terminal = "${pkgs.alacritty}/bin/alacritty";
      display-drun = "  Apps";
      display-run = "  Run";
      display-filebrowser = "  Files";
      display-window = "  Windows";
      display-calc = "";
      drun-display-format = "{name} [<span weight='light' size='small'><i>({generic})</i></span>]";
      window-format = "{w} · {c} · {t}";
    };

    /**
      Author : Aditya Shakya (adi1090x)
      Github : @adi1090x

      Rofi Theme File
      Rofi Version: 1.7.3
    */
    theme = mkForce {
      /**
        ***----- Global Properties -----****
      */
      "*" = {
        font = "JetBrains Mono Nerd Font 10";
        background = mkLiteral "#1f1e25";
        background-alt = mkLiteral "#2a2f41";
        foreground = mkLiteral "#ffffff";
        selected = mkLiteral "#7aa2f7";
        active = mkLiteral "#ffa148";
        urgent = mkLiteral "#7D0075";
      };

      /**
        ***----- Main Window -----****
      */
      window = {
        # properties for window widget
        transparency = "real";
        location = mkLiteral "center";
        anchor = mkLiteral "center";
        fullscreen = false;
        width = mkLiteral "1000px";
        x-offset = mkLiteral "0px";
        y-offset = mkLiteral "0px";

        # properties for all widgets
        enabled = true;
        border-radius = mkLiteral "20px";
        cursor = "default";
        background-color = mkLiteral "@background";
      };

      /**
        ***----- Main Box -----****
      */
      mainbox = {
        enabled = true;
        spacing = mkLiteral "0px";
        background-color = mkLiteral "transparent";
        orientation = mkLiteral "vertical";
        children = map mkLiteral [
          "inputbar"
          "listbox"
        ];
      };

      listbox = {
        spacing = mkLiteral "20px";
        padding = mkLiteral "20px";
        background-color = mkLiteral "transparent";
        orientation = mkLiteral "vertical";
        children = map mkLiteral [
          "message"
          "listview"
        ];
      };

      /**
        ***----- Inputbar -----****
      */
      inputbar = {
        enabled = true;
        spacing = mkLiteral "10px";
        padding = mkLiteral "20px";
        background-color = mkLiteral "#161616";
        text-color = mkLiteral "@foreground";
        orientation = mkLiteral "horizontal";
        children = map mkLiteral [
          "textbox-prompt-colon"
          "entry"
          "dummy"
          "mode-switcher"
        ];
      };
      textbox-prompt-colon = {
        enabled = true;
        expand = false;
        str = " ";
        padding = mkLiteral "12px 12px 12px 15px";
        border-radius = mkLiteral "20px";
        background-color = mkLiteral "@background-alt";
        text-color = mkLiteral "#73daca";
      };
      entry = {
        enabled = true;
        expand = false;
        width = mkLiteral "300px";
        padding = mkLiteral "12px 16px";
        border-radius = mkLiteral "20px";
        background-color = mkLiteral "@background-alt";
        text-color = mkLiteral "inherit";
        cursor = mkLiteral "text";
        placeholder = "Search";
        placeholder-color = mkLiteral "inherit";
      };
      dummy = {
        expand = true;
        background-color = mkLiteral "transparent";
      };

      /**
        ***----- Mode Switcher -----****
      */
      mode-switcher = {
        enabled = true;
        spacing = mkLiteral "10px";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "#73daca";
      };
      button = {
        width = mkLiteral "120px";
        padding = mkLiteral "12px";
        border-radius = mkLiteral "20px";
        background-color = mkLiteral "@background-alt";
        text-color = mkLiteral "inherit";
        cursor = mkLiteral "pointer";
      };
      "button selected" = {
        background-color = mkLiteral "@selected";
        text-color = mkLiteral "@background";
      };

      /**
        ***----- Listview -----****
      */
      listview = {
        enabled = true;
        columns = 2;
        lines = 9;
        cycle = true;
        dynamic = true;
        scrollbar = false;
        layout = mkLiteral "vertical";
        reverse = false;
        fixed-height = true;
        fixed-columns = true;

        spacing = mkLiteral "10px";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@foreground";
        cursor = "default";
      };

      /**
        ***----- Elements -----****
      */
      element = {
        enabled = true;
        spacing = mkLiteral "10px";
        padding = mkLiteral "4px 6px";
        border-radius = mkLiteral "18px";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@foreground";
        cursor = mkLiteral "pointer";
      };

      "element normal.normal" = {
        background-color = mkLiteral "inherit";
        text-color = mkLiteral "inherit";
      };

      "element normal.urgent" = {
        background-color = mkLiteral "@urgent";
        text-color = mkLiteral "@foreground";
      };

      "element normal.active" = {
        background-color = mkLiteral "@active";
        text-color = mkLiteral "@foreground";
      };

      "element selected.normal" = {
        background-color = mkLiteral "@selected";
        text-color = mkLiteral "@background";
      };

      "element selected.urgent" = {
        background-color = mkLiteral "@urgent";
        text-color = mkLiteral "@foreground";
      };

      "element selected.active" = {
        background-color = mkLiteral "@urgent";
        text-color = mkLiteral "@foreground";
      };

      element-icon = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "inherit";
        size = mkLiteral "32px";
        cursor = mkLiteral "inherit";
      };

      element-text = {
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "inherit";
        cursor = mkLiteral "inherit";
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.0";
      };

      /**
        ***----- Message -----****
      */
      message = {
        background-color = mkLiteral "transparent";
      };

      textbox = {
        padding = mkLiteral "12px";
        border-radius = mkLiteral "20px";
        background-color = mkLiteral "@background-alt";
        text-color = mkLiteral "@foreground";
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.0";
      };

      error-message = {
        padding = mkLiteral "12px";
        border-radius = mkLiteral "20px";
        background-color = mkLiteral "@background";
        text-color = mkLiteral "@foreground";
      };

    };
  };
}
