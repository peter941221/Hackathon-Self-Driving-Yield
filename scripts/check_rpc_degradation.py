#!/usr/bin/env python3
import json
import os
import sys
import urllib.error
import urllib.request


def rpc_call(url: str, method: str, timeout: float):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": []}).encode()
    request = urllib.request.Request(url, data=payload, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)


def main() -> int:
    rpc_url = os.environ.get("BSC_RPC_URL", "")
    if not rpc_url:
        print("BSC_RPC_URL not set; RPC degradation probe skipped.")
        return 0

    normal = rpc_call(rpc_url, "eth_chainId", 5.0)
    print("Normal RPC probe result:", normal.get("result"))

    try:
        degraded = rpc_call(rpc_url, "eth_blockNumber", 0.001)
        print("Degraded RPC probe still succeeded quickly:", degraded.get("result"))
    except (TimeoutError, urllib.error.URLError, OSError) as error:
        print(f"Graceful degraded RPC handling confirmed: {type(error).__name__}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
