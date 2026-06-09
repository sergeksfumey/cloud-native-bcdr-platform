# validate_application_health.py
# Validates application health endpoints on recovered VMs
# Called from DR test pipeline Stage 3: RecoveryValidation
# NOTE: Test failover runs in isolated network -- validates startup health only,
# not full production connectivity (external APIs, DNS, on-premises systems)

import argparse
import sys
import time
import urllib.request
import urllib.error
import json
from datetime import datetime, timezone

def validate_health(environment, expected_status, timeout_seconds, endpoints=None):
    if endpoints is None:
        # Default endpoints for isolated test failover validation
        endpoints = [
            "http://10.1.0.10/health",
            "http://10.1.0.11/health",
        ]

    start_time = time.time()
    results = []

    print(f"[{datetime.now(timezone.utc).isoformat()}] Validating {len(endpoints)} health endpoints")
    print(f"Environment: {environment} | Expected status: {expected_status} | Timeout: {timeout_seconds}s")

    for endpoint in endpoints:
        elapsed = time.time() - start_time
        if elapsed > timeout_seconds:
            results.append({"endpoint": endpoint, "status": "timeout", "passed": False})
            continue

        retries = 0
        max_retries = 5
        passed = False

        while retries < max_retries:
            try:
                req = urllib.request.Request(endpoint, method="GET")
                req.add_header("User-Agent", "DR-Test-Validator/1.0")
                with urllib.request.urlopen(req, timeout=30) as response:
                    actual_status = response.getcode()
                    passed = (actual_status == expected_status)
                    results.append({
                        "endpoint": endpoint,
                        "status": actual_status,
                        "passed": passed,
                        "retries": retries
                    })
                    print(f"  [{endpoint}] HTTP {actual_status} -- {'PASS' if passed else 'FAIL'}")
                    break
            except (urllib.error.URLError, OSError) as e:
                retries += 1
                print(f"  [{endpoint}] Attempt {retries}/{max_retries} failed: {e}")
                if retries < max_retries:
                    time.sleep(10)
            except Exception as e:
                results.append({"endpoint": endpoint, "status": "error", "error": str(e), "passed": False})
                print(f"  [{endpoint}] ERROR: {e}")
                break

        if not passed and retries == max_retries:
            results.append({"endpoint": endpoint, "status": "unreachable", "passed": False})

    passed_count = sum(1 for r in results if r.get("passed"))
    total_count = len(results)

    print(f"
Health validation: {passed_count}/{total_count} endpoints healthy")

    if passed_count < total_count:
        print("FAIL: Not all endpoints healthy")
        sys.exit(1)

    print("PASS: All endpoints healthy")
    return results

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--environment", default="test-failover")
    parser.add_argument("--expected-status", type=int, default=200)
    parser.add_argument("--timeout-seconds", type=int, default=300)
    args = parser.parse_args()
    validate_health(args.environment, args.expected_status, args.timeout_seconds)
