/*
    ARC_fnc_uiConsoleFormatRow

    Shared helper: format a list row from a tuple with column alignment.

    Builds a padded row string from an array of column values and widths.
    Replaces per-painter inline format strings.

    Params:
      0: ARRAY — columns, each element: [value, width] or just value
         - value: STRING — column text
         - width: NUMBER — target character width (right-padded with spaces)
         If element is a plain STRING, default width 12 is used.

    Returns:
      STRING — formatted row
*/

params [
    ["_columns", [], [[]]]
];

if ((count _columns) == 0) exitWith { "" };

private _out = "";
{
    private _val = "";
    private _w = 12;
    if (_x isEqualType []) then {
        if ((count _x) >= 1) then { _val = _x select 0; };
        if ((count _x) >= 2) then { _w = _x select 1; };
    } else {
        if (_x isEqualType "") then { _val = _x; } else { _val = str _x; };
    };

    if (!(_val isEqualType "")) then { _val = str _val; };

    // Pad or truncate to target width
    private _len = count _val;
    if (_len < _w) then {
        private _pad = _w - _len;
        private _spaces = "";
        for "_i" from 1 to _pad do { _spaces = _spaces + " "; };
        _val = _val + _spaces;
    };
    if (_len > _w && { _w > 3 }) then {
        _val = (_val select [0, _w - 2]) + "..";
    };

    _out = _out + _val;
} forEach _columns;

_out
