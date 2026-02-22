/*
    ARC_fnc_iedHandleDetonation

    Server-side: Handle an IED/VBIED detonation signal and drive the command cycle.

    Problem addressed:
      - An IED can detonate without the objective object being "Killed" (ACE/EOD, scripted
        detonation, proxy explosives). When that happens, the mission spine can stall
        because nothing marks the incident ready-to-close.

    Design rules:
      - Server is the single writer.
      - Idempotent: first valid detonation wins.
      - Emit explicit OPS logs so UI never guesses.

    Params:
      0: ARRAY - posATL (best-effort)
      1: STRING - objective kind override (optional)
      2: STRING - cause tag (optional; for logging)

    Returns:
      BOOL - true if handled
*/

if (!isServer) exitWith {false};

params [
    ["_posATL", [], [[]]],
    ["_objKindOverride", "", [""]],
    ["_cause", "", [""]]
];

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {false};

private _typeU = toUpper (["activeIncidentType", ""] call ARC_fnc_stateGet);
if (_typeU isNotEqualTo "IED") exitWith {false};

// Only handle once per incident.
private _already = ["activeIedDetonationHandled", false] call ARC_fnc_stateGet;
if (_already isEqualType true && { _already }) exitWith {false};

// Objective kind (state is authoritative, but allow override if provided)
private _objKind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
if (_objKindOverride isNotEqualTo "") then { _objKind = _objKindOverride; };
_objKind = toUpper _objKind;

if !(_objKind in ["IED_DEVICE", "VBIED_VEHICLE", "SUICIDE_VEST"]) exitWith {false};

// Normalize posATL
private _p = _posATL;
if (!(_p isEqualType []) || { (count _p) < 2 }) then
{
    _p = ["activeObjectivePos", []] call ARC_fnc_stateGet;
    if (!(_p isEqualType []) || { (count _p) < 2 }) then { _p = ["activeExecPos", []] call ARC_fnc_stateGet; };
};
if (!(_p isEqualType []) || { (count _p) < 2 }) then { _p = [0,0,0]; };
_p = +_p; _p resize 3;

// Mark handled now (idempotence guard)
["activeIedDetonationHandled", true] call ARC_fnc_stateSet;
["activeIedDetonationAt", serverTime] call ARC_fnc_stateSet;
["activeIedDetonationPos", _p] call ARC_fnc_stateSet;

// Casualty/damage assessment (minimal but deterministic)
private _assessRad = missionNamespace getVariable ["ARC_iedDetonationAssessRadiusM", 120];
if (!(_assessRad isEqualType 0) || { _assessRad <= 0 }) then { _assessRad = 120; };
_assessRad = (_assessRad max 30) min 500;

private _civKia = 0;
private _civWia = 0;
private _bluKia = 0;
private _bluWia = 0;
private _bldDamaged = 0;

private _snap = ["activeIedCivSnapshotNetIds", []] call ARC_fnc_stateGet;
if (!(_snap isEqualType [])) then { _snap = []; };

if ((count _snap) > 0) then
{
    {
        private _u = objectFromNetId _x;
        if (!isNull _u && { (side (group _u)) isEqualTo civilian }) then
        {
            if (!alive _u) then
            {
                _civKia = _civKia + 1;
            }
            else
            {
                // Best-effort "wounded" indicator (ACE may not map cleanly to `damage`, but it is still useful).
                if ((damage _u) >= 0.20) then { _civWia = _civWia + 1; };
            };
        };
    } forEach _snap;
}
else
{
    // Fallback: scan local area for civilians.
    private _men = nearestObjects [_p, ["Man"], _assessRad];
    {
        if ((side (group _x)) isEqualTo civilian) then
        {
            if (!alive _x) then { _civKia = _civKia + 1; }
            else { if ((damage _x) >= 0.20) then { _civWia = _civWia + 1; }; };
        };
    } forEach _men;
};

// BLUFOR casualties (always scan; snapshot is civilian-only)
private _men2 = nearestObjects [_p, ["Man"], _assessRad];
{
    private _sd = side (group _x);
    if (_sd in [west, independent]) then
    {
        if (!alive _x) then { _bluKia = _bluKia + 1; }
        else { if ((damage _x) >= 0.20) then { _bluWia = _bluWia + 1; }; };
    };
} forEach _men2;

// Simple structural damage indicator
private _bldRad = missionNamespace getVariable ["ARC_iedDetonationBldAssessRadiusM", 60];
if (!(_bldRad isEqualType 0) || { _bldRad <= 0 }) then { _bldRad = 60; };
_bldRad = (_bldRad max 20) min 150;

private _blds = nearestObjects [_p, ["House"], _bldRad];
{
    if ((damage _x) >= 0.10) then { _bldDamaged = _bldDamaged + 1; };
} forEach _blds;


["activeIedCivKia", _civKia] call ARC_fnc_stateSet;

// Publish a minimal, presentation-safe snapshot for client UI (Closeout tab).
// NOTE: Clients must not read ARC_state directly.
missionNamespace setVariable ["ARC_activeIedDetonationHandled", true, true];
missionNamespace setVariable ["ARC_activeIedCivKia", _civKia, true];

// Store a snapshot so downstream systems/UI can read explicit facts (no reconstruction).
private _grid = mapGridPosition _p;
private _zone = [_p] call ARC_fnc_worldGetZoneForPos;
if (!(_zone isEqualType "") || { _zone isEqualTo "" }) then { _zone = "Unzoned"; };

private _causeU = if (_cause isEqualTo "") then {"DETONATION"} else {toUpper _cause};

private _snapPairs = [
    ["ts", serverTime],
    ["grid", _grid],
    ["zone", _zone],
    ["posATL", _p],
    ["objectiveKind", _objKind],
    ["cause", _causeU],
    ["assessRadiusM", _assessRad],
    ["civKia", _civKia],
    ["civWia", _civWia],
    ["bluKia", _bluKia],
    ["bluWia", _bluWia],
    ["bldAssessRadiusM", _bldRad],
    ["bldDamaged", _bldDamaged]
];

["activeIedDetonationSnapshot", _snapPairs] call ARC_fnc_stateSet;

// Phase 2: ensure post-blast evidence exists for SSE / TECHINT.
[_p, "POST_BLAST"] call ARC_fnc_iedEnsureEvidence;

// Publish full detonation snapshot for UI/TOC tools (pairs array; safe for presentation).
missionNamespace setVariable ["ARC_activeIedDetonationSnapshot", _snapPairs, true];

// Queue a post-blast response lead (TOC priority). This does NOT create a parallel incident.
private _leadId = [_p, _objKind, _causeU, _snapPairs] call ARC_fnc_iedQueueDetonationResponse;

private _detail = "";
private _leadNote = "";
if (_leadId isEqualType "" && { _leadId isNotEqualTo "" }) then
{
    _leadNote = format [" Follow-on queued: %1.", _leadId];
};

if (_civKia > 0) then
{
    _detail = format [
        "IED detonation detected at %1. CIV KIA: %2. Closure MUST be FAILED.%3",
        _grid,
        _civKia,
        _leadNote
    ];
}
else
{
    _detail = format [
        "IED detonation detected at %1. No CIV KIA detected in %2m. Recommend closing this incident as FAILED.%3",
        _grid,
        _assessRad,
        _leadNote
    ];
};

// Drive the mission spine: make TOC closure available.
["FAILED", "IED_DETONATION", _detail, _p] call ARC_fnc_incidentMarkReadyToClose;

// Extra audit line (keeps forensics crisp even if close-ready prompt already existed).
[
    "OPS",
    _detail,
    _p,
    [
        ["taskId", _taskId],
        ["event", "IED_DETONATION"],
        ["kind", _objKind],
        ["civKia", _civKia],
        ["civWia", _civWia],
        ["bluKia", _bluKia],
        ["bluWia", _bluWia],
        ["bldDamaged", _bldDamaged],
        ["assessRadiusM", _assessRad],
        ["bldAssessRadiusM", _bldRad],
        ["leadId", _leadId],
        ["cause", _causeU]
    ]
] call ARC_fnc_intelLog;

// Player feedback: toast the tasking group so detonation recognition is obvious.
private _gId = ["lastTaskingGroup", ""] call ARC_fnc_stateGet;
if (_gId isEqualType "" && { _gId isNotEqualTo "" }) then
{
    private _grp = grpNull;
    {
        if (groupId _x isEqualTo _gId) exitWith { _grp = _x; };
    } forEach allGroups;

    if (!isNull _grp) then
    {
        {
            if (isPlayer _x) then
            {
                ["IED Detonation", _detail, 10] remoteExec ["ARC_fnc_clientToast", _x];
            };
        } forEach (units _grp);
    };
};

true
