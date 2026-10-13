#!/usr/bin/env python3
"""Conservative impact planning from Git history, not generated version numbers."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
CORE = {
    "manager": ["install.sh", "management.sh", "mst.sh"],
    "distribution": ["repository.sh", "migration.sh", "tool-versions.sh"],
    "language": ["versions-language.sh", "completion.zsh"],
    "sessions": ["platform.sh", "sessions.zsh"],
}


def git(*args, root=ROOT):
    return subprocess.check_output(["git", "-C", str(root), *args])


def catalog(text):
    files = text.split()
    if not files or len(set(files)) != len(files):
        raise ValueError("Empty or duplicate tool catalog")
    for name in files:
        if not re.fullmatch(r"[a-z0-9][a-z0-9-]*\.zsh", name) or name in ("mst.zsh", "init.zsh"):
            raise ValueError(f"Invalid tool: {name}")
    return [name[:-4] for name in files]


def changed_paths(base, head, root=ROOT):
    # --name-status retains both sides of renames and all deleted paths.
    fields = git("diff", "--name-status", "-z", "-M", base, head, root=root).decode().split("\0")
    paths = set()
    while fields and fields[0]:
        status = fields.pop(0)
        paths.add(fields.pop(0))
        if status.startswith(("R", "C")):
            paths.add(fields.pop(0))
    return sorted(paths)


def successful_base(head, root=ROOT):
    """Use the most recent successful push of this workflow on an ancestor."""
    repository = os.environ.get("GITHUB_REPOSITORY")
    token = os.environ.get("GITHUB_TOKEN")
    if not repository or not token:
        return None
    query = urllib.parse.urlencode({"branch": "main", "event": "push", "status": "success", "per_page": 50})
    url = f"https://api.github.com/repos/{repository}/actions/workflows/ci.yml/runs?{query}"
    request = urllib.request.Request(url, headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
    try:
        with urllib.request.urlopen(request, timeout=20) as response:
            runs = json.load(response)["workflow_runs"]
        for run in runs:
            candidate = run["head_sha"]
            # Never use the current run or a different history after force-push.
            if candidate == head or run["id"] == int(os.environ.get("GITHUB_RUN_ID", "0")):
                continue
            ancestry = subprocess.run(["git", "-C", str(root), "merge-base", "--is-ancestor", candidate, head],
                                      stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            if ancestry.returncode == 0:
                return candidate
    except (OSError, ValueError, KeyError, urllib.error.URLError):
        pass
    # Rate limits, missing history or no previous success must expand coverage.
    return None


def make_plan(paths, tools, previous_tools=None, full_reason=None, platforms=None):
    previous_tools = tools if previous_tools is None else previous_tools
    platforms = platforms or ["macos-latest"]
    selected = {}
    contract_tools = set()

    def select(target, reason):
        selected.setdefault(target, [])
        if reason not in selected[target]:
            selected[target].append(reason)

    def all_tests(reason):
        for group in CORE:
            select(group, reason)
        for name in tools:
            select(f"tool-{name}", reason)
        select("integration", reason)

    def manager_tests(reason):
        for group in CORE:
            select(group, reason)
        contract_tools.update(tools)
        select("integration", reason)

    if full_reason:
        all_tests(full_reason)
    added = set(tools) - set(previous_tools)
    removed = set(previous_tools) - set(tools)
    for name in sorted(added):
        select(f"tool-{name}", "new catalog component")
    if added or removed:
        manager_tests("catalog added/removed components")
    owners = {f"tests/core/{file}": group for group, files in CORE.items() for file in files}
    for path in paths:
        if path.startswith("docs/") or path in ("README.md", "README-cn.md", "CHANGELOG.md"):
            continue
        if path == "scripts/tools.list":
            select("integration", "catalog registration/order")
            continue
        if path in ("install.sh", "package.meta", "tools/init.zsh"):
            # Generated consistency and catalog validity are always checked by base.
            continue
        parts = path.split("/")
        component = None
        if len(parts) >= 3 and parts[0] == "tools":
            component = parts[1]
        if len(parts) >= 4 and parts[:2] == ["tests", "tools"]:
            component = parts[2]
        if component is not None:
            if component in tools:
                if path != f"tools/{component}/package.meta":
                    select(f"tool-{component}", path)
                    select("integration", "component loading contract")
            elif component in removed:
                manager_tests(f"removed component: {component}")
            else:
                all_tests(f"unknown component path: {path}")
            continue
        if path in owners:
            select(owners[path], path)
        elif path.startswith("locales/"):
            select("language", path)
        elif path in ("lib/manager.sh", "lib/repository.sh", "lib/mst.zsh"):
            manager_tests(path)
        else:
            # Includes i18n, loader template, builder, bootstrap, shared fixtures,
            # planner/runner/workflow changes and any unclassified future files.
            all_tests(f"shared or unclassified: {path}")
    contract_tools.difference_update(name for name in tools if f"tool-{name}" in selected)
    if contract_tools:
        select("contracts", "real components against changed manager/catalog")
    jobs = [{"id": target, "platform": platform} for target in sorted(selected) for platform in platforms]
    skipped = {f"tool-{name}": "no affected source, test or shared dependency"
               for name in tools if f"tool-{name}" not in selected}
    return {"schema": 1, "paths": sorted(paths), "tools": tools,
            "contracts": sorted(contract_tools), "reasons": selected, "skipped": skipped,
            "jobs": jobs, "matrix": {"include": jobs}, "full_reason": full_reason}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base")
    parser.add_argument("--head", default="HEAD")
    parser.add_argument("--event", default="local", choices=["local", "push", "pull_request", "workflow_dispatch", "schedule", "release"])
    parser.add_argument("--full", action="store_true")
    parser.add_argument("--platform", action="append", choices=["macos-latest", "ubuntu-latest"])
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    head = git("rev-parse", args.head).decode().strip()
    tools = catalog((ROOT / "scripts/tools.list").read_text())
    base, previous, paths = args.base, tools, []
    reason = None
    if args.full or args.event in ("workflow_dispatch", "schedule", "release"):
        reason = "explicit full validation"
    elif args.event == "push":
        # The previous push alone can omit source changes whose run failed or
        # was cancelled; include everything since a successful ancestor instead.
        base = successful_base(head)
    if not reason:
        try:
            if not base:
                raise ValueError("No verified baseline")
            if args.event == "pull_request":
                base = git("merge-base", base, head).decode().strip()
            git("merge-base", "--is-ancestor", base, head)
            paths = changed_paths(base, head)
            previous = catalog(git("show", f"{base}:scripts/tools.list").decode())
        except (subprocess.CalledProcessError, ValueError):
            reason = "missing/unusable verified baseline; conservative full validation"
    plan = make_plan(paths, tools, previous, reason, args.platform)
    plan.update({"head": head, "base": base, "event": args.event})
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(plan, indent=2, ensure_ascii=False) + "\n")
    print(json.dumps(plan, indent=2, ensure_ascii=False))
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a") as output:
            output.write("matrix=" + json.dumps(plan["matrix"]) + "\n")
            output.write("has_jobs=" + str(bool(plan["jobs"])).lower() + "\n")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
            summary.write(f"Diff baseline: `{base or 'full'}` → `{head}`\n\n")
            for target, reasons in plan["reasons"].items():
                summary.write(f"- **{target}**: {', '.join(reasons)}\n")
            for target, why in plan["skipped"].items():
                summary.write(f"- Skipped {target}: {why}\n")


if __name__ == "__main__":
    main()
