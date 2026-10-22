#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
bundle="$here/bundle.py"
golden="$here/testdata"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failed=0

fail() {
  echo "FAIL: $1"
  failed=1
}

commit() {
  local path=$1 msg=$2
  mkdir -p "$(dirname "$path")"
  echo "$msg" >>"$path"
  git add "$path"
  GIT_AUTHOR_DATE="2026-01-0${3:-1}T12:00:00Z" GIT_COMMITTER_DATE="2026-01-0${3:-1}T12:00:00Z" \
    git commit -qm "$msg"
}

put() {
  mkdir -p "$(dirname "$1")"
  cat >"$1"
  git add "$1"
}

lock() {
  local nodes="" root="" name ts
  while (($#)); do
    name=$1 ts=$2
    shift 2
    nodes+="\"$name\": {\"locked\": {\"lastModified\": $ts, \"narHash\": \"sha256-$name-$ts\", \"owner\": \"o\", \"repo\": \"$name\", \"rev\": \"$(printf '%040d' "$ts")\", \"type\": \"github\"}, \"original\": {\"owner\": \"o\", \"repo\": \"$name\", \"type\": \"github\"}}, "
    root+="\"$name\": \"$name\", "
  done
  put nixos/flake.lock <<EOF
{"nodes": {${nodes}"root": {"inputs": {${root%, }}}}, "root": "root", "version": 7}
EOF
}

repo="$work/repo"
git init -q "$repo"
cd "$repo"
git config user.name test
git config user.email test@example.com
git config commit.gpgsign false
put nixos/flake.nix <<'EOF'
{
  # nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  outputs = _: {
    nixosConfigurations = builtins.mapAttrs (name: _: { config = import ./inventory/nixos/${name}; }) (builtins.readDir ./inventory/nixos);
    darwinConfigurations =
      if builtins.pathExists ./inventory/darwin then
        builtins.mapAttrs (name: _: { config = import ./inventory/darwin/${name}; }) (builtins.readDir ./inventory/darwin)
      else
        { };
  };
}
EOF
packages() {
  put "$1" <<EOF
let
  p = name: version: { pname = name; inherit version; name = "\${name}-\${version}"; };
  a = name: version: p name version // { outPath = builtins.path { path = ../../../apps + "/\${name}"; name = "\${name}-\${version}"; }; };
in
{ environment.systemPackages = [ $2 ]; home-manager.users.dias.home.packages = [ $3 ]; }
EOF
}
icon() {
  put "$1" <<<"<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 64 64\"><rect width=\"64\" height=\"64\" rx=\"14\" fill=\"$2\"/></svg>"
}
desktop() {
  put "$1" <<<"$(printf '[Desktop Entry]\nType=Application\nName=%s\nName[ru]=Localized\nIcon=%s\n%s' "$2" "$3" "${4:-}")"
}
desktop nixos/apps/kitty/share/applications/kitty.desktop kitty kitty
desktop nixos/apps/kitty/share/applications/kitty-open.desktop "kitty URL Launcher" kitty NoDisplay=true
icon nixos/apps/kitty/share/icons/hicolor/scalable/apps/kitty.svg '#f9e2af'
desktop nixos/apps/firefox/share/applications/firefox.desktop Firefox firefox
desktop nixos/apps/xterm/share/applications/xterm.desktop XTerm xterm
icon nixos/apps/xterm/share/icons/hicolor/scalable/apps/xterm.svg '#94e2d5'
desktop nixos/apps/zed/share/applications/dev.zed.Zed.desktop Zed zed
icon nixos/apps/zed/share/pixmaps/zed.svg '#cba6f7'
put nixos/apps/iterm2/Applications/iTerm.app/Contents/Info.plist <<<'<plist/>'
packages nixos/inventory/nixos/alpha/default.nix '(p "git" "2.50") (p "curl" "8.0")' '(a "kitty" "0.40") (a "firefox" "130") (a "xterm" "390")'
lock nixpkgs 1767225600 noctalia 1767571200 old-input 1764547200
put nixos/modules/features/pi.nix <<<'{ flake.nixosModules.pi = { }; flake.homeModules.pi = { }; }'
put nixos/modules/hosts/alpha/default.nix <<<'{ flake.nixosConfigurations.alpha = mk { modules = [ config.flake.nixosModules.pi ]; }; }'
put nixos/modules/hosts/alpha/configuration.nix <<'EOF'
{
  imports = [
    homeModules.niri
    # homeModules.kitty
  ];
}
EOF
put nixos/modules/features/kitty.nix <<<'{ flake.homeModules.kitty = { }; }'
put nixos/modules/features/niri.nix <<<'{ flake.homeModules.niri = { }; }'
commit nixos/modules/features/niri.nix "nixos: niri.nix: add niri" 1
git tag start
commit nixos/modules/features/pi.nix "nixos: pi.nix: add pi" 2
commit nixos/modules/features/kitty.nix "nixos: kitty.nix: add kitty" 2
commit misc/unknown.txt "nixos: unknown.txt: add file" 3
commit docs/adr/0001.md "nixos: 0001.md: add adr" 4
put nixos/modules/hosts/alpha/configuration.nix <<'EOF'
{
  imports = [
    homeModules.kitty
  ];
}
EOF
put nixos/modules/hosts/beta/default.nix <<<'{ flake.nixosConfigurations.beta = mk { home.imports = [ homeModules.niri ]; }; }'
lock nixpkgs 1769904000 noctalia 1767571200 sops-nix 1769990400
packages nixos/inventory/nixos/alpha/default.nix '(p "git" "2.51") (p "ghost" "1.0" // { outPath = "/nix/store/00000000000000000000000000000000-ghost-1.0"; })' '(a "kitty" "0.40") (a "firefox" "130") (p "ripgrep" "14.1") (a "zed" "0.200")'
put nixos/inventory/nixos/beta/default.nix <<<'{ environment.systemPackages = [ { pname = "fd"; version = "10.2"; name = "fd-10.2"; } { name = "hello-2.12"; } ]; }'
packages nixos/inventory/darwin/gamma/default.nix '' '(p "htop" "3.4") (a "iterm2" "3.5")'
commit nixos/modules/hosts/beta/notes "nixos: hosts: enable kitty on alpha, add beta" 5

printf '%s\n' 'Релиз переводит рабочий стол' 'на kitty.' '' '' 'Появился второй хост beta.' >"$work/story"
"$bundle" --version v25.11.2 --story "$work/story" start HEAD "$work/a" >/dev/null
"$bundle" --version v25.11.2 --story "$work/story" start HEAD "$work/b" >/dev/null

[[ -s $work/a/notes.md ]] || fail "notes.md is missing"
[[ $(head -c 8 "$work/a/card.png" | od -An -tx1 | tr -d ' ') == 89504e470d0a1a0a ]] || fail "card.png is not a PNG"
diff -r "$work/a" "$work/b" >/dev/null || fail "two runs on the same refs differ"

blocks_in_order() {
  local notes=$1 prev=0 n block
  shift
  for block in "$@"; do
    n=$(awk -v block="$block" -v prev="$prev" 'NR > prev && $0 == block { print NR; exit }' "$notes")
    [[ -n $n ]] || { fail "$notes: block '$block' is missing or out of order"; continue; }
    prev=$n
  done
}
blocks_in_order "$work/a/notes.md" \
  '![v25.11.2](card.png)' \
  'Релиз переводит рабочий стол на kitty.' 'Появился второй хост beta.' \
  '![alpha](apps-alpha.png)' '![gamma](apps-gamma.png)' \
  '<summary>Пакеты</summary>' '</details>' \
  '<summary>Хосты и модули</summary>' '![Хосты и модули](matrix.png)' '</details>' \
  '<summary>Входы flake</summary>' '</details>' \
  '<summary>Коммиты по областям</summary>' '### Рабочий стол' '### Агенты' '### Хосты' '### Документация' '### Прочее' '#### Файлы без области' '</details>'
[[ $(head -1 "$work/a/notes.md") == '![v25.11.2](card.png)' ]] || fail "card is not the first block"
(($(grep -cxF '<details>' "$work/a/notes.md") == 4)) || fail "secondary blocks are not each folded in <details>"
[[ -e $work/a/apps-beta.png ]] && fail "host without apps has a grid"
grep -qF 'apps-beta.png' "$work/a/notes.md" && fail "notes link a grid for a host without apps"

other=$(sed -n '/^### Прочее$/,/^#### /p' "$work/a/notes.md")
grep -qF 'nixos: unknown.txt: add file' <<<"$other" || fail "commit touching an unclassified file is not under Other"
grep -qF 'nixos: pi.nix: add pi' <<<"$other" && fail "classified commit leaked into Other"
files=$(sed -n '/^#### Файлы без области$/,/^<\/details>$/p' "$work/a/notes.md")
grep -qxF -- '- `misc/unknown.txt`' <<<"$files" || fail "unclassified file is not listed"
grep -qF 'pi.nix' <<<"$files" && fail "classified file is listed as unclassified"

inputs=$(sed -n '/^<summary>Входы flake<\/summary>$/,/^<\/details>$/p' "$work/a/notes.md")
[[ $inputs == "<summary>Входы flake</summary>

| Вход | Было | Стало |
| --- | --- | --- |
| **nixpkgs** | 2026-01-01 | 2026-02-01 |
| noctalia | 2026-01-05 | 2026-01-05 |
| **old-input** | 2025-12-01 |  |
| **sops-nix** |  | 2026-02-02 |

</details>" ]] || fail "flake inputs table is wrong: $inputs"

packages_table=$(sed -n '/^<summary>Пакеты<\/summary>$/,/^<\/details>$/p' "$work/a/notes.md")
[[ $packages_table == "<summary>Пакеты</summary>

| Пакет | Хост | Было | Стало |
| --- | --- | --- | --- |
| curl | alpha | 8.0 |  |
| fd | beta |  | 10.2 |
| ghost | alpha |  | 1.0 |
| git | alpha | 2.50 | 2.51 |
| hello | beta |  | 2.12 |
| htop | gamma |  | 3.4 |
| iterm2 | gamma |  | 3.5 |
| ripgrep | alpha |  | 14.1 |
| xterm | alpha | 390 |  |
| zed | alpha |  | 0.200 |

</details>" ]] || fail "packages table is wrong: $packages_table"

"$bundle" --version v25.11.1 "" start "$work/first" >/dev/null
[[ $(grep -v '^$' "$work/first/notes.md" | sed -n 2p) == '![alpha](apps-alpha.png)' ]] || fail "notes without --story have text between the card and the grids"

for n in 1 2 3 4 5; do printf 'Абзац %s.\n\n' "$n"; done >"$work/five"
"$bundle" --version v25.11.2 --story "$work/five" start HEAD "$work/five-out" >/dev/null 2>"$work/five-err" && fail "a story of 5 paragraphs is accepted"
grep -qF 'at most 4' "$work/five-err" || fail "rejecting 5 paragraphs does not say the limit: $(cat "$work/five-err")"
head -8 "$work/five" >"$work/four"
"$bundle" --version v25.11.2 --story "$work/four" start HEAD "$work/four-out" >/dev/null || fail "a story of 4 paragraphs is rejected"
printf 'Слово %.0s' {1..300} >"$work/long"
"$bundle" --version v25.11.2 --story "$work/long" start HEAD "$work/long-out" >/dev/null 2>"$work/long-err" && fail "a story over 1500 characters is accepted"
grep -qF 'at most 1500' "$work/long-err" || fail "rejecting a long story does not say the limit: $(cat "$work/long-err")"
[[ -s $work/first/card.png ]] || fail "first release has no card"
blocks_in_order "$work/first/notes.md" \
  '![v25.11.1](card.png)' \
  '![alpha](apps-alpha.png)' \
  '<summary>Пакеты</summary>' '</details>' \
  '<summary>Хосты и модули</summary>' '![Хосты и модули](matrix.png)' '</details>' \
  '<summary>Входы flake</summary>' '</details>'
grep -qF 'Commits by area' "$work/first/notes.md" && fail "first release renders the commit log"
first_inputs=$(sed -n '/^<summary>Входы flake<\/summary>$/,/^<\/details>$/p' "$work/first/notes.md")
[[ $first_inputs == "<summary>Входы flake</summary>

| Вход | Дата |
| --- | --- |
| nixpkgs | 2026-01-01 |
| noctalia | 2026-01-05 |
| old-input | 2025-12-01 |

</details>" ]] || fail "first release inputs table is wrong: $first_inputs"

first_packages=$(sed -n '/^<summary>Пакеты<\/summary>$/,/^<\/details>$/p' "$work/first/notes.md")
[[ $first_packages == "<summary>Пакеты</summary>

| Пакет | Хост | Версия |
| --- | --- | --- |
| curl | alpha | 8.0 |
| firefox | alpha | 130 |
| git | alpha | 2.50 |
| kitty | alpha | 0.40 |
| xterm | alpha | 390 |

</details>" ]] || fail "first release packages table is wrong: $first_packages"

if [[ ${UPDATE_GOLDEN:-} == 1 ]]; then
  mkdir -p "$golden"
  cp "$work/a/card.png" "$golden/card-diff.png"
  cp "$work/first/card.png" "$golden/card-first.png"
  cp "$work/a/apps-alpha.png" "$golden/apps-alpha-diff.png"
  cp "$work/a/apps-gamma.png" "$golden/apps-gamma-diff.png"
  cp "$work/first/apps-alpha.png" "$golden/apps-alpha-first.png"
  cp "$work/a/matrix.png" "$golden/matrix-diff.png"
  cp "$work/first/matrix.png" "$golden/matrix-first.png"
fi
cmp -s "$work/a/card.png" "$golden/card-diff.png" || fail "card with changes differs from testdata/card-diff.png"
cmp -s "$work/first/card.png" "$golden/card-first.png" || fail "first release card differs from testdata/card-first.png"
cmp -s "$work/a/apps-alpha.png" "$golden/apps-alpha-diff.png" || fail "app grid with changes differs from testdata/apps-alpha-diff.png"
cmp -s "$work/a/apps-gamma.png" "$golden/apps-gamma-diff.png" || fail "darwin app grid differs from testdata/apps-gamma-diff.png"
cmp -s "$work/first/apps-alpha.png" "$golden/apps-alpha-first.png" || fail "first release app grid differs from testdata/apps-alpha-first.png"
cmp -s "$work/a/matrix.png" "$golden/matrix-diff.png" || fail "matrix with changes differs from testdata/matrix-diff.png"
cmp -s "$work/first/matrix.png" "$golden/matrix-first.png" || fail "first release matrix differs from testdata/matrix-first.png"

"$bundle" "" start "$work/auto" >/dev/null
git tag v25.11.1 start
"$bundle" start HEAD "$work/auto2" >"$work/auto2-out"
grep -qxF 'version: v25.11.2' "$work/auto2-out" || fail "builder does not print the computed version: $(cat "$work/auto2-out")"
[[ $(head -1 "$work/auto/notes.md") == '![v25.11.1](card.png)' ]] || fail "first version in a branch is not .1"
[[ $(head -1 "$work/auto2/notes.md") == '![v25.11.2](card.png)' ]] || fail "version does not follow the last tag of the branch"

((failed == 0)) && echo "all tests passed"
exit "$failed"
