/*
    ARC_fnc_iedClientAddEvidenceAction

    Client: attach a “Collect evidence” action to the evidence prop.
    This is remoteExec'd by the server (JIP safe).

    Params:
        0: OBJECT - evidence prop

    Returns:
        BOOL
*/
if (!hasInterface) exitWith {false};

params [
    ["_obj", objNull]
];

if (isNull _obj) exitWith {false};
if !(_obj getVariable ["ARC_isIedEvidence", false]) exitWith {false};

private _nid = netId _obj;
if (_nid isEqualTo "") exitWith {false};

private _key = format ["ARC_iedEvAct_%1", _nid];
if (!isNil { missionNamespace getVariable _key }) exitWith {true};

private _id = _obj addAction [
    "Collect evidence",
    {
        params ["_target", "_caller", "_actionId", "_args"];
        _args params ["_nid"];

        [_nid, _caller] remoteExec ["ARC_fnc_iedCollectEvidence", 2];
    },
    [_nid],
    1.4,
    true,
    true,
    "",
    "alive _target && {_this distance _target < 3} && {!(_target getVariable ['ARC_iedEvidenceCollected', false])}",
    3
];

missionNamespace setVariable [_key, _id];
true
