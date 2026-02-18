# AIRSUB Focused Test Matrix

## Scope
Focused AIRSUB control-plane validation for:
- tower role gating (CCIC / LC / read-only),
- hold/release behavior,
- prioritize/cancel behavior,
- runway lock lifecycle,
- timeout-to-AI fallback.

## Validation Matrix

| ID | Area | Precondition | Steps | Expected Result | Runtime |
|---|---|---|---|---|---|
| AIRSUB-RG-CCIC-001 | Role gating (CCIC) | Player in `FARABAD_TOWER_WS_CCIC` tokenized role/group | Submit hold, release, prioritize, cancel, approve, deny actions from AIR panel | All actions accepted server-side (no auth denied events) | Local MP smoke + dedicated follow-up |
| AIRSUB-RG-LC-001 | Role gating (LC allowed set) | Player in `FARABAD_TOWER_LC`; `airbase_v1_tower_lc_allowedActions` default (`PRIORITIZE`,`CANCEL`) | Attempt prioritize/cancel; attempt hold/release and approve/deny | Prioritize/cancel accepted; hold/release/decision actions denied with `ACTION_NOT_ALLOWED_FOR_LC` | Local MP smoke + dedicated follow-up |
| AIRSUB-RG-RO-001 | Role gating (read-only) | Player without CCIC/LC tokens | Attempt hold/release/prioritize/cancel/approve/deny | All requests rejected; no state mutation | Local MP smoke + dedicated follow-up |
| AIRSUB-HR-001 | Hold/release | Queue has at least one departure-ready flight | CCIC sets HOLD; observe tick cycles; CCIC sets RELEASE | HOLD blocks execution start while queue remains; RELEASE resumes scheduler-driven dispatch | Local MP smoke |
| AIRSUB-PC-001 | Prioritize/cancel | Queue has flights A then B (both non-active) | CCIC/LC prioritize B; then cancel B | B moves to queue front and record status changes to `PRIORITIZED`; cancel removes B and sets record `CANCELLED` | Local MP smoke |
| AIRSUB-RWY-001 | Runway lock lifecycle | Queue has executable flight; runway open | Let scheduler reserve + occupy runway; let completion release | Runway transitions `OPEN -> RESERVED -> OCCUPIED -> OPEN`; owner/until fields update and clear | Local MP smoke + dedicated follow-up |
| AIRSUB-AI-001 | Timeout-to-AI fallback | `airbase_v1_controller_timeout_s` small; fallback enabled; pending request exists | Keep tower idle beyond timeout | Request moves to `APPROVED` with AI decision tuple `[AI, AI, ts, APPROVE, TIMEOUT]`; timeout event logged | Local MP smoke + dedicated follow-up |

## Dedicated-Server-Only Deferred Cases

The following are **deferred** until dedicated server validation is available:

1. **JIP controller continuity**: new CCIC/LC client joining mid-pending request receives accurate pending/awaiting rows and can decide without duplicate notifications.
2. **Ownership and remoteExec edge cases**: verify `remoteExecutedOwner` sender validation under reconnect/respawn and owner migration.
3. **Lock orphan recovery under disconnect**: controller disconnect while runway `RESERVED/OCCUPIED` still converges via sweep/release without deadlock.
4. **AI fallback under network latency**: pending-to-timeout transition remains deterministic with delayed packets and concurrent decision attempts.

### Follow-up Items (Dedicated)

- Run full matrix in hosted dedicated MP and annotate each case with PASS/FAIL + RPT snippet references.
- Add a dedicated-only regression checklist for JIP, reconnect, and ownership migration around AIRSUB control RPCs.
- Capture before/after `ARC_pub_state` snapshots for runway and clearance lists across each lifecycle case.
