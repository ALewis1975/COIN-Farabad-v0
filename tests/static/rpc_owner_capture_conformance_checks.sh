#!/usr/bin/env bash
#
# Step 6 / Lane A — A2: Validator-caller conformance sweep.
#
# Static gate that enforces explicit RPC owner-capture across every server-side
# handler that calls ARC_fnc_rpcValidateSender.
#
# Why this guard exists
# ---------------------
# On a dedicated server, `remoteExecutedOwner` is only defined inside the scope
# of the function that was directly remoteExec'd. It does NOT propagate into
# nested `call` frames, so ARC_fnc_rpcValidateSender cannot read it itself.
# Every handler must therefore capture the owner at its own top frame and pass
# it explicitly as the 6th positional argument (`_callerOwner`). A handler that
# omits the 6th argument silently falls back to a scope read that is `nil` on
# dedicated, producing MISSING_REMOTE_CONTEXT and *_SECURITY_DENIED at runtime.
#
# This check parses each call to ARC_fnc_rpcValidateSender under functions/ and
# fails if:
#   * the call passes fewer than 6 positional arguments, or
#   * the 6th argument is a bare literal (-1 / 0 / nil) instead of a captured
#     owner value, or
#   * the handler file never reads `remoteExecutedOwner` (no top-frame capture).
#
# It also fails if the number of discovered handlers drops below the recorded
# floor, which catches accidental loss of coverage (e.g. a handler renamed so
# the scan no longer sees it).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

# Minimum number of conformant handlers expected. Raise this when handlers are
# added; never lower it without justification — a drop means lost coverage.
MIN_HANDLERS="${ARC_RPC_MIN_HANDLERS:-38}"

python3 - "$MIN_HANDLERS" <<'PY'
import glob
import re
import sys

CALL = "call ARC_fnc_rpcValidateSender"
min_handlers = int(sys.argv[1])

def split_top_level(s):
    """Split an argument-array body on top-level commas."""
    args, depth, cur, instr = [], 0, "", None
    for ch in s:
        if instr:
            cur += ch
            if ch == instr:
                instr = None
            continue
        if ch in "\"'":
            instr = ch
            cur += ch
            continue
        if ch in "[({":
            depth += 1
        elif ch in "])}":
            depth -= 1
        elif ch == "," and depth == 0:
            args.append(cur.strip())
            cur = ""
            continue
        cur += ch
    if cur.strip():
        args.append(cur.strip())
    return args

def extract_call_array(text, call_idx):
    """Return the body inside the [ ... ] argument array that precedes a call."""
    j = text.rfind("]", 0, call_idx)
    if j < 0:
        return None
    depth, i, instr = 0, j, None
    while i >= 0:
        ch = text[i]
        if instr:
            if ch == instr:
                instr = None
            i -= 1
            continue
        if ch in "\"'":
            instr = ch
            i -= 1
            continue
        if ch in "])}":
            depth += 1
        elif ch in "[({":
            depth -= 1
            if depth == 0:
                return text[i + 1:j]
        i -= 1
    return None

LITERALS = {"-1", "0", "nil", "objNull"}

violations = []
conformant = []

for path in sorted(glob.glob("functions/**/*.sqf", recursive=True)):
    with open(path, encoding="utf-8", errors="replace") as fh:
        text = fh.read()
    if CALL not in text:
        continue

    has_capture = "remoteExecutedOwner" in text

    for m in re.finditer(re.escape(CALL), text):
        body = extract_call_array(text, m.start())
        if body is None:
            violations.append((path, "could not parse argument array for call"))
            continue
        args = split_top_level(body)
        if len(args) < 6:
            violations.append(
                (path, "passes %d args; missing explicit _callerOwner (6th arg). args=%s"
                 % (len(args), args))
            )
            continue
        owner_arg = args[5]
        if owner_arg in LITERALS:
            violations.append(
                (path, "6th arg is bare literal '%s'; must be a top-frame owner capture" % owner_arg)
            )
            continue
        if not has_capture:
            violations.append(
                (path, "passes owner arg '%s' but file never reads remoteExecutedOwner" % owner_arg)
            )
            continue
        conformant.append((path, owner_arg))

print("RPC owner-capture conformance sweep")
print("-----------------------------------")
print("Handlers calling ARC_fnc_rpcValidateSender: %d" % (len(conformant) + len(violations)))
for path, owner_arg in conformant:
    print("[PASS] %s -> owner arg: %s" % (path, owner_arg))

ok = True

if violations:
    ok = False
    print()
    for path, reason in violations:
        print("[FAIL] %s: %s" % (path, reason))

if len(conformant) < min_handlers:
    ok = False
    print()
    print("[FAIL] conformant handler count %d is below expected floor %d "
          "(lost coverage?). If handlers were intentionally removed, lower "
          "ARC_RPC_MIN_HANDLERS / MIN_HANDLERS with justification."
          % (len(conformant), min_handlers))

if not ok:
    sys.exit(1)

print()
print("[PASS] all %d handlers pass an explicit _callerOwner (>= floor %d)."
      % (len(conformant), min_handlers))
PY
