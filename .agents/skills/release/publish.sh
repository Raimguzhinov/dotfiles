#!/usr/bin/env bash
set -euo pipefail

if (($# != 3)); then
  echo "usage: publish.sh VERSION TARGET OUT" >&2
  exit 2
fi
version=$1 out=$3
target=$(git rev-parse "$2^{commit}")

if git rev-parse -q --verify "refs/tags/$version" >/dev/null; then
  if [[ $(git rev-parse "$version^{commit}") != "$target" ]]; then
    echo "$version already points at another commit" >&2
    exit 1
  fi
else
  git tag -s "$version" -m "$version" "$target"
fi
git tag -v "$version"
git push origin "refs/tags/$version"

notes=$(mktemp)
trap 'rm -f "$notes"' EXIT
repo=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
sed -E "s#src=\"([A-Za-z0-9._-]+\.png)\"#src=\"https://github.com/$repo/releases/download/$version/\1\"#g" "$out/notes.md" >"$notes"
gh release create "$version" "$out"/*.png --verify-tag --title "$version" --notes-file "$notes"
