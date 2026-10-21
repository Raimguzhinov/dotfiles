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
    nodes+="\"$name\": {\"locked\": {\"lastModified\": $ts, \"narHash\": \"sha256-$name-$ts\", \"type\": \"github\"}}, "
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
put nixos/flake.nix <<<'nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";'
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
commit nixos/modules/hosts/beta/notes "nixos: hosts: enable kitty on alpha, add beta" 5

"$bundle" --version v25.11.2 start HEAD "$work/a" >/dev/null
"$bundle" --version v25.11.2 start HEAD "$work/b" >/dev/null

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
  '<summary>Hosts × modules</summary>' '![Hosts × modules](matrix.png)' '</details>' \
  '<summary>Flake inputs</summary>' '</details>' \
  '<summary>Commits by area</summary>' '### Desktop' '### Harness' '### Hosts' '### Docs' '### Other' '#### Files without an area' '</details>'
[[ $(head -1 "$work/a/notes.md") == '![v25.11.2](card.png)' ]] || fail "card is not the first block"
(($(grep -cxF '<details>' "$work/a/notes.md") == 3)) || fail "secondary blocks are not each folded in <details>"

other=$(sed -n '/^### Other$/,/^#### /p' "$work/a/notes.md")
grep -qF 'nixos: unknown.txt: add file' <<<"$other" || fail "commit touching an unclassified file is not under Other"
grep -qF 'nixos: pi.nix: add pi' <<<"$other" && fail "classified commit leaked into Other"
files=$(sed -n '/^#### Files without an area$/,/^<\/details>$/p' "$work/a/notes.md")
grep -qxF -- '- `misc/unknown.txt`' <<<"$files" || fail "unclassified file is not listed"
grep -qF 'pi.nix' <<<"$files" && fail "classified file is listed as unclassified"

inputs=$(sed -n '/^<summary>Flake inputs<\/summary>$/,/^<\/details>$/p' "$work/a/notes.md")
[[ $inputs == "<summary>Flake inputs</summary>

| Input | Old | New |
| --- | --- | --- |
| **nixpkgs** | 2026-01-01 | 2026-02-01 |
| noctalia | 2026-01-05 | 2026-01-05 |
| **old-input** | 2025-12-01 |  |
| **sops-nix** |  | 2026-02-02 |

</details>" ]] || fail "flake inputs table is wrong: $inputs"

"$bundle" --version v25.11.1 "" start "$work/first" >/dev/null
[[ -s $work/first/card.png ]] || fail "first release has no card"
blocks_in_order "$work/first/notes.md" \
  '![v25.11.1](card.png)' \
  '<summary>Hosts × modules</summary>' '![Hosts × modules](matrix.png)' '</details>' \
  '<summary>Flake inputs</summary>' '</details>'
grep -qF 'Commits by area' "$work/first/notes.md" && fail "first release renders the commit log"
first_inputs=$(sed -n '/^<summary>Flake inputs<\/summary>$/,/^<\/details>$/p' "$work/first/notes.md")
[[ $first_inputs == "<summary>Flake inputs</summary>

| Input | Date |
| --- | --- |
| nixpkgs | 2026-01-01 |
| noctalia | 2026-01-05 |
| old-input | 2025-12-01 |

</details>" ]] || fail "first release inputs table is wrong: $first_inputs"

if [[ ${UPDATE_GOLDEN:-} == 1 ]]; then
  mkdir -p "$golden"
  cp "$work/a/matrix.png" "$golden/matrix-diff.png"
  cp "$work/first/matrix.png" "$golden/matrix-first.png"
fi
cmp -s "$work/a/matrix.png" "$golden/matrix-diff.png" || fail "matrix with changes differs from testdata/matrix-diff.png"
cmp -s "$work/first/matrix.png" "$golden/matrix-first.png" || fail "first release matrix differs from testdata/matrix-first.png"

"$bundle" "" start "$work/auto" >/dev/null
git tag v25.11.1 start
"$bundle" start HEAD "$work/auto2" >/dev/null
[[ $(head -1 "$work/auto/notes.md") == '![v25.11.1](card.png)' ]] || fail "first version in a branch is not .1"
[[ $(head -1 "$work/auto2/notes.md") == '![v25.11.2](card.png)' ]] || fail "version does not follow the last tag of the branch"

((failed == 0)) && echo "all tests passed"
exit "$failed"
