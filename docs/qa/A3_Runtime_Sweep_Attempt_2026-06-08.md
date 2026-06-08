# A3 Runtime Sweep Attempt — 2026-06-08

**Mode:** J — Operations / Config / Data Maintenance  
**Scope:** A3 CIVSUB / Threat / IED hosted MP and dedicated/JIP reliability sweep execution attempt.  
**Runtime behavior changes:** None.  
**Result:** `BLOCKED_RUNTIME`

---

## 1) Purpose

This record documents the requested attempt to execute the A3 runtime sweep after the recent ecosystem, Runtime Boundary, Console VM, and Threat Economy observability work.

The sweep remains required before adaptive COIN tuning proceeds. This record does not validate the coupling. It only records that the connector environment cannot run the Arma hosted MP, full mod-stack dedicated server, JIP observer, reconnect, respawn, or persistence scenarios.

---

## 2) Required checks and current result

| # | Scenario | Required environment | Current result | Notes |
|---|---|---|---|---|
| A3-H1 | CIVSUB district activation and sampler run | Hosted MP with intended mod stack | `BLOCKED_RUNTIME` | Arma runtime unavailable in connector session. |
| A3-H2 | Civilian contact/identity interaction | Hosted MP with player/client UI | `BLOCKED_RUNTIME` | Requires live player interaction. |
| A3-H3 | District delta to posture | Hosted MP or controlled test harness | `BLOCKED_RUNTIME` | Requires live state observation/RPT. |
| A3-H4 | Threat scheduler across multiple district postures | Hosted MP/dedicated runtime | `BLOCKED_RUNTIME` | Requires live scheduler execution and snapshots. |
| A3-H5 | Threat record public visibility | Hosted MP/dedicated runtime | `BLOCKED_RUNTIME` | Requires Console/Diary/public-state observation. |
| A3-H6 | IED evidence/disposition lifecycle | Hosted MP/dedicated runtime with EOD flow | `BLOCKED_RUNTIME` | Requires live object, evidence, and disposition flow. |
| A3-H7 | Protected-zone denial | Hosted MP/dedicated runtime | `BLOCKED_RUNTIME` | Requires controlled scenario and RPT evidence. |
| A3-H8 | Cleanup after resolution | Hosted MP/dedicated runtime | `BLOCKED_RUNTIME` | Requires world-entity observation after area exit. |
| A3-D1 | Dedicated fresh start | Dedicated server | `BLOCKED_RUNTIME` | Dedicated server unavailable in connector session. |
| A3-D2 | JIP during active district state | Dedicated server + late client | `BLOCKED_RUNTIME` | Requires second client/JIP observer. |
| A3-D3 | JIP during active threat/evidence state | Dedicated server + late client | `BLOCKED_RUNTIME` | Requires second client/JIP observer. |
| A3-D4 | Reconnect during active lifecycle | Dedicated server + reconnecting client | `BLOCKED_RUNTIME` | Requires live reconnect scenario. |
| A3-D5 | Restart after closed event | Dedicated server + persistence cycle | `BLOCKED_RUNTIME` | Requires save/restart validation. |

---

## 3) Evidence still required

- RPT excerpts for CIVSUB init, tick, sampler, and contact flow.
- RPT excerpts for scheduler allow/deny decisions.
- RPT excerpts for IED discovery, evidence, disposition, and cleanup.
- Threat economy snapshot before and after scheduled activity.
- CIVSUB district snapshot before and after delta.
- Console/Diary/public-state screenshots or text dumps.
- JIP observer notes.
- Dedicated restart and reconnect observations.

---

## 4) Governance decision

Adaptive COIN behavior remains blocked.

Do not claim A3 coupling is validated until the hosted MP and dedicated/JIP rows above move from `BLOCKED_RUNTIME` to `PASS` in `tests/TEST-LOG.md` with evidence attached or summarized.

---

## 5) Next operator action

Run the A3 checklist in `docs/qa/CIVSUB_Threat_IED_Reliability_Sweep_2026-06-08.md` on a machine that can host Arma 3 with the intended mod stack and at least one JIP observer client.
