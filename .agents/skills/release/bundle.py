#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
AREAS = ["Desktop", "Harness", "Editors", "Dev", "System", "Hosts", "Docs", "Other"]
NIXOS_BASE = re.compile(r'nixpkgs\.url\s*=\s*"github:NixOS/nixpkgs/nixos-(\d\d\.\d\d)"')


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def glob_regex(pattern):
    out = ""
    for token in re.split(r"(\*\*/|\*\*|\*)", pattern):
        if token == "**/":
            out += "(?:.*/)?"
        elif token == "**":
            out += ".*"
        elif token == "*":
            out += "[^/]*"
        else:
            out += re.escape(token)
    return re.compile(out + r"\Z")


def load_areas():
    rules = []
    for line in (HERE / "areas.tsv").read_text().splitlines():
        if line.strip():
            area, pattern = line.split("\t")
            if area not in AREAS:
                sys.exit(f"areas.tsv: unknown area {area!r}, expected one of {', '.join(AREAS)}")
            rules.append((area, glob_regex(pattern)))
    return rules


def area_of(path, rules):
    return next((area for area, regex in rules if regex.match(path)), "Other")


def nixos_base(target):
    match = NIXOS_BASE.search(git("show", f"{target}:nixos/flake.nix"))
    if not match:
        sys.exit("nixpkgs input in nixos/flake.nix does not point at a nixos-YY.MM branch")
    return match.group(1)


def next_version(base):
    numbers = [int(tag.rsplit(".", 1)[1]) for tag in git("tag", "--list", f"v{base}.*").split() if tag.rsplit(".", 1)[1].isdigit()]
    return f"v{base}.{max(numbers, default=0) + 1}"


def commits(prev, target):
    log = git("log", "--no-merges", "--format=%x00%h%x09%s", "--name-only", f"{prev}..{target}" if prev else target)
    for entry in log.split("\0")[1:]:
        header, _, files = entry.partition("\n")
        sha, _, subject = header.partition("\t")
        yield sha, subject, [f for f in files.splitlines() if f]


def group(prev, target):
    rules = load_areas()
    by_area = {area: [] for area in AREAS}
    unclassified = set()
    total = 0
    for sha, subject, files in commits(prev, target):
        total += 1
        file_areas = {f: area_of(f, rules) for f in files}
        areas = set(file_areas.values()) or {"Other"}
        unclassified.update(f for f, area in file_areas.items() if area == "Other")
        for area in AREAS:
            if area in areas:
                by_area[area].append((sha, subject))
    return total, by_area, sorted(unclassified)


def render_card(data, out):
    subprocess.run(
        [
            "typst", "compile",
            "--ignore-system-fonts",
            "--format", "png",
            "--ppi", "144",
            "--input", "data=" + json.dumps(data, sort_keys=True),
            str(HERE / "card.typ"),
            str(out / "card.png"),
        ],
        check=True,
    )


def notes(version, prev, by_area, unclassified):
    lines = [f"![{version}](card.png)", ""]
    if not prev:
        return "\n".join(lines)
    lines += ["<details>", "<summary>Commits by area</summary>", ""]
    for area in AREAS:
        if by_area[area]:
            lines += [f"### {area}", ""] + [f"- `{sha}` {subject}" for sha, subject in by_area[area]] + [""]
    if unclassified:
        lines += ["#### Files without an area", ""] + [f"- `{f}`" for f in unclassified] + [""]
    lines += ["</details>", ""]
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Build a release bundle: notes.md and card.png")
    parser.add_argument("--version")
    parser.add_argument("prev", help="previous release ref, empty for the first release")
    parser.add_argument("target")
    parser.add_argument("out", type=Path)
    args = parser.parse_args()
    if "TYPST_FONT_PATHS" not in os.environ:
        sys.exit("run inside the release devshell: nix develop ~/dotfiles/nixos#release")

    base = nixos_base(args.target)
    version = args.version or next_version(base)
    total, by_area, unclassified = group(args.prev, args.target)
    args.out.mkdir(parents=True, exist_ok=True)
    render_card(
        {
            "version": version,
            "date": git("log", "-1", "--format=%cs", args.target).strip(),
            "base": f"NixOS {base}",
            "range": f"{git('rev-parse', '--short', args.prev).strip()}..{git('rev-parse', '--short', args.target).strip()}" if args.prev else "first release",
            "commits": total,
            "areas": [[area, len(by_area[area])] for area in AREAS],
        },
        args.out,
    )
    (args.out / "notes.md").write_text(notes(version, args.prev, by_area, unclassified))
    for f in unclassified if args.prev else []:
        print(f"unclassified: {f}")


if __name__ == "__main__":
    main()
