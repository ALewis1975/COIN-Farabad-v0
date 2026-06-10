/*
    ARC_fnc_medicalCasevacRequest

    Server-only: generate a structured CASEVAC lead in the lead pool so the
    TOC can see the request and approve a LIFELINE dispatch.

    Called from ARC_fnc_medicalOnCasualty whenever a BLUFOR unit is killed or
    incapacitated. A per-district cooldown prevents lead spam when multiple
    casualties occur in rapid succession.

    Params:
      0: OBJECT - killed/incapacitated unit (may be objNull)
      1: SIDE   - side of the unit (must be west)

    Returns:
      STRING leadId ("" if not emitted)
*/

if (!isServer) exitWith {""};

params [
    ["_unit", objNull, [objNull]],
    ["_side", sideEmpty]
];

if !(_side isEqualTo west) exitWith {""};

// S1: client-driven CASEVAC requests must be initiated by the casualty's owning client
// (ACE incap handler runs on the casualty's machine). Server-internal callers
// (medicalOnCasualty direct call) have no remoteExecutedOwner and bypass this gate.
if (!isNil "remoteExecutedOwner" && { remoteExecutedOwner > 0 }) then
{
    private _reo = remoteExecutedOwner;
    if (isNull _unit) exitWith
    {
        diag_log format ["[ARC][SEC] ARC_fnc_medicalCasevacRequest: CASEVAC_DENIED null casualty from owner=%1", _reo];
        ""
    };
    if ((owner _unit) != _reo) exitWith
    {
        diag_log format ["[ARC][SEC] ARC_fnc_medicalCasevacRequest: CASEVAC_DENIED sender-owner mismatch reo=%1 unitOwner=%2 unit=%3",
            _reo, owner _unit, name _unit];
        ""
    };
};

// Per-district cooldown — avoid flooding the lead pool when several BLUFOR
// fall in the same AO in quick succession.
private _cooldownS = missionNamespace getVariable ["ARC_casevacLeadCooldownS", 180];
if (!(_cooldownS isEqualType 0)) then { _cooldownS = 180; };
_cooldownS = (_cooldownS max 30) min 600;

private _lastTs = missionNamespace getVariable ["ARC_casevacLeadLastTs", -1];
if (!(_lastTs isEqualType 0)) then { _lastTs = -1; };
if (_lastTs > 0 && { (serverTime - _lastTs) < _cooldownS }) exitWith
{
    diag_log format ["[ARC][MEDICAL] ARC_fnc_medicalCasevacRequest: CASEVAC lead suppressed — cooldown active (%1s remaining).", _cooldownS - (serverTime - _lastTs)];
    ""
};

// Position validator: array with numeric X/Y components that is not at/near the
// map origin. Deleted units and corpses parked at [0,0,0] by cleanup return an
// origin position that previously produced useless grid=000000 zone="" leads.
private _isUsablePos =
{
    params [["_p", [], [[]]]];
    if ((count _p) < 2) exitWith { false };
    private _px = _p select 0;
    private _py = _p select 1;
    if (!(_px isEqualType 0) || { !(_py isEqualType 0) }) exitWith { false };
    // Reject positions within 100 m of the map origin (no playable area there).
    if ((_px * _px + _py * _py) < 10000) exitWith { false };
    true
};

// Determine position from unit or active incident pos as fallback
private _pos = [];
if (!isNull _unit) then
{
    _pos = getPosATL _unit;
};
if (!([_pos] call _isUsablePos)) then
{
    private _activePos = ["activeIncidentPos", []] call ARC_fnc_stateGet;
    if (_activePos isEqualType [] && { [_activePos] call _isUsablePos }) then { _pos = +_activePos; };
};
if (!([_pos] call _isUsablePos)) exitWith
{
    diag_log format ["[ARC][MEDICAL][WARN] ARC_fnc_medicalCasevacRequest: could not determine a usable position (unit=%1 pos=%2) — CASEVAC lead not created.",
        if (isNull _unit) then { "objNull" } else { name _unit }, _pos];
    ""
};
_pos resize 3;
if (isNil { _pos select 2 } || { !((_pos select 2) isEqualType 0) }) then { _pos set [2, 0]; };

// Who was the casualty?
private _whoName = if (!isNull _unit) then { name _unit } else { "UNKNOWN" };
private _grid    = mapGridPosition _pos;
private _taskId  = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _zone    = [_pos] call ARC_fnc_worldGetZoneForPos;

// Current casualty count for context in display name
private _bCas = ["baseCasualties", 0] call ARC_fnc_stateGet;
if (!(_bCas isEqualType 0)) then { _bCas = 0; };

private _disp = format ["CASEVAC Request — %1 casualty at %2 (%3)", _whoName, _grid, _zone];

private _ttl = missionNamespace getVariable ["ARC_casevacLeadTtlS", 1200];
if (!(_ttl isEqualType 0)) then { _ttl = 1200; };
_ttl = (_ttl max 300) min 3600;

// Strength reflects medical urgency (scaled from baseMed: low baseMed = high urgency)
private _baseMed = ["baseMed", 0.57] call ARC_fnc_stateGet;
if (!(_baseMed isEqualType 0)) then { _baseMed = 0.57; };
_baseMed = (_baseMed max 0) min 1;
private _strength = (1 - _baseMed) * 0.8 + 0.15;
_strength = (_strength max 0.15) min 0.95;

private _leadId = ["QRF", _disp, _pos, _strength, _ttl, _taskId, "CASEVAC", "", "CASEVAC"] call ARC_fnc_leadCreate;
if (!(_leadId isEqualType "")) then { _leadId = ""; };

if (_leadId isEqualTo "") exitWith
{
    diag_log "[ARC][MEDICAL][WARN] ARC_fnc_medicalCasevacRequest: ARC_fnc_leadCreate failed.";
    ""
};

missionNamespace setVariable ["ARC_casevacLeadLastTs", serverTime];
missionNamespace setVariable ["ARC_casevacLeadLastId", _leadId, true];

private _ctabCasevacMarkers = missionNamespace getVariable ["ARC_casevacCtabMarkersEnabled", true];
if (!(_ctabCasevacMarkers isEqualType true) && !(_ctabCasevacMarkers isEqualType false)) then { _ctabCasevacMarkers = true; };
if (_ctabCasevacMarkers) then
{
    private _mkName = "ARC_casevac_latest";
    private _p2 = +_pos;
    _p2 resize 2;
    if !(_mkName in allMapMarkers) then
    {
        createMarker [_mkName, _p2];
    }
    else
    {
        _mkName setMarkerPos _p2;
    };
    _mkName setMarkerType "mil_dot";
    _mkName setMarkerColor "ColorRed";
    _mkName setMarkerText format ["CASEVAC %1 %2", _whoName, _grid];
    _mkName setMarkerAlpha 0.85;
    missionNamespace setVariable ["ARC_casevacLatestMarker", _mkName, true];
};

diag_log format ["[ARC][MEDICAL] ARC_fnc_medicalCasevacRequest: CASEVAC lead=%1 unit=%2 grid=%3 strength=%4", _leadId, _whoName, _grid, round (_strength * 100) / 100];

// Intel log so TOC can see it in the feed
if (!isNil "ARC_fnc_intelLog") then
{
    ["MED",
        format ["CASEVAC: %1 requires medical evacuation at %2.", _whoName, _grid],
        _pos,
        [
            ["event",    "CASEVAC_REQUEST"],
            ["leadId",   _leadId],
            ["unit",     _whoName],
            ["grid",     _grid],
            ["zone",     _zone],
            ["taskId",   _taskId],
            ["bCas",     _bCas]
        ]
    ] call ARC_fnc_intelLog;
};

_leadId
