/*
    ARC_fnc_uiConsoleFormatEmptyState

    Shared helper: render a distinct empty-state row for a listbox section.

    When a data section is empty (no arrivals, no orders, etc.), use this to
    add a visually distinct row instead of blank space.

    Params:
      0: CONTROL — listbox control
      1: STRING  — empty-state message (e.g. "No arrivals inbound")

    Returns:
      NOTHING
*/

params [
    ["_ctrl", controlNull, [controlNull]],
    ["_msg", "— No data —", [""]]
];

if (isNull _ctrl) exitWith {};

private _idx = _ctrl lbAdd format ["  %1", _msg];
if (_idx >= 0) then {
    _ctrl lbSetColor [_idx, [0.5, 0.5, 0.5, 0.7]];
    _ctrl lbSetData [_idx, ""];
};
