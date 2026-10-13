#!/usr/bin/env python3
"""Isolated suites with timings, bounded waits and durable failure logs."""
import argparse
import json
import os
from pathlib import Path
import platform
import signal
import subprocess
import sys
import tempfile
import time

from plan import CORE, ROOT, catalog, make_plan
sys.path.insert(0, str(ROOT / "tests"))
from fixture import create as create_fixture


def definitions(target, tools, contracts):
    if target == "base":
        return [("static", [sys.executable, str(ROOT / "tests/static.py"), str(ROOT)]),
                ("ci-contracts", [sys.executable, "-m", "unittest", "discover", "-s", str(ROOT / "tests/ci"), "-v"])]
    if target in CORE:
        suites = []
        for filename in CORE[target]:
            if filename == "completion.zsh":
                command = ["zsh", "-f", str(ROOT / "tests/helpers/completion.zsh"), "{fixture}", "mst", str(ROOT / "tests/core/completion.zsh")]
            else:
                shell = ["zsh", "-f"] if filename.endswith(".zsh") else ["sh"]
                command = shell + [str(ROOT / "tests/core" / filename), "{fixture}"]
            suites.append((filename.rsplit(".", 1)[0], command))
        return suites
    if target == "integration":
        return [("loading", ["zsh", "-f", str(ROOT / "tests/integration/loading.zsh"), str(ROOT)])]
    if target == "contracts":
        return [(f"package-{name}", ["sh", str(ROOT / "tests/helpers/package.sh"), "{tool_fixture:" + name + "}", name]) for name in contracts]
    if target.startswith("tool-") and target[5:] in tools:
        name = target[5:]
        directory = ROOT / "tests/tools" / name
        suites = [("behavior", ["zsh", "-f", str(directory / "behavior.zsh"), str(ROOT)]),
                  ("completion", ["zsh", "-f", str(ROOT / "tests/helpers/completion.zsh"), str(ROOT), name, str(directory / "completion.zsh")]),
                  ("package", ["sh", str(ROOT / "tests/helpers/package.sh"), "{tool_fixture:" + name + "}", name])]
        if (directory / "install.sh").is_file():
            suites.append(("install", ["sh", str(directory / "install.sh"), "{tool_fixture:" + name + "}"]))
        return suites
    raise ValueError(f"Unknown test target: {target}")


def expected_suites(target, plan):
    return [name for name, _ in definitions(target, plan["tools"], plan["contracts"])]


def execute(command, env, log_path, timeout):
    with log_path.open("w") as output:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        try:
            return process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid, signal.SIGTERM)
            try:
                process.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
            output.write(f"\nFAIL timeout: exceeded {timeout} seconds\n")
            return 124


def annotation(text):
    return text.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def run_target(target, plan, report_root, runner_platform, timeout=240):
    report = report_root / f"{runner_platform}-{target}"
    report.mkdir(parents=True, exist_ok=True)
    suites = definitions(target, plan["tools"], plan["contracts"])
    result = {"schema": 1, "head": plan["head"], "target": target, "platform": runner_platform,
              "expected": [name for name, _ in suites], "suites": [], "status": "failed"}
    started = time.monotonic()
    try:
        with tempfile.TemporaryDirectory(prefix="mst-tests-") as temporary:
            isolated = Path(temporary)
            fixtures = {}
            for suite, command in suites:
                suite_start = time.monotonic()
                suite_directory = report / suite
                suite_directory.mkdir(exist_ok=True)
                suite_root = isolated / suite
                (suite_root / "home").mkdir(parents=True)
                (suite_root / "tmp").mkdir()
                env = os.environ.copy()
                env.update(HOME=str(suite_root / "home"), TMPDIR=str(suite_root / "tmp"),
                           XDG_CONFIG_HOME="", ZDOTDIR="", MST_LANG="", RUNZSH="no",
                           MST_TEST_ARTIFACT_DIR=str(suite_directory))
                expanded = []
                for arg in command:
                    if arg == "{fixture}" or arg.startswith("{tool_fixture:"):
                        # Namespace fixtures so a valid tool named "core" cannot
                        # accidentally receive the manager's synthetic package.
                        if arg == "{fixture}":
                            key, tool_name = "core-fixture", None
                        else:
                            tool_name = arg[len("{tool_fixture:"):-1]
                            key = "tool-fixture-" + tool_name
                        if key not in fixtures:
                            fixtures[key] = create_fixture(ROOT, isolated / key, tool_name)
                        expanded.append(str(fixtures[key]))
                    else:
                        expanded.append(arg)
                status = execute(expanded, env, suite_directory / "output.log", timeout)
                duration = round(time.monotonic() - suite_start, 3)
                result["suites"].append({"name": suite, "status": "passed" if status == 0 else "failed", "exit_code": status, "seconds": duration})
                content = (suite_directory / "output.log").read_text(errors="replace")
                print(f"{'PASS' if status == 0 else 'FAIL'} {target}/{suite}: {duration:.2f}s", flush=True)
                if status:
                    tail = "\n".join(content.splitlines()[-60:])
                    print(tail, flush=True)
                    if os.environ.get("GITHUB_ACTIONS"):
                        print(f"::error title={target}/{suite}::{annotation(tail[-6000:])}", flush=True)
                else:
                    for line in content.splitlines():
                        if line.startswith(("PASS", "SKIP")):
                            print("  " + line, flush=True)
            if len(result["suites"]) == len(suites) and all(item["status"] == "passed" for item in result["suites"]):
                result["status"] = "passed"
    except Exception as error:
        result["error"] = str(error)
        print(f"FAIL {target}: {error}", flush=True)
    finally:
        result["seconds"] = round(time.monotonic() - started, 3)
        (report / "result.json").write_text(json.dumps(result, indent=2) + "\n")
        if os.environ.get("GITHUB_STEP_SUMMARY"):
            with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
                summary.write(f"\n**{target}**: {result['status']} ({result['seconds']:.2f}s)\n\n")
                summary.write("| Suite | Result | Seconds |\n|---|---|---:|\n")
                for item in result["suites"]:
                    summary.write(f"| {item['name']} | {item['status']} | {item['seconds']:.2f} |\n")
    return result["status"] == "passed"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--target", action="append", help="base, manager, distribution, language, sessions, integration, contracts, tool-<name>")
    parser.add_argument("--tool", action="append", help="run a tool's behavior, completion, package and optional installation tests")
    parser.add_argument("--report-dir", type=Path, default=ROOT / ".artifacts")
    parser.add_argument("--platform", default="macos-latest" if platform.system() == "Darwin" else "ubuntu-latest")
    args = parser.parse_args()
    if args.plan:
        plan = json.loads(args.plan.read_text())
        actual_head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        if actual_head != plan["head"]:
            parser.error("The plan targets a different commit; generate a new plan for this checkout.")
    else:
        tools = catalog((ROOT / "scripts/tools.list").read_text())
        plan = make_plan([], tools, full_reason="local full validation", platforms=[args.platform])
        plan["contracts"] = tools
        revision = subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True, capture_output=True)
        plan["head"] = revision.stdout.strip() if revision.returncode == 0 else "unknown"
    targets = list(args.target or []) + [f"tool-{name}" for name in args.tool or []]
    if args.tool:
        # A local component run includes the cheap shared checks and assembly.
        targets = ["base"] + targets + ["integration"]
    if not targets:
        targets = ["base"] + [job["id"] for job in plan["jobs"] if job["platform"] == args.platform]
    passed = True
    for target in dict.fromkeys(targets):
        passed = run_target(target, plan, args.report_dir.resolve(), args.platform) and passed
    print(f"Reports: {args.report_dir.resolve()}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
