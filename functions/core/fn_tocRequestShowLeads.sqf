/*
    Server: show current lead pool to the requesting client.

    This is intentionally simple (hint-based) as a debug/TOC operator tool.
*/

if (!isServer) exitWith {false};

if (isNil "ARC_fnc_rpcValidateSender") then { ARC_fnc_rpcValidateSender = compile preprocessFileLineNumbers "functions\core\fn_rpcValidateSender.sqf"; };

// Optional: explicit calling unit (preferred). Fallback maps remote owner.
params [ ["_caller", objNull, [objNull]] ];

if (!isNil "remoteExecutedOwner") then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if (isNull _caller) then
        {
            {
                if (owner _x == _reo) exitWith { _caller = _x; };
            } forEach allPlayers;
        };

        // RemoteExec-only validation path: requires remoteExecutedOwner context.
        if (!([_caller, "ARC_fnc_tocRequestShowLeads", "Show leads rejected: sender verification failed.", "TOC_SHOW_LEADS_SECURITY_DENIED", true] call ARC_fnc_rpcValidateSender)) exitWith {false};

        private _isOmni = [_caller, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
        private _can = _isOmni || { [_caller] call ARC_fnc_rolesCanApproveQueue } || { [_caller] call ARC_fnc_rolesIsTocS2 } || { [_caller] call ARC_fnc_rolesIsTocCommand };
        if (!_can) exitWith {false};
    };
};

[] call ARC_fnc_leadPrune;

private _leads = ["leadPool", []] call ARC_fnc_stateGet;
if (!(_leads isEqualType [])) then { _leads = []; };

private _txt = "";

if (_leads isEqualTo []) then
{
    _txt = "Lead Pool: (empty)";
}
else
{
    _txt = "Lead Pool:\n";
    {
        _x params ["_id", "_type", "_disp", "_pos", ["_strength", 0.5], ["_createdAt", -1], ["_expiresAt", -1], ["_srcTask", ""], ["_srcType", ""], ["_threadId", ""], ["_tag", ""]];

        private _grid = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "????" };

        private _mins = -1;
        if (_expiresAt > 0) then
        {
            _mins = floor ((_expiresAt - serverTime) / 60);
        };

        private _ttl = if (_mins < 0) then {"?"} else { str _mins };

        private _thrTxt = if (_threadId isEqualType "" && { !(_threadId isEqualTo "") }) then { format [" %1", _threadId] } else {""};
        private _tagTxt = if (_tag isEqualType "" && { !(_tag isEqualTo "") }) then { format [" [%1]", toUpper _tag] } else {""};
        _txt = _txt + format ["- %1%2 | %3%4 | %5 | STR %6 | %7m | %8\n", _id, _thrTxt, toUpper _type, _tagTxt, _grid, (round (_strength * 100)), _ttl, _disp];
    } forEach _leads;
};

// Send hint to the requesting client only.
// NOTE: In hosted/SP testing, remoteExecutedOwner can be -1 because the code isn't truly "remote".
// Fall back to broadcasting to clients in that case, so the operator still sees the output.
private _owner = if (!isNull _caller) then { owner _caller } else { remoteExecutedOwner };

// Defensive fallback: if we couldn't resolve a sane client owner ID, broadcast to all clients.
// (Client owner IDs are typically >= 3; server is usually 2.)
if (_owner <= 2) then { _owner = -2; };

[_txt] remoteExec ["ARC_fnc_clientHint", _owner];

true
