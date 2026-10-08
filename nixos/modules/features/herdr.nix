{ ... }:
let
  mkRustHerdrPlugin =
    {
      pkgs,
      rustPlatform ? pkgs.rustPlatform,
      pname,
      version,
      src,
      cargoHash,
      description,
    }:
    let
      bin = rustPlatform.buildRustPackage {
        inherit pname;
        inherit version;
        inherit src;
        inherit cargoHash;

        doCheck = false;

        meta = {
          inherit description;
          homepage = "https://github.com/${src.owner}/${src.repo}";
          license = pkgs.lib.licenses.mit;
          mainProgram = pname;
        };
      };
    in
    pkgs.runCommand "${pname}-plugin-${version}" { } # bash
      ''
        cp -r ${src} "$out"
        chmod -R u+w "$out"
        mkdir -p "$out/bin"
        cp ${pkgs.lib.getExe bin} "$out/bin/${pname}"
      '';

  mkHerdrNvimPlugin =
    pkgs:
    mkRustHerdrPlugin rec {
      inherit pkgs;
      pname = "herdr-nvim";
      version = "1.1.0";
      src = pkgs.fetchFromGitHub {
        owner = "ChmaraX";
        repo = "herdr-nvim";
        tag = "v${version}";
        hash = "sha256-q44Qt73XzNNipwF3hHr3Hzg0EReC3tz2bKB/l4ZBqiE=";
      };
      cargoHash = "sha256-pImtQ1YiM47VvA8u9ER/lXtDVsZhQy38fkCbzmT/gc4=";
      description = "Neovim sidebar and agent annotations for herdr";
    };

  mkHerdrReviewr =
    pkgs: pkgs-unstable:
    mkRustHerdrPlugin rec {
      inherit pkgs;
      inherit (pkgs-unstable) rustPlatform;
      pname = "herdr-reviewr";
      version = "0.46.0";
      src = pkgs.fetchFromGitHub {
        owner = "persiyanov";
        repo = "herdr-reviewr";
        tag = "v${version}";
        hash = "sha256-KJNzp6e7Uy3E1teheD/dMpB5Zqw7dqxEGnjJqvJgYaE=";
      };
      cargoHash = "sha256-v7GFjRE2Zw6HWpD5Pl7Pd8+PNz7Lb05dvsnFJshFtLE=";
      description = "Review agent-written diffs beside the chat in herdr";
    };

  mkHerdrPluck =
    pkgs:
    mkRustHerdrPlugin {
      inherit pkgs;
      pname = "herdr-pluck";
      version = "0.3.1-unstable-2026-09-25";
      src = pkgs.fetchFromGitHub {
        owner = "rmarganti";
        repo = "herdr-pluck";
        rev = "1a6302384098f21835e2964637d39dddc989bc1d";
        hash = "sha256-XK8Tky9kDW8TSudfYvXkqRMYUFnTORguVVYH4z7UrFM=";
      };
      cargoHash = "sha256-p6KhaqawJOSwt/JfZGSKXSxa2eU570wkXEAd3j1o92Y=";
      description = "Inline keyboard hints for copying tokens or opening URLs from herdr panes";
    };

  mkHerdrYazi =
    pkgs:
    pkgs.fetchFromGitHub {
      owner = "speardragon";
      repo = "herdr-yazi";
      rev = "54aa4e6dff480189630fa3593146cdcc2768ade9";
      hash = "sha256-5bAy+xD1mLYJOUYvLWeU2pgZpYAeo+hxdNSlaM9pCkA=";
    };

  mkHerdrCommandPalette =
    pkgs:
    pkgs.fetchFromGitHub {
      owner = "JanTvrdik";
      repo = "herdr-command-palette";
      rev = "eab940018c2135ac23718efa11e23e9dddcd2a75";
      hash = "sha256-A43Dl365S/5w2wrttV1RnQ1g7YRJmsD3tb5EUUZcQQY=";
    };

  mkHerdrOhMyZsh =
    pkgs:
    pkgs.fetchFromGitHub {
      owner = "robbyrussell";
      repo = "herdr-ohmyzsh";
      rev = "bbc072ada531e6306276900a866a4b44a9b92e74";
      hash = "sha256-75JYRXRfn5dFH88DBQqVRbW5OVL1eq3en0M19NpFKLE=";
    };

  linkedPlugins = pkgs: pkgs-unstable: [
    pkgs-unstable.vimPlugins.herdr-splits-nvim
    (mkHerdrNvimPlugin pkgs)
    (mkHerdrYazi pkgs)
    (mkHerdrCommandPalette pkgs)
    (mkHerdrOhMyZsh pkgs)
    (mkHerdrReviewr pkgs pkgs-unstable)
    (mkHerdrPluck pkgs)
  ];

  syncedIntegrations = [
    "claude"
    "codex"
    "opencode"
    "pi"
  ];

  # -6 умеренно (peak -16 dB) | -12 заметно тише (-22) | -18 фоновый мягкий (-28)
  doneSoundGainDb = -12;
  requestSoundGainDb = -18;

  mkQuietSound =
    pkgs: herdr: name: gainDb:
    pkgs.runCommand "herdr-quiet-${name}.mp3" { nativeBuildInputs = [ pkgs.ffmpeg-headless ]; } # bash
      ''
        ffmpeg -nostdin -loglevel error \
          -i ${herdr.src}/assets/sounds/${name}.mp3 \
          -af volume=${toString gainDb}dB \
          -codec:a libmp3lame -q:a 2 "$out"
      '';

  popup = key: command: description: {
    inherit key command description;
    type = "popup";
    width = "90%";
    height = "85%";
  };

  pluginAction = key: command: description: {
    inherit key command description;
    type = "plugin_action";
  };

  shellCmd = key: command: description: {
    inherit key command description;
    type = "shell";
  };

  herdrSettings = pkgs: herdr: {
    onboarding = false;

    keys = {
      prefix = "ctrl+a";

      help = "prefix+?";
      settings = "prefix+shift+s";
      reload_config = "prefix+shift+r";
      detach = "prefix+q";

      workspace_picker = "prefix+w";
      goto = [
        "prefix+alt+g"
        "prefix+s"
      ];
      toggle_sidebar = "prefix+b";
      open_notification_target = "prefix+shift+o";

      rename_workspace = "prefix+shift+w";
      close_workspace = "prefix+shift+d";
      switch_workspace = "prefix+shift+1..9";
      previous_workspace = "ctrl+k";
      next_workspace = "ctrl+j";
      new_worktree = "prefix+shift+g";
      open_worktree = "prefix+ctrl+g";

      new_tab = "prefix+n";
      rename_tab = [
        "prefix+shift+t"
        "prefix+comma"
      ];
      previous_tab = "ctrl+h";
      next_tab = "ctrl+l";
      switch_tab = "prefix+1..9";
      close_tab = [
        "prefix+shift+x"
        "prefix+ampersand"
      ];
      move_tab_previous = "prefix+shift+comma";
      move_tab_next = "prefix+shift+period";

      split_vertical = [
        "prefix+v"
        "prefix+percent"
      ];
      split_horizontal = [
        "prefix+minus"
        "prefix+double_quote"
      ];
      close_pane = "prefix+x";
      zoom = "prefix+z";
      rename_pane = "prefix+shift+p";
      focus_pane_left = "prefix+left";
      focus_pane_down = "prefix+down";
      focus_pane_up = "prefix+up";
      focus_pane_right = "prefix+right";
      swap_pane_left = "prefix+shift+h";
      swap_pane_down = "prefix+shift+j";
      swap_pane_up = "prefix+shift+k";
      swap_pane_right = "prefix+shift+l";
      cycle_pane_next = "prefix+tab";
      cycle_pane_previous = "prefix+shift+tab";
      last_pane = "prefix+semicolon";
      resize_mode = "prefix+r";
      copy_mode = "prefix+[";
      edit_scrollback = "prefix+shift+e";

      focus_agent = "ctrl+shift+1..9";
      previous_agent = "ctrl+shift+k";
      next_agent = "ctrl+shift+j";

      command = [
        (pluginAction "prefix+h" "herdr-splits.nav-left" "nav left (nvim/herdr)")
        (pluginAction "prefix+j" "herdr-splits.nav-down" "nav down (nvim/herdr)")
        (pluginAction "prefix+k" "herdr-splits.nav-up" "nav up (nvim/herdr)")
        (pluginAction "prefix+l" "herdr-splits.nav-right" "nav right (nvim/herdr)")
        (pluginAction "alt+h" "herdr-splits.resize-left" "resize left (nvim/herdr)")
        (pluginAction "alt+j" "herdr-splits.resize-down" "resize down (nvim/herdr)")
        (pluginAction "alt+k" "herdr-splits.resize-up" "resize up (nvim/herdr)")
        (pluginAction "alt+l" "herdr-splits.resize-right" "resize right (nvim/herdr)")
        (shellCmd "prefix+e" "herdr-toggle-or-pick" "nvim sidebar (toggle/pick)")
        (pluginAction "prefix+y" "rmarganti.herdr-pluck.pluck" "yank from scrollback")
        (pluginAction "prefix+u" "persiyanov.reviewr.toggle" "review working tree")
        (shellCmd "prefix+i" "herdr-pick-file-fullscreen" "open file from agent output (new tab)")
        (pluginAction "prefix+o" "ray.file-explorer.open" "yazi pane")
        (pluginAction "prefix+f" "rmarganti.herdr-pluck.open-url" "open url from scrollback")
        (pluginAction "prefix+slash" "jt.command-palette.open" "command palette")
        (pluginAction "prefix+shift+z" "ohmyzsh.shell.reload-all" "reload Oh My Zsh in idle panes")
        (popup "prefix+t" ''exec "''${SHELL:-sh}"'' "scratch terminal")
        (popup "prefix+g" "lazygit" "lazygit")
        (popup "prefix+d" "lazydocker" "lazydocker")
      ];
    };

    theme.name = "tokyo-night";

    terminal = {
      default_shell = "zsh";
      new_cwd = "follow";
    };

    session.resume_agents_on_restore = true;

    update = {
      version_check = false;
      manifest_check = false;
    };

    worktrees.directory = "~/Work/herdr-worktrees";

    ui = {
      window_title = "{workspace} · {tab}";
      tab_bar_position = "bottom";
      status_indicators = "symbols";
      agent_panel_sort = "priority";
      pane_borders = true;
      pane_gaps = false;
      show_agent_labels_on_pane_borders = true;
      tab_bar_right = [
        { type = "zoom"; }
        {
          type = "datetime";
          format = "%H:%M";
        }
      ];
      tab_bar_right_separator = " · ";

      sidebar = {
        agents.rows = [
          [
            "state_icon"
            "agent"
            "state_text"
          ]
          [ "terminal_title_stripped" ]
          [
            "workspace"
            "tab"
          ]
        ];
        spaces.rows = [
          [
            "state_icon"
            "workspace"
          ]
          [
            "branch"
            "git_status"
          ]
        ];
      };

      toast = {
        delivery = "system";
        delay_seconds = 1;
      };

      sound = {
        done_path = "${mkQuietSound pkgs herdr "done" doneSoundGainDb}";
        request_path = "${mkQuietSound pkgs herdr "request" requestSoundGainDb}";
      };
    };

    experimental = {
      kitty_graphics = true;
      pane_history = false;
    };
  };

  herdrNvimSettings = nvimBin: {
    sidebar = {
      nvim_bin = nvimBin;
      position = "right";
    };
    picker.max_files = 30;
  };

  reviewrSettings = {
    theme = "catppuccin";
    default_scope = "uncommitted";
    navigator_position = "bottom";
    toggle_placement = "split";
    toggle_direction = "right";
    auto_open = false;
    editor = "nvim +{line} {file}";
    gitlab_host = "git.protei.ru";

    keybindings = {
      expand = [
        "l"
        "right"
      ];
      collapse = [
        "h"
        "left"
      ];
      comments = [ "L" ];
    };
  };

in
{
  perSystem =
    {
      lib,
      pkgs-unstable,
      system,
      ...
    }:
    lib.optionalAttrs
      (builtins.elem system [
        "x86_64-linux"
        "aarch64-linux"
      ])
      {
        packages.herdr = pkgs-unstable.herdr;
      };

  flake.homeModules.herdr =
    {
      config,
      lib,
      pkgs,
      pkgs-unstable,
      ...
    }:
    let
      inherit (pkgs-unstable) herdr;
      toml = pkgs.formats.toml { };
      configFile = toml.generate "herdr-config.toml" (herdrSettings pkgs herdr);
      pluginRoots = linkedPlugins pkgs pkgs-unstable;
      ohMyZshPlugin = mkHerdrOhMyZsh pkgs;
      ohMyZshCustomDir = "${config.xdg.cacheHome}/oh-my-zsh/custom";

      sendPaths = pkgs.writeShellApplication {
        name = "herdr-send-paths";
        runtimeInputs = [
          herdr
          pkgs.jq
        ];
        text = # bash
          ''
            if [[ "''${HERDR_ENV:-}" != "1" || -z "''${HERDR_PANE_ID:-}" ]]; then
              echo "herdr-send-paths: not running inside a herdr pane" >&2
              exit 1
            fi

            if [[ $# -eq 0 ]]; then
              echo "usage: herdr-send-paths <path>..." >&2
              exit 2
            fi

            agents="$(herdr agent list)"
            tab="$(herdr pane get "$HERDR_PANE_ID" | jq -r '.result.pane.tab_id // empty')"

            target="$(jq -r --arg t "$tab" \
              '[.result.agents[]? | select(.tab_id == $t)][0].pane_id // empty' <<<"$agents")"

            if [[ -z "$target" ]]; then
              target="$(jq -r '.result.agents[0]?.pane_id // empty' <<<"$agents")"
            fi

            if [[ -z "$target" ]]; then
              echo "herdr-send-paths: no agent found in this session" >&2
              exit 1
            fi

            herdr pane send-text "$target" "$*"
          '';
      };

      pickFileFullscreen = pkgs.writeShellApplication {
        name = "herdr-pick-file-fullscreen";
        runtimeInputs = [
          herdr
          pkgs.jq
        ];
        text = # bash
          ''
            before="$(herdr pane list)"
            tab="$(jq -r '.result.panes[] | select(.focused == true) | .tab_id' <<<"$before" | head -n1)"
            if [[ -z "$tab" ]]; then
              exit 0
            fi
            before_count="$(jq -r --arg t "$tab" '[.result.panes[] | select(.tab_id == $t)] | length' <<<"$before")"

            herdr plugin action invoke pick-file --plugin chmarax.herdr-nvim >/dev/null

            for _ in $(seq 1 200); do
              sleep 0.3
              after="$(herdr pane list)"
              after_count="$(jq -r --arg t "$tab" '[.result.panes[] | select(.tab_id == $t)] | length' <<<"$after")"
              if [[ "$after_count" != "$before_count" ]]; then
                pane="$(jq -r --arg t "$tab" '.result.panes[] | select(.tab_id == $t and .focused == true) | .pane_id' <<<"$after")"
                if [[ -n "$pane" ]]; then
                  herdr pane move "$pane" --new-tab --focus >/dev/null
                fi
                exit 0
              fi
            done
          '';
      };

      toggleOrPick = pkgs.writeShellApplication {
        name = "herdr-toggle-or-pick";
        runtimeInputs = [
          herdr
          pkgs.jq
        ];
        text = # bash
          ''
            tab="$(herdr pane list | jq -r '.result.panes[] | select(.focused == true) | .tab_id' | head -n1)"
            if [[ -z "$tab" ]]; then
              exit 0
            fi

            state_dir="''${HERDR_NVIM_STATE_DIR:-''${XDG_STATE_HOME:-$HOME/.local/state}/herdr-nvim}"
            state_file="$state_dir/''${tab//:/_}.json"

            sidebar_pane=""
            if [[ -f "$state_file" ]]; then
              sidebar_pane="$(jq -r '.sidebar_pane // empty' "$state_file" 2>/dev/null || true)"
            fi

            if [[ -n "$sidebar_pane" ]] && herdr pane get "$sidebar_pane" >/dev/null 2>&1; then
              herdr plugin action invoke toggle --plugin chmarax.herdr-nvim >/dev/null
            else
              herdr plugin action invoke pick-file --plugin chmarax.herdr-nvim >/dev/null
            fi
          '';
      };

      pluginsSync = pkgs.writeShellApplication {
        name = "herdr-plugins-sync";
        runtimeInputs = [
          herdr
        ];
        text = # bash
          ''
            declare -a integrations=(${lib.escapeShellArgs syncedIntegrations})

            if [[ "''${1:-}" == "--list" ]]; then
              herdr plugin list
              herdr integration status
              exit 0
            fi

            for name in "''${integrations[@]}"; do
              herdr integration install "$name" || echo "herdr-plugins-sync: integration FAILED $name" >&2
            done

            herdr server reload-config 2>/dev/null || true
          '';
      };
    in
    {
      home.packages = [
        herdr
        pickFileFullscreen
        pluginsSync
        sendPaths
        toggleOrPick
      ];

      home.file.".claude/skills/herdr/SKILL.md".source = "${herdr}/share/skills/herdr/herdr/SKILL.md";
      home.file.".pi/agent/skills/herdr/SKILL.md".source = "${herdr}/share/skills/herdr/herdr/SKILL.md";
      xdg.configFile."opencode/skills/herdr/SKILL.md".source =
        "${herdr}/share/skills/herdr/herdr/SKILL.md";

      programs.zsh.oh-my-zsh = {
        custom = ohMyZshCustomDir;
        plugins = [ "herdr" ];
      };

      home.sessionVariables.HERDR_OMZ_REPORT = false;
      home.sessionVariables.HERDR_OMZ_NOTIFY = false;
      # home.sessionVariables.HERDR_OMZ_THRESHOLD = "60"; # require HERDR_OMZ_REPORT=true
      home.sessionVariables.HERDR_OMZ_DEFAULT_AGENT = "pi";

      xdg.configFile."herdr-nvim/config.toml".source = toml.generate "herdr-nvim-config.toml" (
        herdrNvimSettings "${config.programs.nvf.finalPackage}/bin/nvim"
      );

      xdg.configFile."herdr/plugins/config/persiyanov.reviewr/config.toml".source =
        toml.generate "herdr-reviewr-config.toml" reviewrSettings;

      programs.zsh.shellAliases = {
        hd = "herdr";
        hda = "herdr session attach";
        hdl = "herdr session list";
      };

      home.activation.setupHerdr = lib.mkAfter /* bash */ ''
        set -euo pipefail

        config_dir="$HOME/.config/herdr"

        log() { printf '[herdr] %s\n' "$*" >&2; }

        mkdir -p "$config_dir"
        install -m600 ${configFile} "$config_dir/config.toml"

        for root in ${lib.escapeShellArgs pluginRoots}; do
          if ! ${herdr}/bin/herdr plugin link "$root" >/dev/null; then
            log "plugin link failed for $root"
          fi
        done

        omz_custom_plugins="${ohMyZshCustomDir}/plugins"
        mkdir -p "$omz_custom_plugins"
        ln -sfn ${ohMyZshPlugin} "$omz_custom_plugins/herdr"

        if ! ${pluginsSync}/bin/herdr-plugins-sync >/dev/null 2>&1; then
          log "herdr-plugins-sync failed (offline or herdr unreachable?)"
        fi
      '';
    };
}
