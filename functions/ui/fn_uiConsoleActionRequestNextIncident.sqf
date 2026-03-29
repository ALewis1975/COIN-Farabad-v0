/*
    ARC_fnc_uiConsoleActionRequestNextIncident

    Client: request TOC to generate the next incident.

    Server validation remains authoritative.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// UI event handlers are unscheduled; BIS_fnc_guiMessage requires scheduled.
if (!canSuspend) exitWith { _this spawn ARC_fnc_uiConsoleActionRequestNextIncident; false };

// OMNI override (playtesting)
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
private _isOmni = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; };
} forEach _omniTokens;

private _canApprove = _isOmni || { [player] call ARC_fnc_rolesCanApproveQueue };
if (!_canApprove) exitWith
{
    ["TOC", "Incident generation restricted to TOC (S3/Command) or OMNI."] call ARC_fnc_clientToast;
    false
};

// Do not spam requests while an incident is active.
private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""]; 
if (!(_taskId isEqualType "")) then { _taskId = ""; };
if (!(_taskId isEqualTo "")) exitWith
{
    ["TOC", "An incident is already active. Close it (and complete SITREP workflow) before generating a new one."] call ARC_fnc_clientToast;
    false
};

private _ok = ["Generate the next incident now?", "TOC", true, true] call BIS_fnc_guiMessage;
if (!_ok) exitWith {false};

private _requestStamp = diag_tickTime;
private _myOwner = clientOwner;

[player] remoteExec ["ARC_fnc_tocRequestNextIncident", 2];
["TOC", "Requested next incident: pending server decision."] call ARC_fnc_clientToast;

[_requestStamp, _myOwner] spawn
{
    params ["_stamp", "_ownerId"];


// sqflint-compatible helpers
private _trimFn  = compile "params ['_s']; trim _s";
    private _timeoutAt = time + 8;
    private _found = false;

    waitUntil
    {
        uiSleep 0.15;

        private _res = missionNamespace getVariable ["ARC_pub_nextIncidentResult", []];
        if (_res isEqualType [] && { (count _res) >= 6 }) then
        {
            _res params ["_resStamp", "_resOwner", "_code", "_title", "_detail", "_allowed"];
            if ((_resStamp isEqualType 0) && { _resStamp >= _stamp } && { _resOwner isEqualTo _ownerId }) then
            {
                _found = true;
                uiNamespace setVariable ["ARC_console_lastNextIncidentResult", _res];

                private _msg = if (_detail isEqualType "" && { trim !(_detail isEqualTo "") }) then { [_detail] call _trimFn } else { "Server returned no detail." };
                private _hdr = if (_title isEqualType "" && { trim !(_title isEqualTo "") }) then { [_title] call _trimFn } else { "TOC" };

                if (_allowed isEqualType true && { _allowed }) then
                {
                    [_hdr, _msg, 5] call ARC_fnc_clientToast;
                }
                else
                {
                    [_hdr, _msg, 7] call ARC_fnc_clientToast;
                };
            };
        };

        _found || { time >= _timeoutAt }
    };

    if (!_found) then
    {
        ["TOC", "No server decision received yet. Check TOC/OPS panel for latest incident-generation status.", 6] call ARC_fnc_clientToast;
    };
};

true
