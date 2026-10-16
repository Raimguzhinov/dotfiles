#!/usr/bin/env python3
"""Проверка theme.fg/bg токенов во встроенном TS pi.nix.

Неизвестный токен роняет TUI в живой сессии (headless pi --print футер
не рендерит), поэтому ловим до коммита. Валидный набор — из dist
pi-coding-agent (theme), сверить при обновлении pi.
"""

import re
import sys
from pathlib import Path

VALID = {"accent", "success", "error", "warning", "muted", "dim", "text", "mdLink"}
PATTERN = re.compile(r'theme\.(?:fg|bg)\(\s*["\']([^"\']+)["\']')
DEFAULTS = ("nixos/modules/features/pi.nix",)


def check(path: Path) -> list[str]:
    bad: dict[str, list[int]] = {}
    for line_no, line in enumerate(path.read_text().splitlines(), 1):
        for m in PATTERN.finditer(line):
            tok = m.group(1)
            if tok not in VALID:
                bad.setdefault(tok, []).append(line_no)
    return [
        f"{path}: неизвестный theme-токен {tok!r} (строки {lines})"
        for tok, lines in bad.items()
    ]


def main() -> int:
    names = sys.argv[1:] or list(DEFAULTS)
    errors = [e for name in names for e in check(Path(name))]
    for e in errors:
        print(e, file=sys.stderr)
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
