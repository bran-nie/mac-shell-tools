#!/usr/bin/env python3
"""Cheap repository-wide contracts, always run even for documentation changes."""
import ast
from pathlib import Path
import re
import subprocess
import sys

ROOT = Path(sys.argv[1]).resolve()
sys.path.insert(0, str(ROOT / "scripts/ci"))
from plan import catalog


def main():
    tools = catalog((ROOT / "scripts/tools.list").read_text())
    directories = {path.name for path in (ROOT / "tools").iterdir() if path.is_dir()}
    if directories != set(tools):
        raise ValueError(f"Source directories and catalog disagree: {directories ^ set(tools)}")
    for tool in tools:
        for filename in ("behavior.zsh", "completion.zsh"):
            if not (ROOT / "tests/tools" / tool / filename).is_file():
                raise ValueError(f"Missing tests/tools/{tool}/{filename}")
    for directory in ("lib", "locales", "tools", "scripts", "tests"):
        for path in sorted((ROOT / directory).rglob("*")):
            if not path.is_file():
                continue
            # Fixture placeholders are rendered and syntax-checked on creation.
            if path.suffix == ".sh" or path.name == "bootstrap.sh.in":
                subprocess.run(["sh", "-n", str(path)], check=True)
            elif path.suffix == ".zsh" or path.name == "loader.zsh.in":
                subprocess.run(["zsh", "-n", str(path)], check=True)
            elif path.suffix == ".py":
                ast.parse(path.read_text(), filename=str(path))
    subprocess.run(["sh", "-n", str(ROOT / "install.sh")], check=True)
    subprocess.run(["sh", str(ROOT / "scripts/build-installer.sh"), "--check"], check=True)
    locales = [ROOT / "locales"] + [ROOT / "tools" / name / "locales" for name in tools]
    subprocess.run(["sh", str(ROOT / "tests/helpers/locales.sh"), *map(str, filter(Path.is_dir, locales))], check=True)
    # Internal documentation links must remain usable as files move.
    documents = list(ROOT.glob("*.md")) + list((ROOT / "docs").rglob("*.md"))
    for document in documents:
        for destination in re.findall(r"\]\(([^ )]+)(?:\s+[^)]*)?\)", document.read_text()):
            if ":" in destination or destination.startswith("#"):
                continue
            path = destination.split("#", 1)[0]
            if path and not (document.parent / path).exists():
                raise ValueError(f"Broken link: {document.relative_to(ROOT)} -> {path}")
    print(f"PASS static: syntax, generated loader/provenance, {len(tools)} component contracts and documentation links.")


if __name__ == "__main__":
    main()
