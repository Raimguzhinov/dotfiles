#!/usr/bin/env bash
set -euo pipefail

if (($# != 3)); then
  echo "usage: draft.sh VERSION OUT TARGET" >&2
  exit 2
fi
version=$1 out=$2 target=$(git rev-parse "$3^{commit}")

notes=$(mktemp)
trap 'rm -f "$notes"' EXIT

gh release create "$version" "$out"/*.png \
  --draft \
  --target "$target" \
  --title "$version" \
  --notes-file "$out/notes.md"

asset=$(gh release view "$version" --json assets --jq '.assets[0].url')
base=${asset%/*}
sed -E "s#\]\(([A-Za-z0-9._-]+\.png)\)#]($base/\1)#g" "$out/notes.md" >"$notes"
gh release edit "$version" --notes-file "$notes"
gh release view "$version" --json url --jq .url
