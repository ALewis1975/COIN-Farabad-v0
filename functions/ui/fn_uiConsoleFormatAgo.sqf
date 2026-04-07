/*
    ARC_fnc_uiConsoleFormatAgo

    Shared helper: format a serverTime timestamp as "Xs ago" / "Xm Ys ago".

    Replaces AIR _fmtAgo and similar closures duplicated in 3+ painters.

    Params:
      0: NUMBER — serverTime timestamp

    Returns:
      STRING — human-readable age string
*/

params [
    ["_t", -1, [0]]
];

if (_t < 0) exitWith { "-" };

private _age = (serverTime - _t) max 0;

if (_age < 5) exitWith { "just now" };
if (_age < 60) exitWith { format ["%1s ago", round _age] };
format ["%1m %2s ago", floor (_age / 60), (round _age) mod 60]
