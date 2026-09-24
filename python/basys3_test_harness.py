#!/usr/bin/env python3
"""
basys3_test_harness.py

Host-side automated test script for the Basys 3 UART test harness
(src/uart_test_harness.v). Talks to the board over its onboard USB-UART
bridge - no extra wiring, it's the same USB cable used to program the FPGA -
and runs a small pass/fail test sequence, similar in spirit to a bench ATE
script exercising a unit under test.

Protocol (115200 8N1):
    'S' -> 2 bytes: {sw[15:8], sw[7:0]}          (current switch positions)
    'C' -> 2 bytes: {count[15:8], count[7:0]}    (free-running 1Hz counter)
    'R' -> 2 bytes: b"OK"                        (resets the counter)
    'T' -> 1 byte:  0x01                         (self-test / BIST placeholder)
    anything else -> 1 byte: b"?"

Usage:
    python basys3_test_harness.py --list
    python basys3_test_harness.py --port COM5
    python basys3_test_harness.py --port COM5 --duration 5
"""

import argparse
import sys
import time

try:
    import serial
    from serial.tools import list_ports
except ImportError:
    sys.exit(
        "pyserial is required. Install it with:\n"
        "    pip install -r requirements.txt"
    )

BAUD_RATE = 115200
TIMEOUT_S = 1.0


class HarnessError(RuntimeError):
    pass


class Basys3Harness:
    def __init__(self, port, baud=BAUD_RATE, timeout=TIMEOUT_S):
        self.ser = serial.Serial(port, baud, timeout=timeout)
        # let the board's USB-UART bridge settle after the port opens
        time.sleep(0.2)
        self.ser.reset_input_buffer()

    def close(self):
        self.ser.close()

    def _command(self, cmd_char, expected_len):
        self.ser.write(cmd_char.encode("ascii"))
        resp = self.ser.read(expected_len)
        if len(resp) != expected_len:
            raise HarnessError(
                f"command {cmd_char!r}: expected {expected_len} bytes, "
                f"got {len(resp)} ({resp!r}) - check COM port/baud and that "
                f"the board is programmed with this project's bitstream"
            )
        return resp

    def read_switches(self):
        resp = self._command("S", 2)
        return (resp[0] << 8) | resp[1]

    def read_counter(self):
        resp = self._command("C", 2)
        return (resp[0] << 8) | resp[1]

    def reset_counter(self):
        resp = self._command("R", 2)
        if resp != b"OK":
            raise HarnessError(f"reset: expected b'OK', got {resp!r}")

    def self_test(self):
        resp = self._command("T", 1)
        return resp == b"\x01"


def list_serial_ports():
    ports = list(list_ports.comports())
    if not ports:
        print("No serial ports found.")
        return
    print("Available serial ports:")
    for p in ports:
        print(f"  {p.device}  {p.description}")


def run_tests(port, duration_s):
    results = []  # (name, passed, detail)

    def record(name, passed, detail=""):
        results.append((name, passed, detail))
        status = "PASS" if passed else "FAIL"
        suffix = f" - {detail}" if detail else ""
        print(f"[{status}] {name}{suffix}")

    harness = Basys3Harness(port)
    try:
        # 1. self-test / BIST
        try:
            ok = harness.self_test()
            record("self_test", ok, "0x01 expected" if not ok else "")
        except HarnessError as e:
            record("self_test", False, str(e))

        # 2. read current switch positions (informational + sanity check)
        try:
            sw = harness.read_switches()
            record("read_switches", True, f"sw = 0x{sw:04X} ({sw:016b})")
        except HarnessError as e:
            record("read_switches", False, str(e))

        # 3. reset the counter and confirm it reads back near zero
        try:
            harness.reset_counter()
            count_after_reset = harness.read_counter()
            passed = count_after_reset <= 1  # allow 1 tick of round-trip latency
            record(
                "reset_counter",
                passed,
                f"counter = {count_after_reset} right after reset",
            )
        except HarnessError as e:
            record("reset_counter", False, str(e))

        # 4. let the free-running 1 Hz counter run and check its rate.
        #    This is exactly the kind of bug a bench test like this catches -
        #    an earlier version of this design ticked twice as fast as
        #    intended, which only shows up if you actually time it.
        try:
            start_count = harness.read_counter()
            t0 = time.monotonic()
            time.sleep(duration_s)
            end_count = harness.read_counter()
            elapsed = time.monotonic() - t0
            delta = end_count - start_count
            expected = elapsed  # 1 Hz -> ~1 count per second
            tolerance = max(1, round(expected * 0.15)) + 1  # +/-15%, min +/-1
            passed = abs(delta - expected) <= tolerance
            record(
                "counter_rate",
                passed,
                f"+{delta} counts in {elapsed:.2f}s "
                f"(expected ~{expected:.2f} +/- {tolerance})",
            )
        except HarnessError as e:
            record("counter_rate", False, str(e))

        # 5. unknown command should be handled gracefully, not hang
        try:
            resp = harness._command("Z", 1)
            passed = resp == b"?"
            record("unknown_command", passed, f"got {resp!r}")
        except HarnessError as e:
            record("unknown_command", False, str(e))

    finally:
        harness.close()

    print()
    n_pass = sum(1 for _, ok, _ in results if ok)
    n_total = len(results)
    print(f"Summary: {n_pass}/{n_total} passed")
    return n_pass == n_total


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--port", help="Serial port, e.g. COM5 or /dev/ttyUSB1")
    parser.add_argument(
        "--duration", type=float, default=3.0,
        help="Seconds to wait while checking the counter's tick rate (default: 3)",
    )
    parser.add_argument(
        "--list", action="store_true", help="List available serial ports and exit"
    )
    args = parser.parse_args()

    if args.list:
        list_serial_ports()
        return

    if not args.port:
        parser.error("--port is required (use --list to see available ports)")

    ok = run_tests(args.port, args.duration)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
