#!/usr/bin/env python3
"""Reject missing, failed, cancelled, duplicate and unexpectedly skipped checks."""
import argparse
import json
from pathlib import Path
from run import expected_suites


def validate(plan, reports, needs):
    errors = []
    expected_jobs = {(job["id"], job["platform"]) for job in plan["jobs"]}
    expected_jobs.add(("base", "macos-latest"))
    for job in ("plan", "base"):
        if needs.get(job, {}).get("result") != "success":
            errors.append(f"{job} did not succeed")
    wanted = "success" if plan["jobs"] else "skipped"
    if needs.get("tests", {}).get("result") != wanted:
        errors.append(f"tests job expected {wanted}")
    seen = set()
    for report in reports:
        identity = (report.get("target"), report.get("platform"))
        if identity not in expected_jobs or identity in seen:
            errors.append(f"unexpected/duplicate result: {identity}")
            continue
        seen.add(identity)
        suites = expected_suites(identity[0], plan)
        actual = report.get("suites", [])
        if report.get("head") != plan["head"] or report.get("status") != "passed":
            errors.append(f"failed/stale result: {identity}")
        if report.get("expected") != suites or [suite.get("name") for suite in actual] != suites:
            errors.append(f"incomplete suite coverage: {identity}")
        if any(suite.get("status") != "passed" or suite.get("exit_code") != 0 for suite in actual):
            errors.append(f"failed suite: {identity}")
    for identity in sorted(expected_jobs - seen):
        errors.append(f"missing result: {identity}")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plan", type=Path, required=True)
    parser.add_argument("--reports", type=Path, required=True)
    parser.add_argument("--needs", required=True)
    args = parser.parse_args()
    plan = json.loads(args.plan.read_text())
    reports = [json.loads(path.read_text()) for path in args.reports.rglob("result.json")]
    errors = validate(plan, reports, json.loads(args.needs))
    for error in errors:
        print("FAIL ci-result: " + error)
    if not errors:
        print(f"PASS ci-result: {len(reports)} required job reports, complete suite coverage.")
    return bool(errors)


if __name__ == "__main__":
    raise SystemExit(main())
