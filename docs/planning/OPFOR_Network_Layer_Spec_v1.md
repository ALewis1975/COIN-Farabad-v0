# Farabad COIN v0 - OPFOR Network Layer Spec v1

**Version:** 1.0  
**Date:** 2026-06-08  
**Status:** Planning spec  
**Mode:** F - Documentation-Only Changes  
**Layer:** L6 OPFOR Network  
**Scope:** Defines abstract hidden-network posture, capacity, disruption, recovery, and public-exposure boundaries. No runtime behavior changes.

---

## 0) Truth status

This document is a planning spec. It does not add runtime state, schedulers, RemoteExec endpoints, or behavior.

| Claim type | Status |
|---|---|
| OPFOR Network as ecosystem layer | Branch-local until parent ecosystem stack merges |
| Existing Threat system behavior | Existing Threat docs remain authoritative |
| Runtime OPFOR network subsystem | Not implemented by this document |

---

## 1) Purpose

The OPFOR Network layer separates abstract hidden-network posture from visible threat-system outputs.

Threat Synthesis owns visible threat records, leads, and event decisions. OPFOR Network should later own the hidden abstract stock that shapes those decisions: district network strength, support posture, disruption state, recovery rate, and pressure on civilian cooperation.

This prevents Threat from becoming both the hidden network model and every visible expression of that model.

---

## 2) Authority

| Item | Contract |
|---|---|
| Owner layer | L6 OPFOR Network |
| Initial subsystem owner | Threat / future OPFOR bridge |
| Writer authority | Server only if implemented later |
| Client role | No raw access. Clients see filtered Intel/Threat products only. |
| Persistence | Likely required later, but not authorized by this planning spec alone. |
| UI authority | None. UI receives only filtered leads, confidence, reports, or debug-gated summaries. |

---

## 3) Boundary with Threat Synthesis

| Concern | OPFOR Network owns | Threat Synthesis owns |
|---|---|---|
| Hidden district capacity | Yes, if later implemented | Consumes as one input |
| Abstract support posture | Yes, if later implemented | Consumes as one input |
| District pressure context | Produces hidden context | Combines context with terrain, time, CIVSUB, and budgets |
| Visible records and leads | No | Yes |
| Event allow/deny decision | No | Yes |
| Public UI exposure | No raw exposure | Filtered summaries only |

---

## 4) Future hidden-state concept

A future `opfor_v1_network` model may include:

| Field | Meaning |
|---|---|
| `districtId` | District key |
| `networkStrength` | Abstract district capacity |
| `supportPosture` | Abstract support posture |
| `pressureIndex` | Abstract pressure on local cooperation |
| `disruptedUntil` | Server time for temporary disruption effect |
| `recoveryRate` | Slow return toward baseline |
| `lastChangedAt` | Last server-side update timestamp |
| `audit` | Bounded internal audit metadata |

Raw fields should stay server-only unless a later public summary explicitly filters them.

---

## 5) Planned event taxonomy

| Event | Meaning | Likely consumers |
|---|---|---|
| `OPFOR_NETWORK_CHANGED` | Hidden network posture changed. | Threat, Intel |
| `OPFOR_NETWORK_DISRUPTED` | Temporary reduction effect applied. | Threat, Intel, S3 |
| `OPFOR_NETWORK_RECOVERED` | Recovery state changed. | Threat, Intel |
| `OPFOR_PRESSURE_CHANGED` | District pressure context changed. | CIVSUB, Intel, Threat |
| `OPFOR_INPUT_MISSING` | A consumer expected network input but none existed. | Diagnostics |

---

## 6) Public exposure rule

Allowed public exposure:

- Intel confidence and uncertainty.
- Leads with fidelity metadata.
- Threat records after Threat emits them.
- Narrative reporting with uncertainty labels.
- Debug-only summaries when explicitly authorized.

Forbidden public exposure:

- Raw hidden network strength in normal UI.
- Exact recovery timers in normal UI.
- Client-side mutation of hidden network state.
- UI inference of hidden state from partial messages.

---

## 7) Non-goals

- Do not implement persistent OPFOR state in this spec.
- Do not create a second Threat governor.
- Do not expose raw hidden network state to players.
- Do not add physical activity paths from OPFOR Network directly.
- Do not bypass CIVSUB, Intel, or Threat contracts.

---

## 8) Validation requirements before runtime expansion

| Validation | Required evidence |
|---|---|
| Static contract review | State/config ownership and hidden/public split defined. |
| Threat consumer review | Threat consumes network context through explicit API/snapshot, not direct hidden mutation. |
| Intel exposure review | Public outputs expose uncertainty, not raw hidden state. |
| Closeout feedback smoke | Completed operations can produce bounded abstract disruption feedback. |
| JIP secrecy check | Late client receives no raw hidden network state unless debug-gated. |
| Dedicated RPT review | Network events log bounded structured entries if implemented later. |

---

## 9) Next implementation task

Before code, write a narrow OPFOR Bridge baseline that chooses one v1 slice: recommended first slice is incident closeout -> abstract disruption hint -> Threat input modifier -> Intel uncertainty update.
