#!/usr/bin/env bash
set -euo pipefail

log_file="tests/TEST-LOG.md"

if rg -n "commit:\s*<pending>|@\s*pending|<pending>\s*@|copilot/<pending>|<current branch>\s*@\s*pending" "$log_file"; then
  echo "ERROR: $log_file contains pending commit placeholders. Replace with a real SHA or 'commit: unrecoverable' + rationale." >&2
  exit 1
fi

echo "PASS: $log_file contains no pending commit placeholders."
