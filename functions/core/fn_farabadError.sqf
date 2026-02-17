/*
    ARC_fnc_farabadError

    Convenience helper for ERROR-level FARABAD logs.

    Params:
      0: STRING - channel
      1: STRING - message
      2: ANY    - meta payload (optional, default [])
*/

params [
    ["_channel", "CORE", [""]],
    ["_message", "", [""]],
    ["_meta", []]
];

[_channel, "ERROR", _message, _meta] call ARC_fnc_farabadLog
