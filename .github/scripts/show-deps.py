#!/usr/bin/env python3
"""Validate Helm dependency charts declared in Chart.lock or Chart.yaml.

This script is intended to be run from the repository root in CI.
"""
import sys
import subprocess
import urllib.parse
import re
from pathlib import Path

try:
    import yaml
except Exception as exc:
    print("PyYAML is required. Install with: pip3 install pyyaml")
    raise


def load_chart():
    for fname in ("Chart.lock", "Chart.yaml"):
        try:
            with open(fname, "r") as f:
                return yaml.safe_load(f)
        except FileNotFoundError:
            continue
    return None


def main():
    chart_root = Path.cwd()
    data = load_chart()
    if not data:
        print("No Chart.lock or Chart.yaml found; skipping dependency chart validation")
        return 0

    deps = data.get("dependencies") or []
    if not deps:
        print("No dependencies found in chart file")
        return 0

    aliases = []
    for d in deps:
        name = d.get("name")
        version = d.get("version")
        repo = d.get("repository") or d.get("url") or d.get("repo")
        if not name or not repo:
            raise SystemExit(f"Invalid dependency entry, missing name or repository: {d}")
        if repo.startswith("file://"):
            raw_path = repo.removeprefix("file://")
            local_path = Path(raw_path).expanduser()
            if not local_path.is_absolute():
                local_path = (chart_root / local_path).resolve()
            else:
                local_path = local_path.resolve()
            if not local_path.exists():
                raise SystemExit(f"Local dependency chart not found: {repo} -> {local_path}")
            aliases.append((None, str(local_path), name, version, True))
            continue

        parsed = urllib.parse.urlparse(repo)
        if parsed.netloc:
            raw = parsed.netloc + parsed.path
        else:
            raw = repo
        alias = re.sub(r"[^A-Za-z0-9._-]+", "-", raw).strip("-")
        if not version:
            raise SystemExit(f"Remote dependency is missing a pinned version: {name} from {repo}")
        aliases.append((alias, repo, name, version, False))

    remote_aliases = []
    for alias, repo, name, version, is_local in aliases:
        if is_local:
            continue
        print(f"Adding repo {alias} -> {repo}")
        subprocess.run(["helm", "repo", "add", alias, repo], check=False)
        remote_aliases.append(alias)

    if remote_aliases:
        subprocess.run(["helm", "repo", "update", *remote_aliases], check=False)

    for alias, repo, name, version, is_local in aliases:
        print('\n--- Validating dependency chart {} (source: {}) ---'.format(name, repo))
        if is_local:
            cmd = ["helm", "template", name, repo]
        else:
            cmd = ["helm", "template", name, f"{alias}/{name}", "--version", str(version)]
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        if p.returncode != 0:
            print(p.stdout)
            raise SystemExit(f"Dependency chart validation failed for {name} ({repo})")
        print(f"Validated dependency chart {name}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
