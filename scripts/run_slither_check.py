#!/usr/bin/env python3
import re
import subprocess
import sys


COMMAND = [
    "slither",
    ".",
    "--exclude-dependencies",
    "--exclude",
    "incorrect-equality,timestamp,low-level-calls,naming-convention,cyclomatic-complexity",
]


def main() -> int:
    print("Running:", " ".join(COMMAND))
    completed = subprocess.run(COMMAND, capture_output=True, text=True)
    output = (completed.stdout or "") + (completed.stderr or "")
    print(output, end="")

    detector_names = re.findall(r"Detector:\s*([^\r\n]+)", output)
    result_match = re.search(r"INFO:Slither:.*analyzed .*?,\s*(\d+) result\(s\) found", output)
    result_count = int(result_match.group(1)) if result_match else None
    detector_set = set(detector_names)

    if result_count == 0:
        print("Slither check passed: zero findings.")
        return 0

    if result_count == 1 and detector_set == {"reentrancy-events"}:
        print("Slither check passed: single known triaged finding (reentrancy-events).")
        return 0

    print("Slither check failed: unexpected findings or detector set.", file=sys.stderr)
    print(f"Exit code: {completed.returncode}", file=sys.stderr)
    print(f"Detectors: {sorted(detector_set)}", file=sys.stderr)
    print(f"Result count: {result_count}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
