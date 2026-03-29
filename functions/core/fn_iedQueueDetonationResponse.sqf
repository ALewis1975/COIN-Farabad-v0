/*
    ARC_fnc_iedQueueDetonationResponse

    Server-only helper.

    Purpose:
      When an IED/VBIED objective detonates, queue a post-blast response as a HIGH PRIORITY lead.

      This keeps the command-cycle intact:
        Execute -> Consolidate -> SITREP -> TOC Follow-on (PROCEED/LEAD) -> Next task.

      The lead is tagged with a TOC_ prefix so it is consumed before routine leads.

    Design rules:
      - Server is single writer
      - Consumers never guess (explicit lead creation + explicit logs)
      - Idempotent per incident (guarded by detonation handler + stored leadId)

    Params:
      0: ARRAY  - posATL of detonation (required)
      1: STRING - objective kind (optional) e.g. "IED_DEVICE" | "VBIED_VEHICLE"
      2: STRING - cause/reason (optional) e.g. "OBJECTIVE_KILLED" | "MISSION_EXPLOSION"
      3: ARRAY  - assessment pairs (optional) e.g. [["civKia",1],["bluKia",0],...]

    Returns:
      STRING - leadId ("" on failure / not queued)
*/

if (!isServer) exitWith {""};

params [
    ["_posATL", [], [[]]],
    ["_objKind", "", [""]],
    ["_cause", "", [""]],
    ["_assessment", [], [[]]]
];

if (!(_posATL isEqualType []) || { (count _posATL) < 2 }) exitWith {""};

_posATL = +_posATL;
_posATL resize 3;

if (!((_posATL # 0) isEqualType 0) || { !((_posATL # 1) isEqualType 0) }) exitWith {""};
if (!((_posATL # 2) isEqualType 0)) then { _posATL set [2, 0]; };

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {""};

private _incType = ["activeIncidentType", ""] call ARC_fnc_stateGet;
if (!(_incType isEqualType "")) then { _incType = ""; };
if (!((toUpper _incType) isEqualTo "IED")) exitWith {""};

private _objKindU = toUpper (trim _objKind);
if (!(_objKindU in ["IED_DEVICE", "VBIED_VEHICLE", "SUICIDE_VEST", "UNKNOWN"])) then { _objKindU = "UNKNOWN"; };

// Idempotence: only queue one follow-on lead per active incident.
private _existingLeadId = ["activeIedDetonationResponseLeadId", ""] call ARC_fnc_stateGet;
if (!(_existingLeadId isEqualType "")) then { _existingLeadId = ""; };
if (!(_existingLeadId isEqualTo "")) exitWith {_existingLeadId};

// Helper: pull values from an array of [k,v] pairs.
private _getP = {
    params ["_pairs", "_k", "_d"];
    if (!(_pairs isEqualType [])) exitWith { _d };
    private _out = _d;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { (_x # 0) isEqualTo _k }) exitWith
        {
            _out = _x # 1;
        };
    } forEach _pairs;
    _out
};

// If no assessment was passed, try to use the server snapshot.
if (!(_assessment isEqualType []) || { (count _assessment) isEqualTo 0 }) then
{
    private _snap = ["activeIedDetonationSnapshot", []] call ARC_fnc_stateGet;
    if (_snap isEqualType [] && { (count _snap) > 0 }) then
    {
        _assessment = _snap;
    };
};

private _civKia = [_assessment, "civKia", -1] call _getP;
if (!(_civKia isEqualType 0)) then { _civKia = -1; };

private _zone = [_posATL] call ARC_fnc_worldGetZoneForPos;
if (!(_zone isEqualType "")) then { _zone = ""; };
if (_zone isEqualTo "") then { _zone = "Unzoned"; };

// Recommend a response task type (keeps us inside the existing incident executor).
// - Airbase detonations should bias to DEFEND posture.
// - Everything else uses QRF (arrive + hold).
private _leadType = "QRF";
if (_zone isEqualTo "Airbase") then { _leadType = "DEFEND"; };

private _grid = mapGridPosition _posATL;

private _kindLabel = "Explosion";
if (_objKindU isEqualTo "IED_DEVICE") then { _kindLabel = "IED Explosion"; };
if (_objKindU isEqualTo "VBIED_VEHICLE") then { _kindLabel = "VBIED Explosion"; };
if (_objKindU isEqualTo "SUICIDE_VEST") then { _kindLabel = "Suicide Explosion"; };

private _disp = format ["Emergency Response: %1 @ %2", _kindLabel, _grid];
if (_civKia isEqualType 0 && { _civKia > 0 }) then
{
    _disp = format ["%1 (CIV KIA %2)", _disp, _civKia];
};

// Tag with TOC_ so leadConsumeNext always treats it as priority.
private _tag = "TOC_DETONATION_RESPONSE";

// Strong/urgent lead: should be preferred over routine intel leads.
private _strength = 0.95;
private _ttl = 60 * 60; // 60 minutes

private _threadId = ["activeThreadId", ""] call ARC_fnc_stateGet;
if (!(_threadId isEqualType "")) then { _threadId = ""; };

// Create lead (server-writer) and store its id for idempotence.
private _leadId = [_leadType, _disp, _posATL, _strength, _ttl, _taskId, _incType, _threadId, _tag] call ARC_fnc_leadCreate;
if (!(_leadId isEqualType "")) then { _leadId = ""; };
if (_leadId isEqualTo "") exitWith {""};

["activeIedDetonationResponseLeadId", _leadId] call ARC_fnc_stateSet;

// Also publish a generic "follow-on lead" pointer for TOC/UI closeout logic.
["activeIncidentFollowOnLeadId", _leadId] call ARC_fnc_stateSet;
["activeIncidentFollowOnLeadType", _leadType] call ARC_fnc_stateSet;
["activeIncidentFollowOnLeadName", _disp] call ARC_fnc_stateSet;
["activeIncidentFollowOnLeadPos", _posATL] call ARC_fnc_stateSet;
["activeIncidentFollowOnLeadZone", _zone] call ARC_fnc_stateSet;
["activeIncidentFollowOnLeadGrid", _grid] call ARC_fnc_stateSet;

missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadId", _leadId, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadType", _leadType, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadName", _disp, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadPos", _posATL, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadZone", _zone, true];
missionNamespace setVariable ["ARC_activeIncidentFollowOnLeadGrid", _grid, true];

// Explicit OPS log for traceability (TOC should never have to guess why a lead appeared).
[
    "OPS",
    format ["Detonation follow-on queued: %1 (%2) lead %3 at %4 (%5).", _kindLabel, _leadType, _leadId, _grid, _zone],
    _posATL,
    [
        ["event", "IED_DETONATION_FOLLOWON_LEAD"],
        ["taskId", _taskId],
        ["leadId", _leadId],
        ["leadType", _leadType],
        ["displayName", _disp],
        ["zone", _zone],
        ["grid", _grid],
        ["objectiveKind", _objKindU],
        ["cause", toUpper _cause],
        ["strength", _strength],
        ["ttlSec", _ttl]
    ]
] call ARC_fnc_intelLog;

_leadId
