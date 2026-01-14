{ config, pkgs, ... }:

{
  programs.zed-editor = {
    enable = true;
    package = pkgs.zed-editor;
    extensions = [
      "docker-compose"
      "dockerfile"
      "go"
      "gosum"
      "golangci-lint"
      "html"
      "jetbrains-new-ui-icons"
      "jetbrains-themes"
      "log"
      "make"
      "markdown"
      "nix"
      "sql"
      "toml"
    ];
    userSettings = {
      telemetry = {
        diagnostics = false;
        metrics = false;
      };
      theme = {
        mode = "system";
        dark = "JetBrains Dark";
        light = "JetBrains Light";
      };
      icon_theme = {
        mode = "system";
        dark = "JetBrains New UI Icons (Dark)";
        light = "JetBrains New UI Icons (Light)";
      };
      git_panel = {
        tree_view = true;
      };
      terminal = {
        font_size = 12;
        font_family = "JetBrainsMono Nerd Font";
      };
      languages = {
        Proto = {
          format_on_save = "off";
        };
      };
      vim_mode = true;
      ui_font_family = "Inter Nerd Font";
      ui_font_size = 14;
      buffer_font_family = "JetBrainsMono Nerd Font";
      buffer_font_weight = 350;
      buffer_font_size = 13;
    };
    userKeymaps = [
      {
        context = "Workspace";
        bindings = {
          "ctrl-\\" = "terminal_panel::ToggleFocus";
          cmd-b = "workspace::ToggleRightDock";
        };
      }
      {
        context = "Terminal";
        bindings = {
          ctrl-h = "workspace::ActivatePaneLeft";
          ctrl-l = "workspace::ActivatePaneRight";
          ctrl-k = "workspace::ActivatePaneUp";
          ctrl-j = "workspace::ActivatePaneDown";
        };
      }
      {
        context = "Editor && vim_mode == insert || vim_mode == visual && !menu";
        bindings = {
          "j k" = "vim::NormalBefore";
        };
      }
      {
        context = "Editor && (vim_mode == normal || vim_mode == visual) && !VimWaiting && !menu";
        bindings = {
          shift-y = [
            "workspace::SendKeystrokes"
            "y $"
          ]; # Use neovim's yank behavior: yank to end of line.
          "space g h d" = "editor::ToggleSelectedDiffHunks"; # Git
          "space g s" = "git_panel::ToggleFocus"; # Git
          "space t i" = "editor::ToggleInlayHints";
          "space u w" = "editor::ToggleSoftWrap";
          "space c z" = "workspace::ToggleCenteredLayout";
          "space m p" = "markdown::OpenPreview";
          "space m P" = "markdown::OpenPreviewToTheSide";
          "space f p" = "projects::OpenRecent";
          "space s w" = "pane::DeploySearch";
          "space a c" = "assistant::ToggleFocus";
          "g f" = "editor::OpenExcerpts";
        };
      }
      {
        context = "Editor && vim_mode == normal && !VimWaiting && !menu";
        bindings = {
          # Ctrl jklk to move between panes
          ctrl-h = "workspace::ActivatePaneLeft";
          ctrl-l = "workspace::ActivatePaneRight";
          ctrl-k = "workspace::ActivatePaneUp";
          ctrl-j = "workspace::ActivatePaneDown";

          # +LSP
          "space c a" = "editor::ToggleCodeActions";
          "space ." = "editor::ToggleCodeActions";
          "space c r" = "editor::Rename";
          "g d" = "editor::GoToDefinition";
          "g D" = "editor::GoToDefinitionSplit";
          "g i" = "editor::GoToImplementation";
          "g I" = "editor::GoToImplementationSplit";
          "g t" = "editor::GoToTypeDefinition";
          "g T" = "editor::GoToTypeDefinitionSplit";
          "g r" = "editor::FindAllReferences";
          "] d" = "editor::GoToDiagnostic";
          "[ d" = "editor::GoToPreviousDiagnostic";
          "] e" = "editor::GoToDiagnostic"; # Go to next error
          "[ e" = "editor::GoToPreviousDiagnostic"; # Go to prev error
          "s s" = "outline::Toggle"; # Symbol search
          "s S" = "project_symbols::Toggle"; # Symbol search
          "space x x" = "diagnostics::Deploy"; # Diagnostic
          "space /" = "editor::ToggleComments";
          "space r a" = "editor::Rename";

          # +Git
          "] h" = "editor::GoToHunk";
          "[ h" = "editor::GoToPreviousHunk";

          # +Buffers
          shift-tab = "pane::ActivatePreviousItem";
          tab = "pane::ActivateNextItem";
          "space q" = [
            "pane::CloseActiveItem"
            { close_pinned = false; }
          ];
          "space w" = "workspace::Save";
          "space e" = "pane::RevealInProjectPanel";
          "shift shift" = "file_finder::Toggle";
          "v v" = "vim::ToggleVisualLine";
        };
      }
      {
        context = "EmptyPane || SharedScreen";
        bindings = {
          "shift shift" = "file_finder::Toggle";
          "space f p" = "projects::OpenRecent";
        };
      }
      {
        context = "Editor && vim_operator == c";
        bindings = {
          c = "vim::CurrentLine";
          r = "editor::Rename";
        };
      }
      {
        context = "ProjectPanel && not_editing";
        bindings = {
          a = "project_panel::NewFile";
          A = "project_panel::NewDirectory";
          r = "project_panel::Rename";
          d = "project_panel::Delete";
          x = "project_panel::Cut";
          c = "project_panel::Copy";
          p = "project_panel::Paste";
          q = "workspace::ToggleRightDock";
          "space e" = "workspace::ToggleRightDock";
          ctrl-h = "workspace::ActivatePaneLeft";
          ctrl-l = "workspace::ActivatePaneRight";
          ctrl-k = "workspace::ActivatePaneUp";
          ctrl-j = "workspace::ActivatePaneDown";
        };
      }
      {
        context = "Dock";
        bindings = {
          "ctrl-w h" = "workspace::ActivatePaneLeft";
          "ctrl-w l" = "workspace::ActivatePaneRight";
          "ctrl-w k" = "workspace::ActivatePaneUp";
          "ctrl-w j" = "workspace::ActivatePaneDown";
        };
      }
      {
        context = "EmptyPane || SharedScreen || vim_mode == normal";
        bindings = {
          "space r t" = [
            "editor::SpawnNearestTask"
            { reveal = "no_focus"; }
          ];
        };
      }
      {
        context = "vim_mode == normal || vim_mode == visual";
        bindings = {
          s = [
            "vim::PushSneak"
            { }
          ];
          S = [
            "vim::PushSneakBackward"
            { }
          ];
        };
      }
    ];
  };
}
