#!/usr/bin/env python3
"""Minimal trace replay tool for grey-conform conformance testing.

Replays pre-recorded binary trace files against the target Unix socket,
comparing responses to expected outputs.
"""

import socket
import struct
import sys
from pathlib import Path


def send_msg(sock, data: bytes):
    """Send a length-prefixed message."""
    sock.sendall(struct.pack('<I', len(data)))
    sock.sendall(data)


def recv_msg(sock) -> bytes:
    """Receive a length-prefixed message."""
    raw_len = b''
    while len(raw_len) < 4:
        chunk = sock.recv(4 - len(raw_len))
        if not chunk:
            raise ConnectionError("Connection closed while reading length")
        raw_len += chunk
    msg_len = struct.unpack('<I', raw_len)[0]
    data = b''
    while len(data) < msg_len:
        chunk = sock.recv(msg_len - len(data))
        if not chunk:
            raise ConnectionError("Connection closed while reading body")
        data += chunk
    return data


MSG_NAMES = {
    0x00: "PeerInfo",
    0x01: "Initialize",
    0x02: "StateRoot",
    0x03: "ImportBlock",
    0x04: "GetState",
    0x05: "State",
    0xFF: "Error",
}


def main():
    trace_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else Path("res/conformance/fuzz-proto/examples/0.7.2/no_forks")
    sock_path = sys.argv[2] if len(sys.argv) > 2 else "/tmp/jam_target.sock"

    if not trace_dir.exists():
        print(f"Error: trace dir {trace_dir} not found")
        sys.exit(1)

    # Collect fuzzer/target file pairs
    fuzzer_files = sorted(trace_dir.glob("*_fuzzer_*.bin"))
    target_files = sorted(trace_dir.glob("*_target_*.bin"))

    if len(fuzzer_files) != len(target_files):
        print(f"Error: mismatch {len(fuzzer_files)} fuzzer vs {len(target_files)} target files")
        sys.exit(1)

    print(f"Found {len(fuzzer_files)} message pairs in {trace_dir}")

    # Connect
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        sock.connect(sock_path)
    except Exception as e:
        print(f"Error connecting to {sock_path}: {e}")
        sys.exit(1)
    print(f"Connected to {sock_path}")

    passed = 0
    failed = 0
    errors = 0

    try:
        for i, (fuzz_file, target_file) in enumerate(zip(fuzzer_files, target_files)):
            # Read message bytes
            request = fuzz_file.read_bytes()
            expected = target_file.read_bytes()

            req_kind = MSG_NAMES.get(request[0], f"0x{request[0]:02x}") if request else "empty"
            exp_kind = MSG_NAMES.get(expected[0], f"0x{expected[0]:02x}") if expected else "empty"

            print(f"\n[{i}] TX: {req_kind} ({len(request)} bytes) -> expecting {exp_kind}")

            # Send request
            send_msg(sock, request)

            # Receive response
            response = recv_msg(sock)
            resp_kind = MSG_NAMES.get(response[0], f"0x{response[0]:02x}") if response else "empty"

            if response == expected:
                print(f"    RX: {resp_kind} ({len(response)} bytes) - PASS")
                passed += 1
            else:
                # Check if both are errors (error text may differ)
                if response and expected and response[0] == 0xFF and expected[0] == 0xFF:
                    print(f"    RX: Error (text may differ) - PASS (error)")
                    errors += 1
                else:
                    print(f"    RX: {resp_kind} ({len(response)} bytes) - FAIL")
                    if response[0:1] == expected[0:1]:
                        # Same type, show diff
                        print(f"    Expected: {expected[:65].hex()}")
                        print(f"    Got:      {response[:65].hex()}")
                    else:
                        print(f"    Expected type: {exp_kind}")
                        print(f"    Got type:      {resp_kind}")
                        if response[0] == 0xFF:
                            # Show error message
                            try:
                                msg = response[2:2+response[1]].decode('utf-8', errors='replace')
                                print(f"    Error msg: {msg}")
                            except:
                                print(f"    Error raw: {response[:80].hex()}")
                    failed += 1
    except Exception as e:
        print(f"\nException: {e}")
    finally:
        sock.close()

    print(f"\n{'='*60}")
    print(f"Results: {passed} passed, {errors} error-match, {failed} failed")
    print(f"Total: {passed + errors + failed}/{len(fuzzer_files)}")
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
