/*
    Validate canonical district identifiers.

    Canonical forms:
      - D01..D20 (always accepted)
      - D00 (optional sentinel, caller-controlled via _allowSentinel)

    Params:
      0: ANY  district id candidate
      1: BOOL allowSentinel (default false)

    Returns:
      BOOL
*/

params [
    ["_districtId", ""],
    ["_allowSentinel", false, [false]]
];

if !(_districtId isEqualType "") exitWith {false};

private _id = toUpper ([_districtId] call _trimFn);
if (_id isEqualTo "") exitWith {false};
if (_allowSentinel && { _id isEqualTo "D00" }) exitWith {true};

if (!((count _id) isEqualTo 3)) exitWith {false};
if (!((_id select [0, 1]) isEqualTo "D")) exitWith {false};

private _numStr = _id select [1, 2];
private _num = parseNumber _numStr;
if (_num <= 0 || { _num > 20 }) exitWith {false};


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
private _expectedNumStr = if (_num < 10) then {
    "0" + (str _num)
} else {
    str _num
};

(_numStr isEqualTo _expectedNumStr)
