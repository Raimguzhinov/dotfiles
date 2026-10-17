#!/usr/bin/env bash
# commit-msg: префикс "nixos: " и файл во втором токене должны быть в диффе
set -euo pipefail

subject=$(head -n1 "$1")

if [[ ! "$subject" =~ ^nixos:\  ]]; then
  echo "commit-msg: subject must start with 'nixos: ' (got: $subject)" >&2
  exit 1
fi

ref=${subject#nixos: }
ref=${ref%%:*}
ref=${ref%%[[:space:]]*}

# проверка файла только если второй токен выглядит как имя файла
if [[ "$ref" == *.* && "$ref" != */* ]]; then
  files=$(git diff --cached --name-only)
  if [[ -z "$files" ]]; then
    # reword/amend без новых изменений: дифф переписываемого коммита
    files=$(git show --name-only --format= HEAD 2>/dev/null || true)
  fi
  if ! printf '%s\n' "$files" | awk -F/ -v f="$ref" '{ b = $NF; sub(/^\./, "", b); f2 = f; sub(/^\./, "", f2); if (b == f || b == f2) found = 1 } END { exit found ? 0 : 1 }'; then
    echo "commit-msg: '$ref' from the subject is not among the changed files" >&2
    exit 1
  fi
fi
