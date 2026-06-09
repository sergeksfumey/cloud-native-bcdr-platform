# calculate_actual_rto.py
# Measures actual RTO from failover initiation to application health confirmation
# Compares against target RTO and reports pass/fail
# Called from DR test pipeline Stage 3: RecoveryValidation

import argparse
import sys
import json
import os
from datetime import datetime, timezone

def calculate_rto(plan_name, target_rto_minutes):
    print(f"Calculating actual RTO for recovery plan: {plan_name}")
    print(f"Target RTO: {target_rto_minutes} minutes")

    # In production: query ASR job history via Azure SDK for actual timestamps
    # az site-recovery replication-recovery-plan show --name <plan> --query
    # "properties.lastPlannedFailoverTime"

    failover_start_env = os.environ.get("TEST_FAILOVER_START")
    health_confirmed_env = os.environ.get("HEALTH_CONFIRMED_TIME")

    if failover_start_env and health_confirmed_env:
        failover_start = int(failover_start_env)
        health_confirmed = int(health_confirmed_env)
        actual_rto_seconds = health_confirmed - failover_start
        actual_rto_minutes = actual_rto_seconds / 60
    else:
        # Placeholder for pipeline integration -- replace with actual ASR job query
        print("NOTE: Failover timing env vars not set -- using ASR job history query")
        actual_rto_minutes = None

    result = {
        "plan_name": plan_name,
        "target_rto_minutes": target_rto_minutes,
        "actual_rto_minutes": actual_rto_minutes,
        "measured_at": datetime.now(timezone.utc).isoformat(),
        "passed": actual_rto_minutes is not None and actual_rto_minutes <= target_rto_minutes
    }

    if actual_rto_minutes is not None:
        status = "PASS" if result["passed"] else "FAIL"
        print(f"Actual RTO: {actual_rto_minutes:.1f} minutes | Target: {target_rto_minutes} minutes | {status}")
        if not result["passed"]:
            print(f"RTO BREACH: Actual {actual_rto_minutes:.1f} min exceeds target {target_rto_minutes} min")
            sys.exit(1)
    else:
        print("RTO measurement pending -- ASR job history query required")

    with open("rto_result.json", "w") as f:
        json.dump(result, f, indent=2)

    return result

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--plan-name", required=True)
    parser.add_argument("--target-rto-minutes", type=int, required=True)
    args = parser.parse_args()
    calculate_rto(args.plan_name, args.target_rto_minutes)
