/*
    ARC_fnc_civsubDebugLog

    Wrapper for diag_log with CIVSUB prefix.

    Params:
      0: message (string)
*/

params [["_msg", "", [""]]];
if (_msg isEqualTo "") exitWith {false};

diag_log format ["[CIVSUB] %1", _msg];
true
