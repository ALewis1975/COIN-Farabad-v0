/*
    ARC_fnc_rolesCanApproveQueue

    Returns TRUE if the unit is allowed to approve/reject items in the TOC queue.

    Default rule (per design decisions):
      - S3 or Command authority

    Optional overrides:
      - missionNamespace ARC_queueApproverTokens: ARRAY of extra tokens to match
        against groupId (case-insensitive). Example: ["REDFALCON TOC"].

    Params:
      0: OBJECT unit

    Returns:
      BOOL
*/

params [ ["_unit", objNull, [objNull]] ];
if (isNull _unit) exitWith {false};

private _ok = ([_unit] call ARC_fnc_rolesIsTocS3) || ([_unit] call ARC_fnc_rolesIsTocCommand);

// BN command roles are allowed to execute TOC/CMD queue actions from the console.
private _bnTokens = missionNamespace getVariable [
    "ARC_consoleHQTokens",
    ["BNCMD", "BN COMMAND", "BNHQ", "BN CO", "BNCO", "BN CDR", "REDFALCON 6", "REDFALCON6", "FALCON 6", "FALCON6"]
];
if (!(_bnTokens isEqualType [])) then
{
    _bnTokens = ["BNCMD", "BN COMMAND", "BNHQ", "BN CO", "BNCO", "BN CDR", "REDFALCON 6", "REDFALCON6", "FALCON 6", "FALCON6"];
};

_ok = _ok || ([_unit, _bnTokens] call ARC_fnc_rolesHasGroupIdToken);

private _extra = missionNamespace getVariable ["ARC_queueApproverTokens", []];
if (_extra isEqualType [] && { (count _extra) > 0 }) then
{
    _ok = _ok || ([_unit, _extra] call ARC_fnc_rolesHasGroupIdToken);
};

_ok
