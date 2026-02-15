/*
    ARC_fnc_intelClientNotify

    Client: lightweight notification for TOC/unit messages.

    Params:
      0: STRING message

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [["_msg", ""]];
if (!(_msg isEqualType "")) then { _msg = str _msg; };

systemChat format ["[TOC] %1", _msg];

true
