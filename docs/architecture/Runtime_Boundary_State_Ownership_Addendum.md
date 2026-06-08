# Runtime Boundary State Ownership Addendum

**Version:** 1.0  
**Date:** 2026-06-08  
**Mode:** B - Feature Delivery support documentation  
**Parent ledger:** `docs/architecture/State_Ownership_Ledger.md`  
**Scope:** Documents the Runtime Boundary public snapshot family introduced by the runtime boundary snapshot feature.

---

## 1) Purpose

This addendum records the state ownership for the new Runtime Boundary public snapshot family. It exists so the feature PR documents the single-writer contract without rewriting the full State Ownership Ledger table in the same PR.

Future State Ownership Ledger maintenance should fold these rows into the main replicated key ledger.

---

## 2) Replicated key ownership

| Key | Status | Writer(s) | Reset / init writer | Purpose |
|---|:---:|---|---|---|
| `ARC_pub_runtimePolicy` | ✅ | `functions/core/fn_runtimePolicyPublish.sqf` | — | Runtime Boundary public snapshot with player count, FPS, AI/vehicle pressure bands, budget band, and diagnostic-only policy hints. |
| `ARC_pub_runtimePolicyUpdatedAt` | ✅ | `functions/core/fn_runtimePolicyPublish.sqf` | — | Freshness signal for the runtime policy snapshot. |
| `ARC_pub_runtimePolicyMeta` | ✅ | `functions/core/fn_runtimePolicyPublish.sqf` | — | Bounded metadata for the runtime policy publish event. |
| `ARC_runtimePolicyLastPublishAt` | ✅ | `functions/core/fn_runtimePolicyPublish.sqf` | — | Server-local throttle timestamp used by `ARC_fnc_playerSnapshot`; not replicated. |

---

## 3) Runtime behavior boundary

The Runtime Boundary snapshot is diagnostic and presentation-oriented in this feature slice.

It does not:

- Change scheduler cadence.
- Change spawn or cleanup behavior.
- Change persistence behavior.
- Change RemoteExec surfaces.
- Make clients authoritative over runtime policy.

---

## 4) Merge-forward note

When `State_Ownership_Ledger.md` is next edited for key-level ownership maintenance, move the replicated rows above into the main ledger and remove or supersede this addendum.
