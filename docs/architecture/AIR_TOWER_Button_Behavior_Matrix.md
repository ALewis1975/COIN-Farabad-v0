# AIR / TOWER Button Behavior Matrix

**Date:** 2026-04-06  
**Status:** Locked for implementation

---

## 1) Mode model

AIR/TOWER has two authority layers:

- `ARC_console_airMode`: `PILOT` or `TOWER`
- `ARC_console_airSubmode`: `AIRFIELD_OPS`, `CLEARANCES`, or `DEBUG`

If `airMode == "PILOT"`, submode is ignored.

---

## 2) Primary / secondary button rules

### PILOT mode

| Selection | Primary | Secondary |
|---|---|---|
| `PACT` | `SEND REQUEST` | `MODE: TOWER` if tower-capable, else `REFRESH` |
| `PWRN` | `SEND REQUEST` | same as above |
| anything else | `SEND REQUEST` | same as above |

### TOWER / AIRFIELD_OPS

| Selection | Primary | Secondary |
|---|---|---|
| any row, control authority present | `HOLD` or `RELEASE` (toggle by current hold state) | `VIEW: <next mode>` |
| any row, read-only | `READ-ONLY` | `REFRESH` |

### TOWER / CLEARANCES

| Selection | Primary | Secondary |
|---|---|---|
| `REQ` | `APPROVE` | `DENY` |
| `FLT` | `EXPEDITE` | `CANCEL` |
| `LANE` | `CLAIM` | `RELEASE` |
| `MODE` / non-action rows | `HOLD` or `RELEASE` when allowed, else `READ-ONLY` | `VIEW: <next mode>` |

### TOWER / DEBUG

| Selection | Primary | Secondary |
|---|---|---|
| any row | `READ-ONLY` | `VIEW: <next mode>` |

---

## 3) Visibility rules

| User capability | AIR tab | Primary | Secondary |
|---|---|---|---|
| no AIR read, no AIR pilot | hidden | hidden | hidden |
| AIR read-only | visible | visible with clean `READ-ONLY` label | visible with `REFRESH` |
| AIR control | visible | visible and enabled per matrix | visible and enabled per matrix |
| AIR pilot only | visible | visible and enabled | visible and enabled |

---

## 4) Non-negotiable label rules

- Never show `NO HOLD AUTH`
- Never show `NO QUEUE AUTH`
- Never show `NO ACCESS`
- Use `READ-ONLY` for visible but unavailable actions
- Use explicit mode labels: `VIEW: AIRFIELD OPS`, `VIEW: CLEARANCES`, `VIEW: DEBUG`

