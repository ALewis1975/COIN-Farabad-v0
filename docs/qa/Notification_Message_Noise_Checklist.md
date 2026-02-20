# Notification Message-Noise QA Checklist

Use this checklist for any PR that modifies notification behavior or touches files that can emit user-visible messaging.

## Scope

- [ ] Changed files reviewed for `hint`, `systemChat`, `ARC_fnc_clientToast`, and `ARC_fnc_clientHint` usage.
- [ ] New/changed callsites mapped to a clear event trigger.

## Channel Policy Conformance

- [ ] Each event uses one primary channel (toast/chat/hint).
- [ ] No dual-channel duplicate for the same event/message.
- [ ] Hint usage is justified as interruptive/exceptional.

## Anti-Spam Controls

- [ ] Loop/tick-based notifications have dedupe or cooldown.
- [ ] Cooldown key and interval are documented in PR notes.
- [ ] Repeated unchanged-state messages are suppressed.

## Message Quality

- [ ] Wording is short, actionable, and non-redundant.
- [ ] Message text does not restate obvious UI state every tick.
- [ ] Player-facing text avoids debug-only diagnostics.

## Repeatable Static Review Commands

Run from repo root and paste output summary in PR:

```bash
# 1) identify changed files in notification-capable surface
CHANGED_FILES="$(git diff --name-only -- '*.sqf' '*.hpp' '*.ext')"
echo "$CHANGED_FILES"

# 2) scan notification primitives in changed files
for p in "\\bhint\\b" "systemChat" "ARC_fnc_clientToast" "ARC_fnc_clientHint"; do
  echo "=== pattern: $p ==="
  rg -n "$p" $CHANGED_FILES || true
done

# 3) optional diff-scoped additions count
for p in "hint" "systemChat" "ARC_fnc_clientToast"; do
  echo "=== added lines containing: $p ==="
  git diff -U0 -- '*.sqf' '*.hpp' '*.ext' | rg '^\\+.*'"$p" || true
done
```

## PR Rationale Requirements

- [ ] Added `hint` callsites: count + rationale
- [ ] Added `systemChat` callsites: count + rationale
- [ ] Added `ARC_fnc_clientToast` callsites: count + rationale
- [ ] Any intentional exception to policy is explicitly documented with risk/mitigation.
