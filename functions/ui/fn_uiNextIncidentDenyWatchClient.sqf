/*
    ARC_fnc_uiNextIncidentDenyWatchClient

    Client: passive watcher that surfaces `ARC_pub_nextIncidentLastDenied`
    to TOC-authorized operators as a client toast (Dedicated Server
    Activation Plan — Track 3 observability follow-up).

    Behaviour:
      - Only toasts on NEW denials published after this client connected
        (the stamp seen at init is treated as already-seen).
      - Skips the original requester: they already receive a direct
        server-side toast on the deny path of ARC_fnc_tocRequestNextIncident.
      - Role-gated: TOC queue approvers (S3/Command) and OMNI only.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith { false };

// Once-per-mission-session guard (uiNamespace persists across mission restarts
// on a client, so store a per-mission token rather than a boolean).
private _sessionTok = format ["%1|%2", missionName, missionStart];
if ((uiNamespace getVariable ["ARC_console_denyWatchInit", ""]) isEqualTo _sessionTok) exitWith { true };
uiNamespace setVariable ["ARC_console_denyWatchInit", _sessionTok];

[] spawn {
    // Seed last-seen so stale pre-join denials don't toast on connect/JIP.
    private _seed = missionNamespace getVariable ["ARC_pub_nextIncidentLastDenied", []];
    private _lastStamp = -1;
    if (_seed isEqualType [] && { (count _seed) >= 1 } && { (_seed select 0) isEqualType 0 }) then
    {
        _lastStamp = _seed select 0;
    };

    while { true } do
    {
        uiSleep 2;

        private _deny = missionNamespace getVariable ["ARC_pub_nextIncidentLastDenied", []];
        if (_deny isEqualType [] && { (count _deny) >= 3 }) then
        {
            private _stamp = _deny select 0;
            if ((_stamp isEqualType 0) && { _stamp > _lastStamp }) then
            {
                _lastStamp = _stamp;

                // Skip the requester — they already received the direct deny toast.
                private _denyOwner = -1;
                if ((count _deny) >= 4 && { (_deny select 3) isEqualType 0 }) then
                {
                    _denyOwner = _deny select 3;
                };
                private _isRequester = (_denyOwner > 0) && { _denyOwner isEqualTo clientOwner };

                private _canSee = false;
                if (!isNil "ARC_fnc_rolesCanApproveQueue") then
                {
                    _canSee = [player] call ARC_fnc_rolesCanApproveQueue;
                };
                if (!_canSee && { !isNil "ARC_fnc_rolesHasGroupIdToken" }) then
                {
                    private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
                    if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
                    {
                        if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _canSee = true; };
                    } forEach _omniTokens;
                };

                if (_canSee && { !_isRequester }) then
                {
                    private _code = if ((_deny select 1) isEqualType "") then { toUpper (_deny select 1) } else { "UNKNOWN" };
                    private _detail = if ((_deny select 2) isEqualType "") then { _deny select 2 } else { "" };
                    private _msg = if (_detail isEqualTo "") then
                    {
                        format ["Incident generation denied: %1", _code]
                    }
                    else
                    {
                        format ["Incident generation denied: %1 — %2", _code, _detail]
                    };
                    ["TOC", _msg, 7] call ARC_fnc_clientToast;
                };
            };
        };
    };
};

true
