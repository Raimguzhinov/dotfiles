# AGENTS.md

NixOS dotfiles for the user's machines: hosts, desktop, tools, editors, and a
coding-agent harness. Flake entry point: `nixos/flake.nix`.

## Git

- Commit only when the user asks. The commit-msg hook
  (`scripts/check_commit_msg.sh`) enforces English and the
  `nixos: <file>: description` format.
- If GPG signing fails (no YubiKey or no PIN prompt), stop and ask the user to
  commit locally: signing needs the physical key.
- Close an issue whose comment references a commit only after that commit is
  pushed, so the reference resolves.

## Editing Nix

- import-tree loads every `.nix` under `nixos/modules/` as a flake-parts
  module. Prefix files that are not modules with `_` (`_disko.nix`).
- A feature module exports `flake.nixosModules.<name>` or
  `flake.homeModules.<name>` and takes effect only once the host lists it:
  nixosModules in `hosts/<host>/default.nix`, homeModules in the home-manager
  imports of `hosts/<host>/configuration.nix`.
- Hosts: `raimguzhinov` (`hosts/dell-xps-13-9320`, the current machine) and
  `thinkpad-t495` (`hosts/lenovo-thinkpad-t495`).
- Desktop packages go to `home.packages` of user `dias`.
  `environment.systemPackages` holds only what needs system-level polkit.
- One `inherit` per line.
- In `perSystem`, check the platform with `system` + `builtins.elem`:
  `pkgs.stdenv.isLinux` recurses there.
- A module top-level `let` can reference `lib` but not `pkgs`: neither
  flake-parts nor home-manager provides `pkgs` outside `perSystem` /
  homeModules. Keep the source as a bare string at top level and
  `pkgs.writeText` it where `pkgs` is in scope.
- In `home.activation`, a command that calls external binaries or the network
  logs `WARNING` on failure and lets activation continue. `set -e` is only for
  pure file operations.
- `export NIX_CONFIG="eval-cache = false"` in the generated `~/Work/.envrc`
  (`development.nix`) works around `eval-cache ... sqlite is busy`; keep it
  local to that file.
- Change `flake.lock` through nix only: `nix flake lock --update-input NAME`.
- `~/.config` and `~/.pi` are generated from Nix: edit the module that writes
  them.
- No non-`.nix` files under `nixos/`: extension and tool sources stay inline in
  the module that ships them (`pkgs.writeText`, the pi.nix pattern).
- When a build fails inside an external flake input, report options to the
  user (update the input, wait for an upstream fix, drop the dependency).
  Local overrides, patches and re-pinned hashes rot on the next update.

## Verifying

- After editing `nixos/` for the current host, run
  `nixos-rebuild build --flake ~/dotfiles/nixos#raimguzhinov` (no sudo).
- Format edited Nix with `nixfmt <file>`: pre-commit runs `nixfmt --check` and,
  for `pi.nix`, `scripts/check_pi_theme_tokens.py`. All hooks:
  `pre-commit run --all-files`.
- `switch`, `nix build`, and builds of other hosts or branches run only on
  request: they target another machine or need the user at the fingerprint
  reader.
- Before reporting, review `git diff`: no duplicates, correct indentation and
  syntax, only the requested change.
- An interrupted command may have partly run: read `git diff` before retrying.
- Visual changes (colors, layout): after the second failed iteration, render
  the output (ANSI) to a file and compare against the render.

## Environment

- Other agents edit this repo in parallel: re-read a file and `git status`
  right before editing it.
- When the permission system denies a deletion (recursive `rm`,
  `find -delete`), ask the user to run it.
- GitHub file reads: `git clone --depth 1 <repo>` (`gh api` is dead on
  this host, every call 404s). `gh` CLI for issues/PRs and gh_grep MCP
  for code search work. URL tools (aft_outline, web_url_read) block
  GitHub hosts.
- After two attempts against an external blocker, give the user one line of
  options and move to the next task.

## Dell XPS 13 9320

The touchpad recovers only through `xps-touchpad-watchdog` (hibernate).
Re-probing `i2c_hid` (unbind/bind) hangs the I2C bus until power-off, and
`modprobe -r i2c_designware_*` leaves the touchpad dead until reboot. Leave
both out of any fix.

## Read before

- `switch`: `docs/agents/rebuild.md`
- editing `neovim.nix`: `docs/agents/neovim-nix.md`
- XPS hardware work (camera, mic, sleep, touchpad, PAM): `docs/agents/xps-hardware.md`
- harness work (`harness.nix`, `pi.nix`, `opencode.nix`, `claude.nix`): `docs/agents/harness.md`

## Agent skills

- Issue tracker: GitHub issues in `Raimguzhinov/dotfiles` via `gh`, see
  `docs/agents/issue-tracker.md`.
- Triage labels: `docs/agents/triage-labels.md`.
- Domain docs: `GLOSSARY.md` + `docs/adr/`, see `docs/agents/domain.md`.
