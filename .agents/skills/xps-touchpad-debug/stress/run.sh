#!/usr/bin/env bash
set -u
OUT=${1:?usage: run.sh OUT_DIR [default|t2a|ec]}
PLAN=${2:-default}
HERE=$(cd "$(dirname "$0")" && pwd)
PY=${PYTHON:-python3}
mkdir -p "$OUT"

step() {
  local name=$1; shift
  echo "=== $(date '+%F %T') $name: $*"
  "$PY" "$HERE/stress.py" "$name" --out "$OUT/$name" "$@"
  local rc=$?
  echo "=== $(date '+%F %T') $name exit $rc"
  if [ "$rc" -ne 0 ]; then
    chown -R 1000:100 "$OUT"
    [ "$rc" -eq 3 ] && echo "HANG: plan stopped at $name, recovery requires manual hibernate"
    echo "plan stopped at $name"
    exit "$rc"
  fi
}

case "$PLAN" in
  default)
    step t2a --cycles 100 --idle 2
    step t2b --cycles 100 --sleep 10 --bind-delay 1
    ;;
  t2a) step t2a --cycles 100 --idle 2 ;;
  ec) step t3 --cycles 40 --sleep 10 ;;
  *) echo "unknown plan: $PLAN" >&2; exit 64 ;;
esac
chown -R 1000:100 "$OUT"
echo "plan done"
