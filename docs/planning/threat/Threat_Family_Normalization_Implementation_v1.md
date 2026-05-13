# Threat Family Normalization v1

## Scope

Epic 4 implementation normalizes threat-family contracts for `IED`, `VBIED`, `SUICIDE`, and `NON_IED` while preserving server-authoritative writes and compatibility with legacy IED-only readers.

## Family matrix (type/subtype/state/event/log)

| Family | Canonical type/subtype expectations | Create | Update | Close/Cleanup | Log/Event expectations |
|---|---|---|---|---|---|
| `IED` | `type=IED`; subtype usually `IED_*` | `THREAT_CREATED` with `family=IED` | Standard lifecycle states | `CLOSED -> CLEANED` | `THREAT_STATE_CHANGED` / `THREAT_CLOSED` / `THREAT_CLEANED` with `family` |
| `VBIED` | Accept legacy (`type=IED`,`subtype=VBIED*`) and normalized (`type=VBIED`) | `THREAT_CREATED` with `family=VBIED` | Standard lifecycle states | `CLOSED -> CLEANED` | Same event contract, `family=VBIED` |
| `SUICIDE` | Accept legacy (`type=IED`,`subtype=SUICIDE*|SB_*`) and normalized (`type=SUICIDE`) | `THREAT_CREATED` with `family=SUICIDE` | Standard lifecycle states | `CLOSED -> CLEANED` | Same event contract, `family=SUICIDE` |
| `NON_IED` | Any non-IED/other types/subtypes | `THREAT_CREATED` with `family=NON_IED` | Standard lifecycle states | `CLOSED -> CLEANED` | Same event contract, `family=NON_IED` |

## Shared schema core + family extensions

Shared record shape remains additive and backward compatible:

- Existing keys preserved: `type`, `subtype`, `state`, `state_ts`, `links`, `area`, `world`, `outcome`, `audit`.
- New normalized key: `family`.
- Event envelope and payload now carry:
  - `family`
  - `deny_reason` (empty for successful transitions)

Legacy readers that only consume `type/subtype` remain functional; normalized consumers should prefer `family`.

## Family-safe transition and closure semantics

- Transition vocabulary remains: `CREATED`, `ACTIVE`, `STAGED`, `DISCOVERED`, `NEUTRALIZED`, `DETONATED`, `INTERDICTED`, `CLOSED`, `CLEANED`, `EXPIRED`.
- Alias normalization:
  - `PLANNED -> CREATED`
  - `FAILED -> EXPIRED`
- Closure semantics remain family-safe and consistent:
  - terminal closure path is `... -> CLOSED -> CLEANED`
  - expired path is `... -> EXPIRED -> CLEANED`

## Deny reason normalization

`ARC_fnc_threatUpdateState` emits normalized deny reasons on guarded failures:

- `DENY_THREAT_NOT_FOUND`
- `DENY_STATE_FROM_EMPTY`
- `DENY_STATE_TO_UNKNOWN`
- `DENY_STATE_NOOP`
- `DENY_TRANSITION_INVALID`

For invalid/unknown transition attempts, `THREAT_STATE_CHANGE_DENIED` is emitted with `family`, `type`, `subtype`, and `deny_reason`.

## Compatibility guardrails

1. Legacy records without `family` are interpreted by `type/subtype` inference.
2. Legacy callers passing `type=IED` with `subtype=VBIED|SUICIDE|SB_*` are normalized to the appropriate family without requiring callsite rewrites.
3. Shared UI/event consumers can use `family` and avoid ad hoc family branching on legacy `type` quirks.
