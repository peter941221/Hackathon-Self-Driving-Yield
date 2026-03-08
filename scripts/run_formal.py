#!/usr/bin/env python3
import json
import os
import sys


def main() -> int:
    os.makedirs("cache", exist_ok=True)
    json_out = os.path.join("cache", "halmos-formal.json")
    command = [
        "--contract",
        "EngineVaultFormalTest",
        "--function",
        "check_",
        "--loop",
        "2",
        "--solver-timeout-branching",
        "5s",
        "--solver-timeout-assertion",
        "30s",
        "--json-output",
        json_out,
        "--minimal-json-output",
        "--no-status",
    ]

    print("Running: halmos", " ".join(command))

    import halmos.__main__ as halmos_main
    import halmos.ui as halmos_ui

    halmos_ui.UI.start_status = lambda self: None
    halmos_ui.UI.stop_status = lambda self: None
    halmos_ui.UI.clear_live = lambda self: None

    result = halmos_main._main(command)
    if result.exitcode != 0:
        return result.exitcode

    if os.path.exists(json_out):
        with open(json_out, "r", encoding="utf-8") as handle:
            data = json.load(handle)
        print(json.dumps(data, indent=2))

    return 0


if __name__ == "__main__":
    sys.exit(main())
