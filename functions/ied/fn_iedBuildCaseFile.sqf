/*
    ARC_fnc_iedBuildCaseFile

    IED subsystem: build a case file from collected evidence; emit facilitator lead
    when confidence >= 0.4.

    Params:
      0: STRING deviceId (evidence object netId or device id)
      1: STRING collectorUid (player UID, may be "UNKNOWN")

    Returns:
      STRING caseFileId ("" on failure)
*/

if (!isServer) exitWith {""};

params [
    ["_deviceId", "", [""]],
    ["_collectorUid", "UNKNOWN", [""]]
];

if (_deviceId isEqualTo "") exitWith {""};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// Load evidence state for the device
private _collected   = ["activeIedEvidenceCollected", false] call ARC_fnc_stateGet;
if (!(_collected isEqualType true) && !(_collected isEqualType false)) then { _collected = false; };
if (!_collected) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_iedBuildCaseFile: no evidence collected for device=%1", _deviceId];
    ""
};

private _taskId    = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _incType   = ["activeIncidentType", ""] call ARC_fnc_stateGet;
private _pos       = ["activeExecPos", []] call ARC_fnc_stateGet;
if (!(_pos isEqualType []) || { (count _pos) < 2 }) then { _pos = [0,0,0]; };
_pos resize 3;

// Build evidence items list
private _items = [];
if (_collected) then { _items pushBack "device_remnants"; };
private _pendingPos = ["activeIedEvidenceLeadPendingPos", []] call ARC_fnc_stateGet;
if (_pendingPos isEqualType [] && { (count _pendingPos) >= 2 }) then { _items pushBack "site_sample"; };
private _collectedBy = ["activeIedEvidenceCollectedBy", "UNKNOWN"] call ARC_fnc_stateGet;
if (!(_collectedBy isEqualTo "UNKNOWN")) then { _items pushBack "collector_witness"; };

// Confidence: 0.2 per evidence item
private _confidence = (count _items) * 0.2;
_confidence = (_confidence max 0) min 1.0;

// Generate case file ID
private _now = serverTime;
private _caseFileId = format ["CF_%1_%2", _deviceId, floor _now];

// Load existing case files
private _caseFiles = ["ied_v0_case_files", createHashMap] call ARC_fnc_stateGet;
if (!(_caseFiles isEqualType createHashMap)) then { _caseFiles = createHashMap; };

// Build case file entry
private _cfEntry = createHashMap;
_cfEntry set ["caseFileId",    _caseFileId];
_cfEntry set ["deviceId",      _deviceId];
_cfEntry set ["taskId",        _taskId];
_cfEntry set ["evidence_items", _items];
_cfEntry set ["confidence",    _confidence];
_cfEntry set ["created_ts",    _now];
_cfEntry set ["collectorUid",  _collectorUid];

_caseFiles set [_caseFileId, _cfEntry];
["ied_v0_case_files", _caseFiles] call ARC_fnc_stateSet;

// Update active state
["activeIedCaseFileId", _caseFileId] call ARC_fnc_stateSet;

// Emit facilitator lead when confidence threshold met
private _leadEmitted = false;
if (_confidence >= 0.4) then
{
    private _fId = [
        "IED",
        format ["Facilitator Node — SSE Case %1", _caseFileId],
        _pos,
        _confidence,
        5400,
        _taskId,
        _incType,
        "",
        "ied_sse"
    ] call ARC_fnc_leadCreate;

    if (!(_fId isEqualTo "")) then
    {
        _leadEmitted = true;
        _cfEntry set ["leadId", _fId];
        _caseFiles set [_caseFileId, _cfEntry];
        ["ied_v0_case_files", _caseFiles] call ARC_fnc_stateSet;
        diag_log format ["[ARC][INFO] ARC_fnc_iedBuildCaseFile: facilitator lead emitted lead=%1 confidence=%2 caseFile=%3", _fId, _confidence, _caseFileId];
    };
};

diag_log format ["[ARC][INFO] ARC_fnc_iedBuildCaseFile: caseFile=%1 confidence=%2 leadEmitted=%3 device=%4", _caseFileId, _confidence, _leadEmitted, _deviceId];

_caseFileId
