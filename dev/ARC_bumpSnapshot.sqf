/*
    dev\ARC_bumpSnapshot.sqf

    Force a state change + republish ARC_pub_state so your client snapshot watcher refreshes.

    Run in SP/hosted (where isServer is true):
      [] execVM "dev\ARC_bumpSnapshot.sqf";

    ALWAYS logs to RPT via [ARC][DEV].
*/

private _log = {
    params [["_chan","DEV"], ["_msg",""], ["_args",[]], ["_lvl","INFO"]];
    private _text = _msg;
    if (_args isEqualType [] && {count _args > 0}) then { _text = format ([_msg] + _args); };
    diag_log format ["[ARC][DEV][%1][%2] %3", _chan, _lvl, _text];
};

if (!isServer) exitWith {
    ["SYS","Not server: run this in SP/hosted so state changes are authoritative.",[], "WARN"] call _log;
    false
};

private _leg = ["govLegitimacy", 0.45] call ARC_fnc_stateGet;
if !(_leg isEqualType 0) then { _leg = 0.45; };

_leg = _leg + 0.01;
if (_leg > 1) then { _leg = 1; };

["govLegitimacy", _leg] call ARC_fnc_stateSet;

[] call ARC_fnc_publicBroadcastState;

private _upd = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1];

["SYS","Bumped govLegitimacy to %1 and republished snapshot (updatedAt=%2).",[_leg,_upd],"INFO"] call _log;

if (hasInterface) then { hintSilent format ["Bumped govLegitimacy to %1. Snapshot republished.", _leg]; };

true
