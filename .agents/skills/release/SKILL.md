---
name: release
description: Build the release bundle for this dotfiles repo (release notes and a header card rendered from git history). Use when the user wants to cut a release, tag a version, or see what changed between two releases.
---

# Release

A **release** and its **release notes** are defined in `GLOSSARY.md`. The
skill lives outside the Nix tree (ADR 0009). Its toolchain (typst, pinned
fonts, python) comes from the `release` devshell, so every render looks the
same.

## Build the bundle

```bash
nix develop ~/dotfiles/nixos#release -c \
  .agents/skills/release/bundle.py [--version vYY.MM.N] PREV TARGET OUT
```

- `PREV`: the previous release tag. Pass `""` for the first release: the
  bundle then has no commit log and no highlighted changes.
- `TARGET`: the commit to release, usually `HEAD`.
- `--version`: omit it to take the next number after the last
  `v<NixOS branch>.*` tag. The NixOS branch is read from the `nixpkgs` input
  of `nixos/flake.nix` at `TARGET`.

`OUT` receives `notes.md`, `card.png`, `apps-<host>.png` per host with apps
and `matrix.png`. `notes.md` holds, in this order: the card, the app grids, then
folded blocks for the changed packages, the hosts × feature-modules matrix, the
flake inputs table and the commit log by area. The builder reads git, `nix
eval` and binary caches only and never calls GitHub.

Packages come from `nix eval` of every `nixosConfigurations` and
`darwinConfigurations` host of the flake at each ref, read straight from git
(`git+file://...?rev=`), so the working tree is never checked out and nothing
is built. A host's packages are `environment.systemPackages` plus the
home-manager `home.packages` of user `dias`, keyed by name with their version.
The card counts added, removed and updated (host, package) pairs. The first
release lists every package instead. One eval of this flake takes about 15 s.

App grids show the desktop entries (`share/applications/*.desktop` without
`NoDisplay` or `Hidden`) and darwin `Applications/*.app` of the target ref's
packages, plus those of packages removed since `PREV`. Package paths are
fetched with `nix build --max-jobs 0`, so a path that is neither in the local
store nor in a binary cache is skipped, never built. Its apps are absent from
the grid. An app is added or removed when its package is. The icon comes from
the package's hicolor theme or pixmaps (SVG or PNG), otherwise the tile shows
the first letter of the name.

The matrix comes from the host sources at each ref: a host is a directory under
`nixos/modules/hosts/` that defines `flake.nixosConfigurations.<name>` or
`flake.darwinConfigurations.<name>`. Its modules are the uncommented
`nixosModules.<name>` and `homeModules.<name>` references that a file in
`nixos/modules/features/` exports. A module enabled on no host is left out.

## Classify unknown files

Every file that matches no row of `areas.tsv` is printed as
`unclassified: <path>`, and its commits land in Other. Show the list to the
user and ask which area each file belongs to. Add the answers to `areas.tsv`
(`<area><TAB><glob>`, first match wins, `**/` spans directories) and rebuild.

## Test

```bash
nix develop ~/dotfiles/nixos#release -c .agents/skills/release/test.sh
```

The card and matrix tests compare against `testdata/*.png`. After an intended
design change, rerun with `UPDATE_GOLDEN=1`, look at the images, and commit
them.
