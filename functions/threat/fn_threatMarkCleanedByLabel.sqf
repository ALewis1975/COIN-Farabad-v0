/*
    Threat helper: mark CLEANED from a cleanup queue label.

    Params:
        0: STRING cleanup_label  (expected prefix "THREAT:")
        1: STRING netId (optional; for note/debug only)

    Returns:
        BOOL handled
*/

if (!isServer) exitWith {false};

params [
    ["_label", ""],
    ["_nid", ""]
];

if (!(_label isEqualType "") || { _label isEqualTo "" }) exitWith {false};

// Must start with THREAT:
if (!((_label select [0,7]) isEqualTo "THREAT:")) exitWith {false};

private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
if (!_enabled) exitWith {false};

private _parts = _label splitString ":";

if ((count _parts) < 3) exitWith {false};
if (!((_parts # 0) isEqualTo "THREAT")) exitWith {false};

// _parts: ["THREAT", "<type>", "THR", "<district>", "<seq6>"]
private _type = _parts # 1;
private _rest = _parts select [2, (count _parts) - 2];
private _threatId = _rest joinString ":";

if (_threatId isEqualTo "") exitWith {false};

private _note = "CLEANUP_TICK";
if (!(_nid isEqualTo "")) then { _note = format ["%1 nid=%2", _note, _nid]; };

[_threatId, "CLEANED", _note] call ARC_fnc_threatUpdateState;

true
