#!/usr/bin/env bash
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd)
bundle="$here/bundle.py"
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

repo="$work/repo"
git init -q "$repo"
cd "$repo"
git config user.name test
git config user.email test@example.com
git config commit.gpgsign false
mkdir -p nixos
printf 'nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";\n' >nixos/flake.nix
git add nixos/flake.nix
commit nixos/modules/features/niri.nix "nixos: niri.nix: add niri" 1
git tag start
commit nixos/modules/features/pi.nix "nixos: pi.nix: add pi" 2
commit nixos/modules/features/kitty.nix "nixos: kitty.nix: add kitty" 2
commit misc/unknown.txt "nixos: unknown.txt: add file" 3
commit docs/adr/0001.md "nixos: 0001.md: add adr" 4

"$bundle" --version v25.11.2 start HEAD "$work/a" >/dev/null
"$bundle" --version v25.11.2 start HEAD "$work/b" >/dev/null

[[ -s $work/a/notes.md ]] || fail "notes.md is missing"
[[ $(head -c 8 "$work/a/card.png" | od -An -tx1 | tr -d ' ') == 89504e470d0a1a0a ]] || fail "card.png is not a PNG"
diff -r "$work/a" "$work/b" >/dev/null || fail "two runs on the same refs differ"

line_of() { grep -nxF -- "$1" "$work/a/notes.md" | head -1 | cut -d: -f1 || true; }
order=(1)
for block in '<details>' '<summary>Commits by area</summary>' '### Desktop' '### Harness' '### Docs' '### Other' '#### Files without an area' '</details>'; do
  n=$(line_of "$block")
  [[ -n $n ]] || { fail "block '$block' is missing"; continue; }
  ((n > order[-1])) || fail "block '$block' is out of order"
  order+=("$n")
done
[[ $(head -1 "$work/a/notes.md") == '![v25.11.2](card.png)' ]] || fail "card is not the first block"

other=$(sed -n '/^### Other$/,/^#### /p' "$work/a/notes.md")
grep -qF 'nixos: unknown.txt: add file' <<<"$other" || fail "commit touching an unclassified file is not under Other"
grep -qF 'nixos: pi.nix: add pi' <<<"$other" && fail "classified commit leaked into Other"
files=$(sed -n '/^#### Files without an area$/,/^<\/details>$/p' "$work/a/notes.md")
grep -qxF -- '- `misc/unknown.txt`' <<<"$files" || fail "unclassified file is not listed"
grep -qF 'pi.nix' <<<"$files" && fail "classified file is listed as unclassified"

"$bundle" --version v25.11.1 "" start "$work/first" >/dev/null
[[ -s $work/first/card.png ]] || fail "first release has no card"
[[ $(cat "$work/first/notes.md") == '![v25.11.1](card.png)' ]] || fail "first release renders more than the card"

"$bundle" "" start "$work/auto" >/dev/null
git tag v25.11.1 start
"$bundle" start HEAD "$work/auto2" >/dev/null
[[ $(head -1 "$work/auto/notes.md") == '![v25.11.1](card.png)' ]] || fail "first version in a branch is not .1"
[[ $(head -1 "$work/auto2/notes.md") == '![v25.11.2](card.png)' ]] || fail "version does not follow the last tag of the branch"

((failed == 0)) && echo "all tests passed"
exit "$failed"
