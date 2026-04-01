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

// Determine position from unit or active incident pos as fallback
private _pos = [];
if (!isNull _unit) then
{
    _pos = getPosATL _unit;
};
if (_pos isEqualTo [] || { (count _pos) < 2 }) then
{
    private _activePos = ["activeIncidentPos", []] call ARC_fnc_stateGet;
    if (_activePos isEqualType [] && { (count _activePos) >= 2 }) then { _pos = _activePos; };
};
if (_pos isEqualTo [] || { (count _pos) < 2 }) exitWith
{
    diag_log "[ARC][MEDICAL][WARN] ARC_fnc_medicalCasevacRequest: could not determine position — CASEVAC lead not created.";
    ""
};
_pos resize 3;

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
