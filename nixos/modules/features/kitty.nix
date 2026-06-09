{ ... }:
{
  flake.homeModules.kitty =
    { pkgs, ... }:
    {
      programs.kitty = {
        enable = true;
        enableGitIntegration = true;
        shellIntegration = {
          enableBashIntegration = true;
          enableZshIntegration = true;
        };
        font = {
          name = "JetBrainsMono Nerd Font";
          size = 10.5;
        };
        settings = {
          enable_audio_bell = "no";
          visual_bell_duration = "0.0";
          window_alert_on_bell = "no";
          shell = "${pkgs.zsh}/bin/zsh";
          scrollback_lines = 10000;
          bold_is_bright = "yes";
          background = "#181818";
          foreground = "#ffffff";
          color0 = "#181818";
          color1 = "#f62b5a";
          color2 = "#47b413";
          color3 = "#e3c401";
          color4 = "#24acd4";
          color5 = "#f2affd";
          color6 = "#13c299";
          color7 = "#e6e6e6";
          color8 = "#616161";
          color9 = "#ff4d51";
          color10 = "#35d450";
          color11 = "#e9e836";
          color12 = "#5dc5f8";
          color13 = "#feabf2";
          color14 = "#24dfc4";
          color15 = "#ffffff";
        };
        keybindings = {
          "ctrl+c" = "copy_or_interrupt";
        };
      };
    };
}
