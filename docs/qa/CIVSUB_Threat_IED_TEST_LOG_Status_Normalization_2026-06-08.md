# CIVSUB / Threat / IED TEST-LOG Status Normalization — 2026-06-08

**Mode:** J — Operations / Config / Data Maintenance  
**Scope:** Status-label normalization for the CIVSUB / Threat / IED reliability sweep evidence record.  
**Runtime behavior changes:** None.

---

## 1) Purpose

The CIVSUB / Threat / IED reliability sweep uses `BLOCKED_RUNTIME` to distinguish unavailable Arma runtime evidence from other blocked or pending review states.

This normalization record proposes canonical wording for the dated `tests/TEST-LOG.md` entry. Note: `tests/TEST-LOG.md` currently defines the allowed Result labels as `PASS`, `FAIL`, or `BLOCKED`; update that policy header before applying new labels like `PENDING` or `BLOCKED_RUNTIME` in the canonical log.

---

## 2) Intended status labels

| Check | Intended status | Reason |
|---|---|---|
| Reliability sweep document | `PASS` | The checklist/evidence contract exists. |
| Static review | `PENDING` | Static review is a reviewer action, not a runtime block. |
| Hosted MP runtime | `BLOCKED_RUNTIME` | Arma hosted runtime was unavailable in the connector environment. |
| Dedicated/JIP runtime | `BLOCKED_RUNTIME` | Dedicated/JIP operator run is required. |
| Adaptive behavior gate | `PASS` | The sweep gates adaptive behavior until evidence exists. |
| Overall result | `BLOCKED_RUNTIME` | The sweep does not prove live coupling until hosted/dedicated/JIP evidence is collected. |

---

## 3) Corrected TEST-LOG row set

Use the following row set when updating the canonical `tests/TEST-LOG.md` entry:

```md
| # | Check | Command / Step | Result | Notes |
|---|-------|----------------|--------|-------|
| 1 | Reliability sweep document | Add `docs/qa/CIVSUB_Threat_IED_Reliability_Sweep_2026-06-08.md` | PASS | Checklist/evidence contract only. No runtime behavior changed. |
| 2 | Static review | Review CIVSUB delta, Threat record, Threat economy, IED evidence/disposition, and protected-zone paths | PENDING | Requires reviewer execution. |
| 3 | Hosted MP runtime | Run CIVSUB district activation, contact/delta path, threat scheduler, IED evidence/disposition flow | BLOCKED_RUNTIME | Arma runtime unavailable in this environment. |
| 4 | Dedicated/JIP runtime | Run dedicated fresh start, JIP during active CIVSUB/threat/evidence state, reconnect/restart checks | BLOCKED_RUNTIME | Dedicated/JIP operator run required. |
| 5 | Adaptive behavior gate | Confirm adaptive COIN behavior remains blocked until reliability failures are closed or scoped | PASS | This sweep defines the gate and does not implement adaptive behavior. |
```

Canonical result line:

```md
**Result:** BLOCKED_RUNTIME — sweep defines the evidence contract; hosted MP, dedicated, JIP, reconnect, and persistence validation must be executed in Arma and recorded here.
```

---

## 4) Current addendum status

`tests/TEST-LOG-CIVSUB_THREAT_IED_2026-06-08.md` already uses the normalized `PENDING` / `BLOCKED_RUNTIME` status split and is retained as a historical addendum.

---

## 5) Runtime validation rule

Do not claim CIVSUB / Threat / IED coupling is validated until the hosted MP and dedicated/JIP checks move from `BLOCKED_RUNTIME` to `PASS` with RPT excerpts and observer notes.
