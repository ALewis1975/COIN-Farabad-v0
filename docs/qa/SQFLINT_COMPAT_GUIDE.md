# SQFLINT Compatibility Guide (Pre-Parser Guardrails)

This guide documents SQF constructs that are valid in-engine but have been problematic for `sqflint` parser compatibility in this repo.

Use this mapping before running `sqflint -e w` so compatibility issues are fixed consistently.

---

## Pattern mapping (disallowed/problematic → approved)

| Problematic construct | Why it is problematic | Approved equivalent |
|---|---|---|
| `findIf { ... }` | sqflint does not consistently parse `findIf`. | `forEach` + `_forEachIndex` + `exitWith` (see §1). |
| `toUpperANSI` / `toLowerANSI` | sqflint does not recognise these operators. | `toUpper` / `toLower` (identical for ASCII). |
| Bare `createHashMapFromArray [...]` | sqflint cannot parse this as an operator. | `_hmCreate` compile helper (see §4). |
| Bare `keys _map` | sqflint cannot parse `keys` as an operator. | `_keysFn` compile helper (see §5). |
| Direct `trim _value` | `trim` parsing can fail in sqflint compatibility mode. | `_trimFn` compile helper (see §2). |
| Direct `fileExists _path` | Similar parser-compat issue as `trim`. | `_fileExistsFn` compile helper (see §2). |
| HashMap method form `_map getOrDefault [k, d]` | Method-style parsing can fail. | `_hg` compile helper (see §3). |
| `isNotEqualTo` | sqflint does not recognise this operator. | `!(_a isEqualTo _b)` |

---

## Compile helper reference

Every helper is declared at the top of the file (after `exitWith` guards, before logic) using `compile "..."` so sqflint never sees the problematic operator.

| Helper name | Compile string | Call pattern |
|---|---|---|
| `_trimFn` | `compile "params ['_s']; trim _s"` | `[_value] call _trimFn` |
| `_fileExistsFn` | `compile "params ['_p']; fileExists _p"` | `[_path] call _fileExistsFn` |
| `_hg` | `compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]"` | `[_map, _key, _default] call _hg` |
| `_hmCreate` | `compile "params ['_a']; createHashMapFromArray _a"` | `[[key1,val1,...]] call _hmCreate` |
| `_hmFrom` | `compile "private _pairs = _this; createHashMapFromArray _pairs"` | `[[k,v],[k,v]] call _hmFrom` |
| `_keysFn` | `compile "params ['_m']; keys _m"` | `[_map] call _keysFn` |

**Important notes:**
- The parentheses around `_h` in `_hg` are **required** for correct parsing: `(_h) getOrDefault [_k, _d]`.
- `_hmFrom` uses `private _pairs = _this` (not `params`) because call sites pass array-of-pairs directly.
- Never place helper declarations between an `exitWith` keyword and its `{...}` block.

---

## Examples from current code

### 1) `findIf` replacement

```sqf
// BEFORE (banned):
private _idx = _array findIf { condition };

// AFTER (approved):
private _idx = -1;
{ if (condition) exitWith { _idx = _forEachIndex; }; } forEach _array;
```

Source: `fn_uiConsoleAirPaint.sqf`, `fn_threatCreateFromTask.sqf`, and 57 other files.

### 2) `trim` / `fileExists` wrappers

```sqf
private _trimFn = compile "params ['_s']; trim _s";
_airModeList = toUpper ([_airModeList] call _trimFn);
```

Source: `fn_uiConsoleAirPaint.sqf`, `fn_uiConsoleCommandPaint.sqf`, `fn_civsubContactActionQuestion.sqf`.

### 3) HashMap `getOrDefault` via `_hg`

```sqf
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
private _qidRaw = [_pl, "qid", ""] call _hg;
```

Source: `fn_civsubInteractCheckPapers.sqf`, `fn_civsubInteractDetain.sqf`, `fn_civsubSchedulerTick.sqf`.

### 4) `createHashMapFromArray` via `_hmCreate`

```sqf
private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _map = [[["key1","val1"],["key2","val2"]]] call _hmCreate;
```

Source: `fn_civsubIdentityTouch.sqf`, `fn_civsubInteractCheckPapers.sqf`, and 37 other files.

### 5) `keys` via `_keysFn`

```sqf
private _keysFn = compile "params ['_m']; keys _m";
private _allKeys = [_myMap] call _keysFn;
```

Source: `fn_civsubInteractHandoffSheriff.sqf`, `fn_civsubIdentityTouch.sqf`.

### 6) `toUpperANSI` / `toLowerANSI` replacement

```sqf
// BEFORE (banned):
private _upper = toUpperANSI _str;

// AFTER (approved — direct replacement, no helper needed):
private _upper = toUpper _str;
```

---

## Local + CI preflight order

1. Run compatibility scanner first:
   - `python3 scripts/dev/sqflint_compat_scan.py --strict <changed sqf files...>`
2. Then run lint:
   - `sqflint -e w <changed sqf files...>`

The scanner is intentionally lightweight and pattern-based. It catches known parser-compat risks early and provides approved equivalents before lint output becomes noisy.

### Scanner coverage

| Pattern | Scanner rule | Status |
|---------|-------------|--------|
| `findIf` | `findIf` | ✅ Covered |
| `trim` | `trim-operator` | ✅ Covered |
| `fileExists` | `fileExists-operator` | ✅ Covered |
| `getOrDefault` (method) | `hashmap-getOrDefault-method` | ✅ Covered |
| `isNotEqualTo` | `isNotEqualTo` | ✅ Covered |
| `toUpperANSI` | `toUpperANSI` | ✅ Covered |
| `toLowerANSI` | `toLowerANSI` | ✅ Covered |
| `#` indexing | `hash-index-operator` | ✅ Covered |
| `createHashMapFromArray` | `bare-createHashMapFromArray` | ✅ Covered |
| `keys _map` | — | ❌ Caught by sqflint only |
