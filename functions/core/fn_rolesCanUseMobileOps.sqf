/*
    ARC_fnc_rolesCanUseMobileOps

    Returns TRUE if the unit should have access to the mobile ops vehicle controls.

    Default access:
      - Queue approvers (S3 / Command) OR authorized leaders.

    Optional admin override:
      - missionNamespace ARC_mobileOpsAllowAdmins (default true)
      - serverCommandAvailable "#kick" (logged-in admin)

    Optional group token override:
      - missionNamespace ARC_mobileOpsApproverTokens : ARRAY of groupId tokens
        matched case-insensitively (e.g. ["REDFALCON TOC","REDFALCON S3"])

    Params:
      0: OBJECT unit

    Returns:
      BOOL
*/

params [ ["_unit", objNull, [objNull]] ];
if (isNull _unit) exitWith {false};

private _ok = ([_unit] call ARC_fnc_rolesCanApproveQueue) || ([_unit] call ARC_fnc_rolesIsAuthorized);

// Optional extra group tokens
private _extra = missionNamespace getVariable ["ARC_mobileOpsApproverTokens", []];
if (_extra isEqualType [] && { (count _extra) > 0 }) then
{
    _ok = _ok || ([_unit, _extra] call ARC_fnc_rolesHasGroupIdToken);
};

// Optional admin override for testing / mission staff
private _allowAdmins = missionNamespace getVariable ["ARC_mobileOpsAllowAdmins", true];
if (_allowAdmins) then
{
    _ok = _ok || (serverCommandAvailable "#kick");
};

_ok
