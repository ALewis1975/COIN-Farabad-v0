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

    _entry params ["_id", "_type", "_disp", "_pos", ["_strength", 0.5], ["_createdAt", -1], ["_expiresAt", -1]];

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

hint _txt;
true
