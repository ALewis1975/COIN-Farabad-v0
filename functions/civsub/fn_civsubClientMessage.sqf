/*
    ARC_fnc_civsubClientMessage

    Client-side helper for CIVSUB interactions.

    Params:
      0: text (string)
      1: mode (string, optional) "CHAT" | "HINT"
*/

if (!hasInterface) exitWith {false};

params [
    ["_text", "", [""]],
    ["_mode", "CHAT", [""]]
];

if (_text isEqualTo "") exitWith {false};

switch (toUpper _mode) do
{
    case "HINT": { hintSilent _text; };
    default { systemChat _text; };
};

true
