# Threat System Review — Decomposition Plan (Docs-Only)

**Date:** 2026-05-13  
**Mode:** F (Documentation-Only Changes)  
**Scope:** `docs/planning/threat/**`  
**Primary baseline:** `docs/projectFiles/Farabad_THREAT_v0_IED_P1_Baseline_regen.md`  
**Related architecture:** `docs/architecture/Architecture_Plan_2026-05-08.md`  
**Validation ledger:** `tests/TEST-LOG.md`

---

## 1) Purpose

Define a concrete, PR-sized follow-up plan for Threat subsystem review findings without claiming runtime completion. This decomposition separates work into epics, documents dependencies, and sets evidence gates (especially dedicated/JIP/restart).

---

## 2) Status legend used in this plan

- **Implemented:** present in code and registered, with expected behavior documented.
- **Partially implemented:** code exists, but contract/spec/evidence is incomplete.
- **Missing:** planned contract capability is absent.
- **Validation-only:** feature exists but closure is blocked on evidence.

---

## 3) Current-state framing (review board)

| Review area | Current status | Notes |
|---|---|---|
| Optional baseline APIs (`threatCreateFromLead`, `threatEmitEvent`) | Missing | Not registered in `config/CfgFunctions.hpp` Threat block. |
| IED suspicious-object lifecycle / explicit spawn-path contract | Partially implemented | Threat/incident lifecycle exists, but explicit suspicious-object contract evidence is incomplete. |
| TOC/S2/player-facing threat surfacing | Partially implemented | Debug/snapshot paths exist; operator-facing threat presentation contract appears thin. |
| Threat-family normalization (IED/VBIED/SUICIDE/non-IED) | Partially implemented | Economy/lead flow includes family handling, but contract and consistency need normalization pass. |
| Threat schema/spec/version drift | Partially implemented | Current implementation appears broader than locked baseline schema. |
| Persistence/reset/migration hardening | Partially implemented | Persistence patterns exist; migration/reset hardening evidence needs closure. |
| Dedicated/JIP/restart validation evidence | Validation-only | Dedicated/JIP/restart closure remains a required gate. |
| Threat Economy operator tooling/observability | Partially implemented | Core economy logic exists; operator-facing completion criteria/tooling need explicit plan. |
| Virtual OpFor pool completion/documentation/admin surface | Partially implemented | Virtual pool runtime exists; completion documentation and operator/debug package incomplete. |

---

## 4) Epic structure and sequencing

Execution order is risk-first: contract/API correctness -> lifecycle correctness -> UI/operator surfacing -> normalization -> persistence hardening -> evidence closure.

1. **Epic 1:** Threat API and contract completion
2. **Epic 2:** IED suspicious-object lifecycle audit and explicit execution contract
3. **Epic 3:** Threat UI / TOC / S2 surfacing
4. **Epic 4:** Threat family normalization
5. **Epic 5:** Threat persistence / reset / migration / restart hardening
6. **Epic 6:** Threat validation and evidence closure
7. **Epic 7:** Threat Economy operator tooling and observability
8. **Epic 8:** Virtual OpFor pool completion and documentation

Dependency notes:
- Epic 1 feeds Epics 3, 4, 7 (shared API/event contract).
- Epic 2 feeds Epics 3, 5, 6 (lifecycle contract + evidence shape).
- Epic 5 must complete before Epic 6 closure evidence is considered final.
- Epics 7 and 8 can proceed in parallel after Epic 1 contract boundaries are set.

---

## 5) PR slicing model (one PR per epic for planning artifacts)

This decomposition intentionally defines **docs/planning PRs only** at this stage.

| PR | Scope | Artifact |
|---|---|---|
| PR-E1 | Epic 1 planning only | `docs/planning/threat/epics/Epic_1_Threat_API_Contract.md` |
| PR-E2 | Epic 2 planning only | `docs/planning/threat/epics/Epic_2_IED_Lifecycle_Contract.md` |
| PR-E3 | Epic 3 planning only | `docs/planning/threat/epics/Epic_3_Threat_UI_Surfacing.md` |
| PR-E4 | Epic 4 planning only | `docs/planning/threat/epics/Epic_4_Threat_Family_Normalization.md` |
| PR-E5 | Epic 5 planning only | `docs/planning/threat/epics/Epic_5_Persistence_Reset_Migration.md` |
| PR-E6 | Epic 6 planning only | `docs/planning/threat/epics/Epic_6_Validation_Evidence_Closure.md` |
| PR-E7 | Epic 7 planning only | `docs/planning/threat/epics/Epic_7_Threat_Economy_Operator_Tooling.md` |
| PR-E8 | Epic 8 planning only | `docs/planning/threat/epics/Epic_8_Virtual_OpFor_Pool_Completion.md` |

Companion PR metadata/templates:
- `docs/planning/threat/Threat_Epic_PR_Templates_2026-05-13.md`

---

## 6) Epic index

- [Epic 1 — Threat API and contract completion](./epics/Epic_1_Threat_API_Contract.md)
- [Epic 2 — IED suspicious-object lifecycle audit and explicit execution contract](./epics/Epic_2_IED_Lifecycle_Contract.md)
- [Epic 3 — Threat UI / TOC / S2 surfacing](./epics/Epic_3_Threat_UI_Surfacing.md)
- [Epic 4 — Threat family normalization](./epics/Epic_4_Threat_Family_Normalization.md)
- [Epic 5 — Threat persistence / reset / migration / restart hardening](./epics/Epic_5_Persistence_Reset_Migration.md)
- [Epic 6 — Threat validation and evidence closure (dedicated/JIP/restart/tests)](./epics/Epic_6_Validation_Evidence_Closure.md)
- [Epic 7 — Threat Economy operator tooling and observability](./epics/Epic_7_Threat_Economy_Operator_Tooling.md)
- [Epic 8 — Virtual OpFor pool completion and documentation](./epics/Epic_8_Virtual_OpFor_Pool_Completion.md)

---

## 7) Acceptance criteria for this decomposition package

- [ ] All eight epics have explicit scope boundaries and non-goals.
- [ ] Each epic distinguishes implemented vs partial vs missing vs validation-only work.
- [ ] Each epic defines PR-sized work packages and deliverables.
- [ ] Each epic includes explicit validation evidence requirements.
- [ ] Dependencies and execution order are documented.
- [ ] No runtime implementation is claimed complete without evidence.

---

## 8) Risk controls for follow-on implementation PRs

- Keep server as single writer for threat authoritative state.
- Do not add or expand RemoteExec surfaces without explicit security review and allowlist updates.
- Keep UI paths read-only against authoritative state.
- Treat dedicated/JIP/restart checks as closure gates, not optional follow-up.
