/*
    ARC_fnc_uiConsoleFormatStatusChip

    Shared helper: build R/A/G chip HTML with text + color.

    Replaces AIR-specific _statusColor helper and chip formatting.

    Params:
      0: STRING — chip label (e.g. "RWY", "ARR")
      1: STRING — chip value (e.g. "OPEN", "3")
      2: STRING — status key for color mapping: "GREEN", "AMBER", "RED", or
                  any of the known status keywords (CRITICAL, HOLD, etc.)

    Returns:
      STRING — structured text HTML for the chip
*/

params [
    ["_label", "", [""]],
    ["_value", "", [""]],
    ["_status", "GREEN", [""]]
];

private _s = toUpper _status;

// Map status to color hex
private _color = "#4CAF50"; // default green
if (_s in ["CRITICAL", "CONFLICT", "BLOCKED", "HOLD", "OCCUPIED", "RED", "DEGRADED"]) then {
    _color = "#E74C3C";
};
if (_s in ["CAUTION", "HOLDING", "RESERVED", "PRIORITY", "STALE", "AMBER", "DELAYED"]) then {
    _color = "#F5A623";
};

format ["<t color='%1' size='0.95'>%2: %3</t>", _color, _label, _value]
