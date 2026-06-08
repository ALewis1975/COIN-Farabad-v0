# Farabad COIN v0 - Government / GREEN Layer Spec v1

**Version:** 1.0  
**Date:** 2026-06-08  
**Status:** Planning spec  
**Mode:** F - Documentation-Only Changes  
**Layer:** L5 Government / GREEN  
**Scope:** Defines governance posture, agency response, legitimacy, corruption, detention handoff, checkpoint status, and public-service event concepts. No runtime behavior changes.

---

## 0) Truth status

This document is a planning spec. It does not add `gov_v1_*` state, new schedulers, new RemoteExec endpoints, or runtime behavior.

| Claim type | Status |
|---|---|
| Government / GREEN as ecosystem layer | Branch-local until parent ecosystem stack merges |
| Existing GREEN legitimacy through CIVSUB | Conceptually aligned with CIVSUB baseline; no code audit performed here |
| Runtime government subsystem | Not implemented by this document |

---

## 1) Purpose

Farabad is the capital city of Takistan in the mission setting. A capital city needs visible governance pressure: police, army, ministries, palace security, airport/embassy authority, detention/prison process, checkpoints, corruption, service delivery, and legitimacy.

The Government / GREEN layer prevents those concepts from being scattered across CIVSUB, SitePop, Prison, TASKENG, Threat, and UI without a shared owner.

This layer should answer:

- What is the local government posture by district?
- How legitimate does the government appear to civilians?
- Which TNP/TNA/security response is available?
- Does a detention or evidence handoff improve legitimacy or create grievance?
- Does corruption or failed service delivery affect civilian cooperation?
- Which government facts may be shown to players through intel/SITREP/console views?

---

## 2) Authority

| Item | Contract |
|---|---|
| Owner layer | L5 Government / GREEN |
| Initial subsystem owner | CIVSUB / future Government bridge |
| Writer authority | Server only when implemented |
| Client role | Request/report only through validated actions |
| Persistence | Planning only. Future posture/history state requires schema/version/reset plan. |
| UI authority | UI displays posture, handoff state, or uncertainty. UI does not own legitimacy. |

---

## 3) Relationship to CIVSUB

CIVSUB already owns district population state and the RED/WHITE/GREEN influence axes. In v1 planning, Government / GREEN should not duplicate that store.

Recommended split:

| Concern | Owner |
|---|---|
| District GREEN legitimacy score | CIVSUB district state until a future governance store exists |
| Government agency posture | Government / GREEN layer planning contract |
| Police/army response event | Government / GREEN layer, implemented through server-mediated subsystem bridge |
| Civilian sentiment effect | CIVSUB delta bundle |
| Task/lead effect | TASKENG/Intel consumer of government event or CIVSUB delta |
| UI display | Console VM / Interface as consumer only |

---

## 4) Planned event taxonomy

| Event | Meaning | Likely consumers |
|---|---|---|
| `GOV_POSTURE_CHANGED` | District or site governance posture changed. | CIVSUB, Intel, S3, UI |
| `TNP_RESPONSE_AVAILABLE` | Police response is available in a district/site. | S3, SitePop, Prison, UI |
| `TNA_RESPONSE_AVAILABLE` | Army response is available for higher-risk government support. | S3, Threat, UI |
| `CHECKPOINT_STATUS_CHANGED` | Checkpoint opened, closed, degraded, or compromised. | World, SitePop, Threat, Intel |
| `DETAINEE_HANDOFF_ACCEPTED` | Server-validated detainee handoff completed. | CIVSUB, Prison, S3, UI |
| `EVIDENCE_HANDOFF_ACCEPTED` | Server-validated evidence handoff completed. | Intel, Threat, S3, UI |
| `CORRUPTION_EVENT_RECORDED` | Corruption or abuse signal added to district posture. | CIVSUB, Intel, S3 |
| `SERVICE_DELIVERY_RECORDED` | Aid, repair, medical, or civil service success recorded. | CIVSUB, S3, UI |

---

## 5) Planned read model

Recommended future read model: `gov_v1_posture` or Console VM section `sections.government`.

Recommended fields:

| Field | Type | Meaning |
|---|---|---|
| `schema` | string | `gov_posture_v1` |
| `version` | array | `[1,0,0]` |
| `builtAtServerTime` | number | Server build time |
| `districtId` | string | `D01`-`D20` where applicable |
| `greenScore` | number | CIVSUB GREEN value or derived governance score |
| `policePosture` | string | `NONE`, `LIMITED`, `AVAILABLE`, `DEGRADED`, or `UNKNOWN` |
| `armyPosture` | string | `NONE`, `LIMITED`, `AVAILABLE`, `DEGRADED`, or `UNKNOWN` |
| `checkpointStatus` | array/map | Bounded checkpoint status records |
| `handoffStatus` | array/map | Recent detainee/evidence handoff records |
| `corruptionRisk` | string | `LOW`, `MED`, `HIGH`, or `UNKNOWN` |
| `serviceStatus` | string | `NONE`, `LIMITED`, `ACTIVE`, or `UNKNOWN` |
| `freshness` | map | Updated-at and stale-after metadata |

Do not publish hidden raw government logic if later implemented. UI should see posture and uncertainty, not secret internals.

---

## 6) Candidate mechanics, planning only

| Mechanic | Description | Required guardrail |
|---|---|---|
| Detention handoff legitimacy | Lawful, documented handoffs improve GREEN or reduce grievance. | Must be server-mediated and logged. |
| Evidence handoff | Evidence can improve lead quality or disrupt hostile networks. | Must flow through Intel/Threat events. |
| Checkpoint support | Government checkpoint status shapes route/security tasks. | Must resolve through World Registry anchors. |
| Corruption pressure | Corruption can reduce GREEN/WHITE or degrade intel reliability. | Must be bounded and explainable. |
| Service delivery | Aid, repairs, or medical support can improve GREEN/WHITE. | Must emit CIVSUB delta bundle. |

---

## 7) Non-goals

- Do not create a full government simulation in v1.
- Do not add persistent `gov_v1_*` state without a separate implementation baseline.
- Do not let UI infer government legitimacy from local visuals.
- Do not bypass CIVSUB when changing RED/WHITE/GREEN effects.
- Do not create new client-to-server request surfaces without RemoteExec audit.

---

## 8) Validation requirements before runtime expansion

| Validation | Required evidence |
|---|---|
| Static contract review | State/config ownership and event producers defined. |
| Server authority review | No client-authoritative government posture changes. |
| Handoff smoke | Detainee/evidence handoff logs and state transitions. |
| CIVSUB delta proof | Government effects change district state through CIVSUB delta path. |
| JIP UI proof | Late client sees posture/handoff state only through public snapshot/VM. |
| Dedicated RPT review | Handoff/checkpoint/service events log bounded structured entries. |

---

## 9) Next implementation task

Before code, write a narrow Government Bridge baseline that chooses one v1 slice: recommended first slice is server-mediated detainee/evidence handoff -> CIVSUB delta -> Intel/S3 visibility.
