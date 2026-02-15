/*
    Runs on server.
    Forces a save. Useful for admin / TOC operators.

    Phase 6:
      - Also forces CIVSUB persistence save (if enabled), so "Save World" includes CIVSUB.
*/

if (!isServer) exitWith {false};

// Dedicated MP hardening:
// Resolve requestor from network sender and require TOC approver authority.
private _requestor = objNull;
if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        {
            if (owner _x == _reo) exitWith { _requestor = _x; };
        } forEach allPlayers;

        if (isNull _requestor) exitWith {false};

        private _isOmni = [_requestor, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
        private _can = _isOmni || { [_requestor] call ARC_fnc_rolesCanApproveQueue };
        if (!_can) exitWith {false};
    };
};

if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
{
    // Best-effort: do not hard error if CIVSUB not initialized yet
    if (!isNil "ARC_fnc_civsubPersistSave") then { [] call ARC_fnc_civsubPersistSave; };
};

[] call ARC_fnc_stateSave
