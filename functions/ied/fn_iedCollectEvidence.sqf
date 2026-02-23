/*
    ARC_fnc_iedCollectEvidence

    Phase 2 (server): Mark evidence collected, log TECHINT, and optionally emit a follow-on lead.

    Params:
        0: STRING - evidence netId
        1: OBJECT - collector (best effort)

    Returns:
        BOOL
*/
if (!isServer) exitWith {false};

params [
    ["_evidenceNid", "", [""]],
    ["_collector", objNull]
];

if (_evidenceNid isEqualTo "") exitWith {false};

// Dedicated MP hardening: validate sender when collector is provided.
if (!isNil "remoteExecutedOwner" && { !isNull _collector }) then
{
    private _reo = remoteExecutedOwner;
    if (_reo > 0) then
    {
        if ((owner _collector) != _reo) exitWith
        {
            diag_log format ["[ARC][SEC] %1 denied: sender-owner mismatch reo=%2 collectorOwner=%3 collector=%4",
                "ARC_fnc_iedCollectEvidence", _reo, owner _collector, name _collector];
            false
        };
    };
};

private _obj = objectFromNetId _evidenceNid;
if (isNull _obj) exitWith {false};

private _already = _obj getVariable ["ARC_iedEvidenceCollected", false];
if (!(_already isEqualType true) && !(_already isEqualType false)) then { _already = false; };
if (_already) exitWith {true};

_obj setVariable ["ARC_iedEvidenceCollected", true, true];
_obj setVariable ["ARC_iedEvidenceCollectedAt", serverTime, true];

private _who = if (!isNull _collector) then { name _collector } else { "UNKNOWN" };
_obj setVariable ["ARC_iedEvidenceCollectedBy", _who, true];

["activeIedEvidenceCollected", true] call ARC_fnc_stateSet;
["activeIedEvidenceCollectedAt", serverTime] call ARC_fnc_stateSet;
["activeIedEvidenceCollectedBy", _who] call ARC_fnc_stateSet;

// UI mirrors (JIP-safe public vars)
missionNamespace setVariable ["ARC_activeIedEvidenceCollected", true, true];
missionNamespace setVariable ["ARC_activeIedEvidenceCollectedAt", serverTime, true];
missionNamespace setVariable ["ARC_activeIedEvidenceCollectedBy", _who, true];

private _pos = getPosATL _obj;
private _grid = mapGridPosition _pos;
private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _zone = [_pos] call ARC_fnc_worldGetZoneForPos;

private _meta = [
    ["event", "IED_EVIDENCE_COLLECTED"],
    ["grid", _grid],
    ["zone", _zone],
    ["taskId", _taskId],
    ["collector", _who]
];

["TECHINT", format ["Evidence collected at %1.", _grid], _pos, _meta] call ARC_fnc_intelLog;

// Stabilization: do NOT create follow-on leads at collection time.
// Rationale: players should not get "free intel" just for finding a device.
// If RTB evidence is approved and evidence is delivered to the disposal site,
// the server may then emit a follow-on lead.
private _chance = missionNamespace getVariable ["ARC_iedEvidenceFollowOnLeadChance", 0.55];
if (!(_chance isEqualType 0)) then { _chance = 0.55; };
_chance = (_chance max 0) min 1;

private _leadId = ["activeIedEvidenceLeadId", ""] call ARC_fnc_stateGet;
if (!(_leadId isEqualType "")) then { _leadId = ""; };

if (_leadId isEqualTo "" && { (random 1) < _chance }) then
{
    private _incType = ["activeIncidentType", ""] call ARC_fnc_stateGet;
    if (!(_incType isEqualType "")) then { _incType = ""; };

    // Record a pending lead request (actual lead creation happens on disposal-site delivery).
    ["activeIedEvidenceLeadPending", true] call ARC_fnc_stateSet;
    ["activeIedEvidenceLeadPendingPos", _pos] call ARC_fnc_stateSet;
};

true
