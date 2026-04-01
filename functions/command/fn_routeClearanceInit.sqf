/*
    ARC_fnc_routeClearanceInit

    Server-side: initialize a Route Clearance task.

    A route clearance task has an EOD team sweep a named MSR segment. On
    success the route's IED placement probability is suppressed for a
    configurable window. If evidence is found during the sweep, a follow-on
    RECON lead is emitted.

    Params:
      0: STRING - taskId
      1: ARRAY  - posATL [x,y,z] (marker centre for the cleared route segment)
      2: STRING - displayName

    State keys:
      routeClear_v0_active             - BOOL
      routeClear_v0_taskId             - STRING
      routeClear_v0_segmentId          - STRING (derived from taskId)
      routeClear_v0_clearUntil         - NUMBER (serverTime when suppression ends)
      routeClear_v0_suppressedSegments - HASHMAP segmentId -> clearUntil

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_taskId", "", [""]],
    ["_pos",    [], [[]]],
    ["_disp",   "", [""]]
];

if (_taskId isEqualTo "") exitWith {false};
if (_pos isEqualTo [] || { (count _pos) < 2 }) exitWith {false};
_pos resize 3;

if (missionNamespace getVariable ["routeClear_v0_active", false]) exitWith
{
    diag_log "[ARC][ROUTECLR] routeClearanceInit: already active — skipping duplicate init.";
    false
};

missionNamespace setVariable ["routeClear_v0_active",   true];
missionNamespace setVariable ["routeClear_v0_taskId",   _taskId];
missionNamespace setVariable ["routeClear_v0_clearUntil", -1];

// Derive a stable segment ID from task marker vicinity
private _segId = format ["SEG_%1_%2", floor (_pos # 0), floor (_pos # 1)];
missionNamespace setVariable ["routeClear_v0_segmentId", _segId];

// Parameters
private _sweepRadiusM  = missionNamespace getVariable ["ARC_routeClearRadiusM",     400];
private _dwellTimeS    = missionNamespace getVariable ["ARC_routeClearDwellS",       240];
private _suppressionS  = missionNamespace getVariable ["ARC_routeClearSuppressionS", 7200]; // 2 h
if (!(_sweepRadiusM  isEqualType 0)) then { _sweepRadiusM  = 400; };
if (!(_dwellTimeS    isEqualType 0)) then { _dwellTimeS    = 240; };
if (!(_suppressionS  isEqualType 0)) then { _suppressionS  = 7200; };
_sweepRadiusM  = (_sweepRadiusM  max 100) min 1500;
_dwellTimeS    = (_dwellTimeS    max 60)  min 1800;
_suppressionS  = (_suppressionS  max 1800) min 86400;

diag_log format ["[ARC][ROUTECLR] routeClearanceInit: taskId=%1 segId=%2 sweep=%3m dwell=%4s suppress=%5s.", _taskId, _segId, _sweepRadiusM, _dwellTimeS, _suppressionS];

// ── Sweep monitor loop ─────────────────────────────────────────────────────
[_taskId, _pos, _sweepRadiusM, _dwellTimeS, _suppressionS, _segId] spawn
{
    params ["_taskId", "_pos", "_sweepR", "_dwellTimeS", "_suppressionS", "_segId"];

    private _dwellAccum = 0;
    private _completed  = false;

    while { !_completed && { missionNamespace getVariable ["routeClear_v0_active", false] } } do
    {
        sleep 5;

        // Abort if task is no longer active
        private _activeTask = ["activeTaskId", ""] call ARC_fnc_stateGet;
        if (!(_activeTask isEqualTo _taskId)) exitWith
        {
            missionNamespace setVariable ["routeClear_v0_active", false];
            diag_log format ["[ARC][ROUTECLR] sweepWatch: task=%1 no longer active — aborted.", _taskId];
        };

        // Count BLUFOR ground units within sweep radius
        private _near = _pos nearEntities [["Man"], _sweepR];
        private _bluforCount = count (_near select { side (group _x) isEqualTo west && { isPlayer _x } });

        if (_bluforCount > 0) then { _dwellAccum = _dwellAccum + 5; };

        // Check for road IEDs in the sweep area (scan for active threat records near _pos)
        private _iedFound = false;
        private _iedRecords = missionNamespace getVariable ["ARC_iedPhase1_deviceRecords", []];
        if (_iedRecords isEqualType []) then
        {
            {
                if (!(_x isEqualType [])) then { continue; };
                private _devPos = _x param [2, []];
                if (!(_devPos isEqualType []) || { (count _devPos) < 2 }) then { continue; };
                if ((_pos distance2D _devPos) < _sweepR) exitWith { _iedFound = true; };
            } forEach _iedRecords;
        };

        if (_dwellAccum >= _dwellTimeS) then
        {
            _completed = true;
            missionNamespace setVariable ["routeClear_v0_active", false];

            // Register suppression
            private _clearUntil = serverTime + _suppressionS;
            missionNamespace setVariable ["routeClear_v0_clearUntil", _clearUntil];

            private _suppressed = missionNamespace getVariable ["routeClear_v0_suppressedSegments", createHashMap];
            if (!(_suppressed isEqualType createHashMap)) then { _suppressed = createHashMap; };
            _suppressed set [_segId, _clearUntil];
            missionNamespace setVariable ["routeClear_v0_suppressedSegments", _suppressed];

            // Mark incident close-ready
            ["activeIncidentCloseReady", true] call ARC_fnc_stateSet;
            missionNamespace setVariable ["ARC_activeIncidentCloseReady", true, true];

            // Emit a RECON lead if IED evidence found in sweep area
            if (_iedFound && { !isNil "ARC_fnc_leadCreate" }) then
            {
                private _lid = ["RECON", format ["Route Clearance — IED evidence at %1", mapGridPosition _pos], _pos, 0.60, 3600, _taskId, "ROUTE_CLEARANCE", "", "component_trace"] call ARC_fnc_leadCreate;
                diag_log format ["[ARC][ROUTECLR] sweepWatch: IED evidence lead=%1 emitted.", _lid];
            };

            // Intel log
            if (!isNil "ARC_fnc_intelLog") then
            {
                ["OPS",
                    format ["Route cleared: %1 suppressed for %2 h.", _segId, _suppressionS / 3600],
                    _pos,
                    [["event","ROUTE_CLEARANCE_SUCCESS"],["taskId",_taskId],["segId",_segId],["clearUntil",_clearUntil],["iedFound",_iedFound]]
                ] call ARC_fnc_intelLog;
            };

            diag_log format ["[ARC][ROUTECLR] sweepWatch: SUCCESS taskId=%1 seg=%2 clearUntil=%3 iedFound=%4.", _taskId, _segId, _clearUntil, _iedFound];
        };
    };
};

true
