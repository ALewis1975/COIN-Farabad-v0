/*
    ARC_fnc_uiConsoleGetPair

    Shared helper: read a key-value pair from an array-of-pairs.

    Replaces per-painter _getPair closures duplicated in 5+ files.

    Params:
      0: ARRAY  — pairs array (e.g. [["key1", val1], ["key2", val2], ...])
      1: STRING — key to find
      2: ANY    — default value if key not found

    Returns:
      ANY — the value for the key, or default
*/

params [
    ["_pairs", [], [[]]],
    ["_k", "", [""]],
    ["_def", nil]
];

if (!(_pairs isEqualType [])) exitWith { _def };

private _v = _def;
{
    if (_x isEqualType [] && { (count _x) >= 2 } && { (_x select 0) isEqualTo _k }) exitWith {
        _v = _x select 1;
    };
} forEach _pairs;
_v
