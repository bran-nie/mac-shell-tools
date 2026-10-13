"""Build small, fixed manager fixtures; never copy the real tool catalog."""
from __future__ import annotations
import shutil
import subprocess
from pathlib import Path


def create(source: Path, target: Path, real_tool: str | None = None) -> Path:
    for directory in ("lib", "locales"):
        shutil.copytree(source / directory, target / directory)
    (target / "scripts").mkdir()
    (target / "tools").mkdir()
    (target / "tests").mkdir()
    shutil.copy2(source / "tests/common.sh", target / "tests/common.sh")
    for filename in ("VERSION", "LICENSE"):
        shutil.copy2(source / filename, target / filename)
    for filename in ("build-installer.sh", "bootstrap.sh.in", "loader.zsh.in"):
        shutil.copy2(source / "scripts" / filename, target / "scripts" / filename)
    # copy_package also works before the fixture is rebuilt after catalog edits.
    shutil.copy2(source / "tools/init.zsh", target / "tools/init.zsh")
    names = ["sample", "second", "third", "dependent"]
    if real_tool:
        peer = "fixture-peer" if real_tool == "sample" else "sample"
        names = [peer, real_tool]
    for name in names:
        component = target / "tools" / name
        if name == real_tool:
            shutil.copytree(source / "tools" / name, component)
            continue
        (component / "locales").mkdir(parents=True)
        (component / "VERSION").write_text("0.1.0-dev\n")
        templates = {"component.zsh.in": f"{name}.zsh",
                     "en.sh.in": "locales/en.sh", "zh-CN.sh.in": "locales/zh-CN.sh"}
        for template, destination in templates.items():
            content = (source / "tests/fixtures" / template).read_text()
            (component / destination).write_text(content.replace("@TOOL@", name))
        if name == "dependent":
            (component / "dependencies.list").write_text("node\nnpm\n")
    (target / "scripts/tools.list").write_text("".join(f"{name}.zsh\n" for name in names))
    subprocess.run(["sh", str(target / "scripts/build-installer.sh")], check=True)
    return target
