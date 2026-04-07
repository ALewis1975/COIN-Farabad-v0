/*
    ARC_fnc_uiConsoleButtonState

    Shared helper: set button label + enabled + tooltip in one call.

    Replaces 4-line patterns repeated 50+ times across painters.

    Params:
      0: CONTROL — button control
      1: STRING  — button text label
      2: BOOL    — enabled state
      3: BOOL    — visible state (default true)
      4: STRING  — tooltip text (default "")

    Returns:
      NOTHING
*/

params [
    ["_ctrl", controlNull, [controlNull]],
    ["_text", "", [""]],
    ["_enabled", true, [true]],
    ["_visible", true, [true]],
    ["_tooltip", "", [""]]
];

if (isNull _ctrl) exitWith {};

_ctrl ctrlSetText _text;
_ctrl ctrlEnable _enabled;
_ctrl ctrlShow _visible;
if (!(_tooltip isEqualTo "")) then {
    _ctrl ctrlSetTooltip _tooltip;
};
