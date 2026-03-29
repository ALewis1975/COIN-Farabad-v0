/*
    Client: show the current lead pool (and a bit of forensic context) using locally
    replicated variables.

    This exists because "hint" is local and server->client remoteExec can be blocked
    or flaky in hosted/SP testing.

    Reads:
      - missionNamespace ARC_leadPoolPublic
      - missionNamespace ARC_lastLeadCreatedPublic
      - missionNamespace ARC_lastLeadConsumedPublic
      - missionNamespace ARC_leadPoolPublicUpdatedAt

    Returns:
      BOOL

    Debug-only operator helper: prefers local HINT channel output for dense snapshots.
*/

if (!hasInterface) exitWith {false};

private _leads = missionNamespace getVariable ["ARC_leadPoolPublic", []];
private _lastC = missionNamespace getVariable ["ARC_lastLeadCreatedPublic", []];
private _lastX = missionNamespace getVariable ["ARC_lastLeadConsumedPublic", []];
private _upd   = missionNamespace getVariable ["ARC_leadPoolPublicUpdatedAt", -1];

if (!(_leads isEqualType [])) then { _leads = []; };

private _fmtLead = {
    params ["_entry", ["_prefix", ""]];
    if (!(_entry isEqualType []) || { (count _entry) < 4 }) exitWith {""};

    private _id = _entry select 0;
    private _type = _entry select 1;
    private _disp = _entry select 2;
    private _pos = _entry select 3;
    private _strength = if ((count _entry) > 4) then { _entry select 4 } else { 0.5 };
    private _expiresAt = if ((count _entry) > 6) then { _entry select 6 } else { -1 };

    private _grid = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "????" };

    private _mins = -1;
    if (_expiresAt > 0) then { _mins = floor ((_expiresAt - serverTime) / 60); };

    private _ttl = if (_mins < 0) then {"?"} else { str _mins };

    format ["%1%2 | %3 | %4 | STR %5 | %6m\n", _prefix, _id, toUpper _type, _grid, (round (_strength * 100)), _ttl] + _disp
};

private _txt = "";

private _updTxt = if (_upd < 0) then {"(no server broadcast yet)"} else { format ["(updated %1s ago)", round (serverTime - _upd)] };

_txt = _txt + format ["Lead Pool %1\n", _updTxt];

if (_leads isEqualTo []) then
{
    _txt = _txt + "(empty)\n";
}
else
{
    {
        _txt = _txt + ([_x, "- "] call _fmtLead) + "\n";
    } forEach _leads;
};

// Add "breadcrumbs" so you can tell whether leads are being created/consumed too quickly.
if (_lastC isEqualType [] && { (count _lastC) >= 4 }) then
{
    _txt = _txt + "\nLast Created:\n" + ([_lastC, "* "] call _fmtLead);
};

if (_lastX isEqualType [] && { (count _lastX) >= 4 }) then
{
    _txt = _txt + "\n\nLast Consumed:\n" + ([_lastX, "* "] call _fmtLead);
};

[_txt, "INFO", "HINT"] call ARC_fnc_clientHint;
true
