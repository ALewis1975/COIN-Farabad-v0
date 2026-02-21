# SQFLINT Compatibility Guide (Pre-Parser Guardrails)

This guide documents SQF constructs that are valid in-engine but have been problematic for `sqflint` parser compatibility in this repo.

Use this mapping before running `sqflint -e w` so compatibility issues are fixed consistently.

## Pattern mapping (disallowed/problematic → approved)

| Problematic construct | Why it is problematic | Approved equivalent |
|---|---|---|
| `findIf { ... }` | Older sqflint parser paths do not consistently parse `findIf` in mission scripts. | Use `forEach` + `_forEachIndex` and `exitWith` for first-match lookup. |
| Direct `trim _value` | `trim` operator parsing can fail in sqflint compatibility mode. | Wrap in compiled helper: `_trimFn = compile "params ['_s']; trim _s";` and call `[_value] call _trimFn`. |
| Direct `fileExists _path` | Similar parser-compat issue as `trim` for some sqflint versions. | Wrap in compiled helper and call through that helper. |
| HashMap method form `_map getOrDefault [k, d]` | Method-style parsing can fail. | Use call-form: `[map, key, default] call getOrDefault`. |

## Examples from current code

### 1) `findIf` replacement (`fn_uiConsoleAirPaint.sqf`)

```sqf
private _idx = -1;
{ if ((_x isEqualType []) && { (count _x) >= 5 } && { ((_x param [0, ""]) isEqualTo _lane) }) exitWith { _idx = _forEachIndex; }; } forEach _rows;
if (_idx < 0) exitWith { [_lane, "AUTO", "", "", -1] };
_rows select _idx
```

### 2) `trim` wrapper (`fn_uiConsoleAirPaint.sqf`, `fn_uiConsoleCommandPaint.sqf`, `fn_uiConsoleDashboardPaint.sqf`, `fn_civsubContactActionQuestion.sqf`)

```sqf
private _trimFn = compile "params ['_s']; trim _s";
...
_airModeList = toUpper ([_airModeList] call _trimFn);
```

### 3) HashMap `getOrDefault` call-form (`fn_civsubContactActionQuestion.sqf`)

```sqf
private _hg = compile "params ['_h','_k','_d']; [_h, _k, _d] call getOrDefault";
private _qidRaw = [_pl, "qid", ""] call _hg;
```

## Local + CI preflight order

1. Run compatibility scanner first:
   - `python3 scripts/dev/sqflint_compat_scan.py --strict <changed sqf files...>`
2. Then run lint:
   - `sqflint -e w <changed sqf files...>`

The scanner is intentionally lightweight and pattern-based. It catches known parser-compat risks early and provides approved equivalents before lint output becomes noisy.
