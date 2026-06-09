# generate_dr_test_report.py
# Generates DR test report from pipeline stage results
# Report stored in Log Analytics for continuous compliance evidence

import argparse
import json
import os
from datetime import datetime, timezone

def generate_report(plan_name, target_rto_minutes, target_rpo_minutes, output_path):
    print(f"Generating DR test report for: {plan_name}")

    rto_result = {}
    rpo_result = {}

    if os.path.exists("rto_result.json"):
        with open("rto_result.json") as f:
            rto_result = json.load(f)

    if os.path.exists("rpo_result.json"):
        with open("rpo_result.json") as f:
            rpo_result = json.load(f)

    report = {
        "report_generated_at": datetime.now(timezone.utc).isoformat(),
        "recovery_plan": plan_name,
        "test_summary": {
            "target_rto_minutes": target_rto_minutes,
            "target_rpo_minutes": target_rpo_minutes,
            "actual_rto_minutes": rto_result.get("actual_rto_minutes"),
            "actual_rpo_minutes": rpo_result.get("actual_rpo_minutes"),
            "rto_passed": rto_result.get("passed"),
            "rpo_passed": rpo_result.get("passed"),
        },
        "overall_result": "PASS" if (rto_result.get("passed") and rpo_result.get("passed")) else "FAIL/INCOMPLETE",
        "compliance_frameworks": ["ISO 22301", "NIST SP 800-34", "PCI DSS v4.0"],
        "next_test_scheduled": "First business day of next month"
    }

    with open(output_path, "w") as f:
        json.dump(report, f, indent=2)

    print(f"DR test report written to: {output_path}")
    print(f"Overall result: {report['overall_result']}")
    print(f"RTO: {report['test_summary']['actual_rto_minutes']} min (target {target_rto_minutes} min)")
    print(f"RPO: {report['test_summary']['actual_rpo_minutes']} min (target {target_rpo_minutes} min)")

    return report

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan-name", required=True)
    parser.add_argument("--target-rto-minutes", type=int, required=True)
    parser.add_argument("--target-rpo-minutes", type=int, required=True)
    parser.add_argument("--output-path", default="dr-test-report.json")
    args = parser.parse_args()
    generate_report(args.plan_name, args.target_rto_minutes, args.target_rpo_minutes, args.output_path)
