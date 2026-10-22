---
name: release
description: Cut a release of this dotfiles repo: build the release notes bundle from git history and host evals, write the release story in Russian, and hand the signed tag and publishing to the user through a wizard. Use when the user wants to cut a release, tag a version, or see what changed between two releases.
---

# Release

A **release** and its **release notes** are defined in `GLOSSARY.md`. The
skill lives outside the Nix tree (ADR 0009). Its toolchain (typst, pinned
fonts, python) comes from the `release` devshell, so every render looks the
same.

## Cut a release

The skill never pushes, tags or publishes: those steps need the user's YubiKey
and eyes, and the wizard walks them through.

1. Take `PREV` as the last release tag,
   `git describe --tags --abbrev=0 --match 'v[0-9]*' HEAD`, and `TARGET` as
   `HEAD` of the current branch.
2. Build the bundle into a scratch directory (see below). The builder prints
   `version: v<NixOS branch>.<n>`, the next number after the last tag of the
   NixOS branch at `TARGET`. Classify any `unclassified:` files first.
3. Read the commit log, the packages table, the matrix and the grids, then
   write the story to a file outside `OUT`: Russian, natural language, at most
   4 short paragraphs and 1500 characters, about a minute to read. It tells
   what this release is about as a whole: the idea behind the changes, what
   the user's machines now do differently, and why. It never repeats what the
   card, the grids or the folded blocks already show: no package or module
   lists, versions, counts or commit subjects. Even a release spanning hundreds
   of commits gets the same length. Show it to the user and rebuild with
   `--story FILE`.
4. Show the user `card.png`, the grids and the story, and fix what they ask.
5. Tell the user to run the wizard in their own terminal:
   `.agents/skills/release/wizard.sh VERSION TARGET OUT`. It creates the signed
   annotated tag, pushes it, and publishes the release at once with every PNG
   as an asset and the notes' images pointing at the tag's download URLs. `gh`
   needs write access to the repo's contents.

## Build the bundle

```bash
nix develop ~/dotfiles/nixos#release -c \
  .agents/skills/release/bundle.py [--version vYY.MM.N] [--story FILE] PREV TARGET OUT
```

- `PREV`: the previous release tag. Pass `""` for the first release: the
  bundle then has no commit log and no highlighted changes.
- `TARGET`: the commit to release, usually `HEAD`.
- `--version`: omit it to take the next number after the last
  `v<NixOS branch>.*` tag. The NixOS branch is read from the `nixpkgs` input
  of `nixos/flake.nix` at `TARGET`.
- `--story`: the story file from step 3, paragraphs separated by blank lines.
  More than 4 paragraphs or 1500 characters fails the build.

`OUT` receives `notes.md`, `card.png`, `apps-<host>.png` per host with apps
and `matrix.png`. `notes.md` is in Russian and holds, in this order: the card,
the story, the app grids, then folded blocks for the changed packages, the hosts ×
feature-modules matrix, the flake inputs table and the commit log by area. The
builder reads git, `nix eval` and binary caches only and never calls GitHub.

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
