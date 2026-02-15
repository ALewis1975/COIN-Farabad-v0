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

private _extra = missionNamespace getVariable ["ARC_queueApproverTokens", []];
if (_extra isEqualType [] && { (count _extra) > 0 }) then
{
    _ok = _ok || ([_unit, _extra] call ARC_fnc_rolesHasGroupIdToken);
};

_ok
