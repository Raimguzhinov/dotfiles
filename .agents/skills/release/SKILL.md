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
  bundle then holds only the card, with no commit log.
- `TARGET`: the commit to release, usually `HEAD`.
- `--version`: omit it to take the next number after the last
  `v<NixOS branch>.*` tag. The NixOS branch is read from the `nixpkgs` input
  of `nixos/flake.nix` at `TARGET`.

`OUT` receives `notes.md` and `card.png`. The builder reads git only and never
calls GitHub.

## Classify unknown files

Every file that matches no row of `areas.tsv` is printed as
`unclassified: <path>`, and its commits land in Other. Show the list to the
user and ask which area each file belongs to. Add the answers to `areas.tsv`
(`<area><TAB><glob>`, first match wins, `**/` spans directories) and rebuild.

## Test

```bash
nix develop ~/dotfiles/nixos#release -c .agents/skills/release/test.sh
```
