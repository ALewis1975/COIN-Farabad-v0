/*
    ARC_fnc_uiTaskTimersInitClient

    Client: Starts a lightweight HUD overlay that displays:
      - Time remaining to reach the objective (arrival window or overall deadline)
      - Once on objective, time remaining to end-state (hold timer)

    This is designed to be non-invasive (does not overwrite hint text).
*/

if (!hasInterface) exitWith {false};

// Only start once per client.
if (missionNamespace getVariable ["ARC_uiTaskTimers_running", false]) exitWith {true};
missionNamespace setVariable ["ARC_uiTaskTimers_running", true];

// Only show by default for authorized roles (SL / Officers).
private _enabled = missionNamespace getVariable ["ARC_uiTaskTimers_enabled", true];

// Create HUD layer
private _layer = "ARC_TaskTimerHUD" call BIS_fnc_rscLayer;
_layer cutRsc ["ARC_TaskTimerHUD", "PLAIN", 0, false];
uiNamespace setVariable ["ARC_TaskTimerHUD_layer", _layer];

[] spawn
{
    // Small helper to format seconds as MM:SS
    private _fmt = {
        params [ ["_sec", 0, [0]] ];
        _sec = _sec max 0;
        private _m = floor (_sec / 60);
        private _s = floor (_sec mod 60);
        private _s2 = if (_s < 10) then { format ["0%1", _s] } else { str _s };
        format ["%1:%2", _m, _s2]
    };

    while { hasInterface } do
    {
        uiSleep 1;

        private _enabled = missionNamespace getVariable ["ARC_uiTaskTimers_enabled", true];

        private _disp = uiNamespace getVariable ["ARC_TaskTimerHUD_display", displayNull];
        if (isNull _disp) then { continue; };
        private _ctrl = _disp displayCtrl 86001;
        if (isNull _ctrl) then { continue; };

        // Hide if disabled.
        if (!_enabled) then
        {
            _ctrl ctrlShow false;
            continue;
        };

        private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
        private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
        private _useIncident = (_taskId isNotEqualTo "") && { _accepted };

        // Non-incident tasks: show the ATH for any focused task set via ARC_fnc_clientSetCurrentTask.
        if (!_useIncident) then
        {
            private _focusId = missionNamespace getVariable ["ARC_uiFocusTaskId", ""];
            if (!(_focusId isEqualType "")) then { _focusId = ""; };
            _focusId = trim _focusId;
            if (_focusId isEqualTo "") then
            {
                _ctrl ctrlShow false;
                continue;
            };

            private _fTitle = missionNamespace getVariable ["ARC_uiFocusTaskTitle", ""]; if (!(_fTitle isEqualType "")) then { _fTitle = ""; };
            private _fKind  = missionNamespace getVariable ["ARC_uiFocusTaskKind", "TASK"]; if (!(_fKind isEqualType "")) then { _fKind = "TASK"; };
            private _fPos   = missionNamespace getVariable ["ARC_uiFocusTaskPos", []]; if (!(_fPos isEqualType [])) then { _fPos = []; };

            private _grid = if (_fPos isEqualType [] && { (count _fPos) >= 2 }) then { mapGridPosition _fPos } else { "" };
            private _dist = if (_fPos isEqualType [] && { (count _fPos) >= 2 }) then { round (player distance2D _fPos) } else { -1 };

            private _uiScale = missionNamespace getVariable ["ARC_taskHudScale", 0.85];
            if (!(_uiScale isEqualType 0)) then { _uiScale = 0.85; };
            _uiScale = (_uiScale max 0.6) min 1.2;

            private _sHeader = 1.05 * _uiScale;
            private _sGrid = 0.95 * _uiScale;

            private _txt = format ["<t size='%1' font='PuristaMedium' color='#FFD700'>ASSIGNED TASK</t>", _sHeader];

            if (_fTitle isNotEqualTo "") then
            {
                _txt = _txt + "<br/>" + format ["<t size='%1' font='PuristaMedium'>%2</t>", _uiScale, _fTitle];
            };

            _txt = _txt + "<br/>" + format ["<t size='%1' font='PuristaLight'>%2</t>", _uiScale, _fKind];

            if (_grid isNotEqualTo "") then
            {
                private _line = if (_dist >= 0) then { format ["GRID %1 | %2m", _grid, _dist] } else { format ["GRID %1", _grid] };
                _txt = _txt + "<br/>" + format ["<t size='%1' font='PuristaLight'>%2</t>", _sGrid, _line];
            };

            _ctrl ctrlSetStructuredText (parseText _txt);
            _ctrl ctrlShow true;
            continue;
        };

        // Pull SITREP gating state
        private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
        private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];

        // Pull mirrored exec state
        private _kind = missionNamespace getVariable ["ARC_activeExecKind", "NONE"];
        private _pos = missionNamespace getVariable ["ARC_activeExecPos", []];
        private _deadlineAt = missionNamespace getVariable ["ARC_activeExecDeadlineAt", -1];
        private _arrivalReq = missionNamespace getVariable ["ARC_activeExecArrivalReq", 0];
        private _startedAt = missionNamespace getVariable ["ARC_activeExecStartedAt", -1];
        private _holdReq = missionNamespace getVariable ["ARC_activeExecHoldReq", 0];
        private _holdAccum = missionNamespace getVariable ["ARC_activeExecHoldAccum", 0];
        private _arrived = missionNamespace getVariable ["ARC_activeExecArrived", false];
        private _activated = missionNamespace getVariable ["ARC_activeExecActivated", false];
        private _objPos = missionNamespace getVariable ["ARC_activeObjectivePos", []];

        private _now = serverTime;

        // Derive phase + countdown
        private _phase = "";
        private _tLeft = -1;
        private _showTimer = true;

        // Once the objective timer/conditions complete, hold at SITREP state until players submit.
        if (_closeReady) then
        {
            _phase = if (_sitrepSent) then { "SITREP Sent" } else { "SITREP Pending" };
            _tLeft = 0;
            _showTimer = false;
        }
        else
        {
            if (_kind isEqualTo "ARRIVE_HOLD" && { !_arrived } && { _arrivalReq isEqualType 0 } && { _arrivalReq > 0 } && { _startedAt isEqualType 0 } && { _startedAt > 0 }) then
            {
                _phase = "Transit";
                _tLeft = (_arrivalReq - (_now - _startedAt));
            }
            else
            {
                if (!_activated) then
                {
                    _phase = "Transit";
                    if (_deadlineAt isEqualType 0 && { _deadlineAt > 0 }) then { _tLeft = (_deadlineAt - _now); };
                }
                else
                {
                    if (_holdReq isEqualType 0 && { _holdReq > 0 }) then
                    {
                        _phase = "On-Objective";
                        _tLeft = (_holdReq - _holdAccum);
                    }
                    else
                    {
                        _phase = "Execute";
                        if (_deadlineAt isEqualType 0 && { _deadlineAt > 0 }) then { _tLeft = (_deadlineAt - _now); };
                    };
                };
            };
        };

        // Safety: if we can't compute a timer, hide (unless we're in SITREP state).
        if (_showTimer && { !(_tLeft isEqualType 0) }) then { _ctrl ctrlShow false; continue; };

        private _grid = if (_pos isEqualType [] && { (count _pos) >= 2 }) then { mapGridPosition _pos } else { "" };
        // For INTERACT tasks the objective may be in a different building/location than the incident
        // center marker.  Show the player their distance to the objective, not to the incident center.
        private _distPos = if (_kind isEqualTo "INTERACT" && { _objPos isEqualType [] && { (count _objPos) >= 2 } }) then { _objPos } else { _pos };
        private _dist = if (_distPos isEqualType [] && { (count _distPos) >= 2 }) then { round (player distance2D _distPos) } else { -1 };

        private _line2 = if (_showTimer) then { format ["%1 | %2", _phase, ([_tLeft] call _fmt)] } else { _phase };
        private _line3 = "";
        if (_grid != "") then
        {
            if (_dist >= 0) then
            {
                _line3 = format ["GRID %1 | %2m", _grid, _dist];
            }
            else
            {
                _line3 = format ["GRID %1", _grid];
            };
        };

        private _taskName = missionNamespace getVariable ["ARC_activeIncidentDisplayName", ""];

        // UI scale (smaller defaults for testing)
        private _uiScale = missionNamespace getVariable ["ARC_taskHudScale", 0.85];
        if (!(_uiScale isEqualType 0)) then { _uiScale = 0.85; };
        _uiScale = (_uiScale max 0.6) min 1.2;

        private _sHeader = 1.05 * _uiScale;
        private _sAccepted = 0.90 * _uiScale;
        private _sGrid = 0.95 * _uiScale;

        private _accGroup = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""];

        private _txt = format ["<t size='%1' font='PuristaMedium' color='#FFD700'>ASSIGNED TASK</t>", _sHeader];

        if (_taskName != "") then
        {
            _txt = _txt + "<br/>" + format ["<t size='%1' font='PuristaMedium'>%2</t>", _uiScale, _taskName];
        };

        if (_accGroup != "") then
        {
            _txt = _txt + "<br/>" + format ["<t size='%1' font='PuristaLight' color='#CCCCCC'>ACCEPTED: %2</t>", _sAccepted, _accGroup];
        };

        _txt = _txt + "<br/>" + format ["<t size='%1' font='PuristaLight'>%2</t>", _uiScale, _line2];

        if (_line3 != "") then
        {
            _txt = _txt + "<br/>" + format ["<t size='%1' font='PuristaLight'>%2</t>", _sGrid, _line3];
        };

        _ctrl ctrlSetStructuredText (parseText _txt);
        _ctrl ctrlShow true;
    };
};

true
