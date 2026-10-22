#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
AREAS = ["Desktop", "Harness", "Editors", "Dev", "System", "Hosts", "Docs", "Other"]
NIXOS_BASE = re.compile(r'nixpkgs\.url\s*=\s*"github:NixOS/nixpkgs/nixos-(\d\d\.\d\d)"')
FEATURE_EXPORT = re.compile(r"flake\.(?:home|nixos)Modules\.([\w-]+)")
HOST_CONFIG = re.compile(r"flake\.(?:nixos|darwin)Configurations\.([\w-]+)")
MODULE_REF = re.compile(r"(?:home|nixos)Modules\.([\w-]+)")
FEATURES_DIR = "nixos/modules/features/"
HOSTS_DIR = "nixos/modules/hosts/"
PACKAGES_EXPR = """
url:
let
  flake = builtins.getFlake url;
  info = p: let drv = builtins.parseDrvName p.name; in { name = p.pname or drv.name; version = p.version or drv.version; };
  host = c: map info (c.config.environment.systemPackages or [ ] ++ c.config.home-manager.users.dias.home.packages or [ ]);
in
builtins.mapAttrs (_: host) (flake.nixosConfigurations or { } // flake.darwinConfigurations or { })
"""


def git(*args):
    return subprocess.run(["git", *args], check=True, capture_output=True, text=True).stdout


def tree(ref, path):
    return git("ls-tree", "-r", "--name-only", ref, "--", path).splitlines()


def source(ref, path):
    return re.sub(r"#.*", "", git("show", f"{ref}:{path}"))


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


def inventory(ref, rules):
    features = {}
    for path in tree(ref, FEATURES_DIR):
        for name in FEATURE_EXPORT.findall(source(ref, path)):
            features[name] = area_of(path, rules)
    host_files = {}
    for path in tree(ref, HOSTS_DIR):
        host_files.setdefault(path[len(HOSTS_DIR):].split("/")[0], []).append(path)
    hosts = {}
    for paths in host_files.values():
        text = "\n".join(source(ref, path) for path in paths)
        config = HOST_CONFIG.search(text)
        if config:
            hosts[config.group(1)] = {name for name in MODULE_REF.findall(text) if name in features}
    return features, hosts


def matrix(prev, target, rules):
    features, hosts = inventory(target, rules)
    old_features, old_hosts = inventory(prev, rules) if prev else ({}, {})
    areas = {**old_features, **features}
    names = sorted(set().union(*hosts.values(), *old_hosts.values()), key=lambda n: (AREAS.index(areas[n]), n))
    host_names = sorted(set(hosts) | set(old_hosts))

    def state(host, name):
        now = name in hosts.get(host, set())
        if not prev or now == (name in old_hosts.get(host, set())):
            return "on" if now else "off"
        return "added" if now else "removed"

    return {
        "hosts": host_names,
        "rows": [{"module": n, "area": areas[n], "cells": [state(h, n) for h in host_names]} for n in names],
        "diff": bool(prev),
    }


def locked_inputs(ref):
    try:
        lock = json.loads(git("show", f"{ref}:nixos/flake.lock"))
    except subprocess.CalledProcessError:
        return {}
    inputs = {}
    for name, node in lock["nodes"][lock["root"]].get("inputs", {}).items():
        locked = lock["nodes"][node]["locked"] if isinstance(node, str) else {}
        modified = locked.get("lastModified")
        date = datetime.fromtimestamp(modified, timezone.utc).date().isoformat() if modified else ""
        inputs[name] = (date, locked.get("narHash", locked.get("rev")))
    return inputs


def inputs_table(prev, target):
    new = locked_inputs(target)
    if not prev:
        return ["| Input | Date |", "| --- | --- |"] + [f"| {name} | {new[name][0]} |" for name in sorted(new)]
    old = locked_inputs(prev)
    lines = ["| Input | Old | New |", "| --- | --- | --- |"]
    for name in sorted(set(old) | set(new)):
        before, after = old.get(name, ("", None)), new.get(name, ("", None))
        label = name if before[1] == after[1] else f"**{name}**"
        lines.append(f"| {label} | {before[0]} | {after[0]} |")
    return lines


def packages(ref):
    root = git("rev-parse", "--show-toplevel").strip()
    rev = git("rev-parse", f"{ref}^{{commit}}").strip()
    url = f"git+file://{root}?rev={rev}&dir=nixos"
    hosts = json.loads(
        subprocess.run(
            ["nix", "eval", "--json", "--expr", f"({PACKAGES_EXPR}) {json.dumps(url)}"],
            check=True,
            stdout=subprocess.PIPE,
            text=True,
        ).stdout
    )
    versions = {}
    for host, pkgs in hosts.items():
        for pkg in pkgs:
            versions.setdefault((pkg["name"], host), set()).add(pkg["version"])
    return {key: ", ".join(sorted(v)) for key, v in versions.items()}


def packages_table(prev, target):
    new = packages(target)
    if not prev:
        lines = ["| Package | Host | Version |", "| --- | --- | --- |"]
        return {"total": len(new)}, lines + [f"| {name} | {host} | {new[name, host]} |" for name, host in sorted(new)]
    old = packages(prev)
    counts = {"added": 0, "removed": 0, "updated": 0}
    lines = ["| Package | Host | Old | New |", "| --- | --- | --- | --- |"]
    for name, host in sorted(set(old) | set(new)):
        before, after = old.get((name, host)), new.get((name, host))
        if before == after:
            continue
        counts["added" if before is None else "removed" if after is None else "updated"] += 1
        lines.append(f"| {name} | {host} | {before or ''} | {after or ''} |")
    return counts, lines


def render(template, data, png):
    subprocess.run(
        [
            "typst", "compile",
            "--ignore-system-fonts",
            "--format", "png",
            "--ppi", "144",
            "--input", "data=" + json.dumps(data, sort_keys=True),
            str(HERE / template),
            str(png),
        ],
        check=True,
    )


def details(summary, body):
    return ["<details>", f"<summary>{summary}</summary>", "", *body, "", "</details>", ""]


def notes(version, prev, package_lines, has_matrix, inputs, by_area, unclassified):
    lines = [f"![{version}](card.png)", ""]
    lines += details("Packages", package_lines)
    if has_matrix:
        lines += details("Hosts × modules", ["![Hosts × modules](matrix.png)"])
    lines += details("Flake inputs", inputs)
    if prev:
        log = []
        for area in AREAS:
            if by_area[area]:
                log += [f"### {area}", ""] + [f"- `{sha}` {subject}" for sha, subject in by_area[area]] + [""]
        if unclassified:
            log += ["#### Files without an area", ""] + [f"- `{f}`" for f in unclassified]
        lines += details("Commits by area", log)
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Build a release bundle: notes.md and its PNG images")
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
    package_counts, package_lines = packages_table(args.prev, args.target)
    args.out.mkdir(parents=True, exist_ok=True)
    render(
        "card.typ",
        {
            "version": version,
            "date": git("log", "-1", "--format=%cs", args.target).strip(),
            "base": f"NixOS {base}",
            "range": f"{git('rev-parse', '--short', args.prev).strip()}..{git('rev-parse', '--short', args.target).strip()}" if args.prev else "first release",
            "commits": total,
            "packages": package_counts,
            "areas": [[area, len(by_area[area])] for area in AREAS],
        },
        args.out / "card.png",
    )
    host_matrix = matrix(args.prev, args.target, load_areas())
    if host_matrix["rows"]:
        render("matrix.typ", host_matrix, args.out / "matrix.png")
    inputs = inputs_table(args.prev, args.target)
    (args.out / "notes.md").write_text(notes(version, args.prev, package_lines, bool(host_matrix["rows"]), inputs, by_area, unclassified))
    for f in unclassified if args.prev else []:
        print(f"unclassified: {f}")


if __name__ == "__main__":
    main()
