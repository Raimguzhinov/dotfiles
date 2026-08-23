{ inputs, ... }:
let
  herdrNvimVersion = "0.2.1";
  herdrSplitsVersion = "0.5.3";

  mkHerdrNvimBin =
    {
      lib,
      fetchFromGitHub,
      rustPlatform,
    }:
    rustPlatform.buildRustPackage (finalAttrs: {
      pname = "herdr-nvim";
      version = herdrNvimVersion;

      src = fetchFromGitHub {
        owner = "ChmaraX";
        repo = "herdr-nvim";
        tag = "v${finalAttrs.version}";
        hash = "sha256-7xnhtj2ngPe/QXMN8crT3mB+QuJ7PvPFwGuS9TMNPMQ=";
      };
      cargoHash = "sha256-/p2rQYNREyzxs9r4shm+D7AK+DHR3oPSd/GJ+xMAeJU=";

      doCheck = false;

      meta = {
        description = "Neovim sidebar and agent annotations for herdr";
        homepage = "https://github.com/ChmaraX/herdr-nvim";
        license = lib.licenses.mit;
        mainProgram = "herdr-nvim";
      };
    });

  mkHerdr =
    pkgs: base:
    pkgs.symlinkJoin {
      name = "herdr-${base.version}";
      paths = [ base ];
      postBuild = # bash
        ''
          export HOME="$TMPDIR"
          mkdir -p "$out/share/zsh/site-functions" "$out/share/herdr"
          "$out/bin/herdr" completion zsh > "$out/share/zsh/site-functions/_herdr"
          "$out/bin/herdr" --skill > "$out/share/herdr/SKILL.md"
        '';
      inherit (base) meta;
    };

  mkHerdrSplits =
    pkgs:
    pkgs.fetchFromGitHub {
      owner = "lmilojevicc";
      repo = "herdr-splits.nvim";
      tag = "v${herdrSplitsVersion}";
      hash = "sha256-7rHAPSjd2n16FGOcqI/1KNHl1yCmMOVVwiJl/eEU9n8=";
    };

  mkHerdrNvimPlugin =
    pkgs:
    let
      bin = pkgs.callPackage mkHerdrNvimBin { };
    in
    pkgs.runCommand "herdr-nvim-plugin-${herdrNvimVersion}" { } # bash
      ''
        cp -r ${bin.src} "$out"
        chmod -R u+w "$out"
        mkdir -p "$out/bin"
        cp ${bin}/bin/herdr-nvim "$out/bin/herdr-nvim"
      '';

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

  linkedPlugins = pkgs: [
    (mkHerdrSplits pkgs)
    (mkHerdrNvimPlugin pkgs)
    (mkHerdrYazi pkgs)
    (mkHerdrCommandPalette pkgs)
  ];

  syncedPlugins = [
    "Tyru5/herdr-floax"
    "thanhdat77/herdr-navigator"
    "Crokily/herdr-lazygit"
    "persiyanov/herdr-reviewr"
    "sh1ma/herdr-auto-title"
    "iurysza/termscope"
    "rmarganti/herdr-pluck"
  ];

  syncedIntegrations = [
    "claude"
    "opencode"
    "pi"
  ];

  popup = key: command: description: {
    inherit key command description;
    type = "popup";
    width = "85%";
    height = "85%";
  };

  pluginAction = key: command: description: {
    inherit key command description;
    type = "plugin_action";
  };

  herdrSettings = {
    onboarding = false;

    keys = {
      prefix = "ctrl+a";

      help = "prefix+?";
      settings = "prefix+shift+s";
      reload_config = "prefix+shift+r";
      detach = "prefix+q";

      workspace_picker = "prefix+w";
      goto = [
        "prefix+g"
        "prefix+s"
      ];
      toggle_sidebar = "prefix+b";
      open_notification_target = "prefix+shift+o";

      new_workspace = "prefix+shift+n";
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
      zoom = [
        "prefix+z"
        "prefix+f"
      ];
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
        (pluginAction "prefix+e" "chmarax.herdr-nvim.toggle" "nvim sidebar")
        (pluginAction "prefix+o" "chmarax.herdr-nvim.pick-file" "open file from agent output")
        (pluginAction "prefix+slash" "jt.command-palette.open" "command palette")
        (pluginAction "prefix+y" "ray.file-explorer.open" "yazi pane")
        (popup "prefix+t" ''exec "''${SHELL:-sh}"'' "scratch terminal")
        (popup "prefix+alt+g" "lazygit" "lazygit")
        (popup "prefix+alt+d" "lazydocker" "lazydocker")
      ];
    };

    theme.name = "tokyo-night";

    terminal = {
      default_shell = "zsh";
      new_cwd = "follow";
    };

    session.resume_agents_on_restore = true;

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
in
{
  perSystem =
    {
      inputs',
      lib,
      pkgs,
      system,
      ...
    }:
    lib.optionalAttrs
      (builtins.elem system [
        "x86_64-linux"
        "aarch64-linux"
      ])
      {
        packages.herdr = mkHerdr pkgs inputs'.herdr.packages.herdr;
      };

  flake.homeModules.herdr =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      herdr = mkHerdr pkgs inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.herdr;
      toml = pkgs.formats.toml { };
      configFile = toml.generate "herdr-config.toml" herdrSettings;
      pluginRoots = linkedPlugins pkgs;

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

      pluginsSync = pkgs.writeShellApplication {
        name = "herdr-plugins-sync";
        runtimeInputs = [
          herdr
          pkgs.jq
          pkgs.git
        ];
        text = # bash
          ''
            declare -a plugins=(${lib.escapeShellArgs syncedPlugins})
            declare -a integrations=(${lib.escapeShellArgs syncedIntegrations})

            if [[ "''${1:-}" == "--list" ]]; then
              herdr plugin list
              herdr integration status
              exit 0
            fi

            installed="$(herdr plugin list --json 2>/dev/null || echo '{}')"

            for src in "''${plugins[@]}"; do
              owner="''${src%%/*}"
              rest="''${src#*/}"
              repo="''${rest%%/*}"
              if jq -e --arg o "$owner" --arg r "$repo" \
                '.result.plugins[]? | select(.source.owner == $o and .source.repo == $r)' \
                <<<"$installed" >/dev/null 2>&1; then
                echo "herdr-plugins-sync: $src already installed"
                continue
              fi
              echo "herdr-plugins-sync: installing $src"
              herdr plugin install --yes "$src" || echo "herdr-plugins-sync: FAILED $src" >&2
            done

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
        pluginsSync
        sendPaths
      ];

      home.file.".claude/skills/herdr/SKILL.md".source = "${herdr}/share/herdr/SKILL.md";

      xdg.configFile."herdr-nvim/config.toml".source = toml.generate "herdr-nvim-config.toml" (
        herdrNvimSettings "${config.programs.nvf.finalPackage}/bin/nvim"
      );

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
      '';
    };
}
