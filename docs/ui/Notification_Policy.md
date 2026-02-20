# Notification Policy

## Purpose

This policy defines how mission code should notify players while minimizing message noise. Use a **single primary channel** per event unless there is a documented accessibility or authority reason to do otherwise.

## Channels

### 1) Toast (`ARC_fnc_clientToast`)

**Use for:**
- action-required operator events
- state transitions that change what the player should do next
- success/failure outcomes tied to a recent player action

**Characteristics:**
- non-blocking
- concise
- best default for most gameplay/system notifications

### 2) Chat (`systemChat`)

**Use for:**
- low-priority informational telemetry
- debug/admin traces (when intentionally visible)
- logs that may be useful to scroll back through

**Characteristics:**
- persistent in chat history
- can become noisy quickly
- should not be primary UX for urgent actions

### 3) Hint (`hint` / `ARC_fnc_clientHint`)

**Use for:**
- exceptional interruptions
- short-lived guidance that must be visually prominent
- fallback UX in flows where toast is unavailable

**Characteristics:**
- highly attention-grabbing
- easy to spam if used in loops/ticks
- should be rate-limited and rare

## Channel Selection Rules

1. **Default to toast** for player-facing events.
2. Use **chat** only when archival/log-like visibility is helpful.
3. Use **hint** only when interruption is intentionally required.
4. If an event already has a channel, do not add another channel unless rationale is documented in the PR.

## Anti-Spam Rules

1. **No dual-channel duplicates**: do not send the same message text to multiple channels for one event.
2. **Cooldown guidance**:
   - repeated event keys should be gated with a cooldown (typically 2-10s depending on cadence)
   - events emitted from loops/ticks must always have dedupe/cooldown protection
3. **Burst control**:
   - aggregate repetitive updates into periodic summaries when possible
   - suppress unchanged-state repeats
4. **Rationale required** when adding a new repeated notification path.

## Wording Guidance

Keep messages:
- **short** (one sentence; avoid stacked clauses)
- **actionable** (state what happened and what to do next)
- **non-redundant** (avoid repeating state already visible in UI)

Recommended structure:
- `<event>: <impact>. <next action>`

Examples:
- `TOC Order accepted. Hold for route confirmation.`
- `Convoy launch blocked. Recheck route and retry.`

Avoid:
- verbose diagnostics in player-facing channels
- repeating identical prefixes/suffixes across every tick

## PR Review Enforcement (Static)

For any PR that touches notification-capable code (`*.sqf`, config function wiring, UI action handlers), include a static message-noise scan:

```bash
# Baseline counts in changed files
FILES="$(git diff --name-only -- '*.sqf' '*.hpp' '*.ext')"

for p in "hint" "systemChat" "ARC_fnc_clientToast"; do
  echo "=== $p ==="
  rg -n "$p" $FILES || true
done
```

Reviewers/authors must state:
1. which new notification callsites were added,
2. why each chosen channel is appropriate,
3. what cooldown/dedupe rule prevents spam (or why not needed).
