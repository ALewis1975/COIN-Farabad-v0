/*
    Initialize TOC actions on client.

    Adds addAction entries to any Eden objects with variable names starting with ARC_toc_.

    This version is screen-aware:
      - ARC_toc_ops_*   : incident/task controls
      - ARC_toc_intel_* : intel feed + reporting tools
      - ARC_toc_screen_*: SITREP display / briefing access
      - ARC_toc_air_*   : placeholder for future air tasking
*/

if (!hasInterface) exitWith {false};

// Fail-safe: ensure role helper functions exist even if CfgFunctions.hpp was not updated.
// This prevents addAction condition spam and keeps role gating stable.
if (isNil "ARC_fnc_rolesIsAuthorized") then { ARC_fnc_rolesIsAuthorized = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsAuthorized.sqf"; };
if (isNil "ARC_fnc_rolesGetTag") then { ARC_fnc_rolesGetTag = compile preprocessFileLineNumbers "functions\\core\\fn_rolesGetTag.sqf"; };
if (isNil "ARC_fnc_rolesFormatUnit") then { ARC_fnc_rolesFormatUnit = compile preprocessFileLineNumbers "functions\\core\\fn_rolesFormatUnit.sqf"; };
if (isNil "ARC_fnc_rolesHasGroupIdToken") then { ARC_fnc_rolesHasGroupIdToken = compile preprocessFileLineNumbers "functions\\core\\fn_rolesHasGroupIdToken.sqf"; };
if (isNil "ARC_fnc_rolesIsTocS2") then { ARC_fnc_rolesIsTocS2 = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsTocS2.sqf"; };
if (isNil "ARC_fnc_rolesIsTocS3") then { ARC_fnc_rolesIsTocS3 = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsTocS3.sqf"; };
if (isNil "ARC_fnc_rolesIsTocCommand") then { ARC_fnc_rolesIsTocCommand = compile preprocessFileLineNumbers "functions\\core\\fn_rolesIsTocCommand.sqf"; };
if (isNil "ARC_fnc_rolesCanApproveQueue") then { ARC_fnc_rolesCanApproveQueue = compile preprocessFileLineNumbers "functions\\core\\fn_rolesCanApproveQueue.sqf"; };

private _tocVars = allVariables missionNamespace select { (toLower _x) find "arc_toc_" isEqualTo 0 };

// Optional mobile TOC (Ops) vehicle for testing / gameplay
private _mobileOpsVar = "remote_ops_vehicle";
if (!(_mobileOpsVar in _tocVars)) then
{
    private _mob = missionNamespace getVariable [_mobileOpsVar, objNull];

    // Fallback 1: netId published by the server (handles locality swaps / weird init order)
    if (isNull _mob) then
    {
        private _nid = missionNamespace getVariable ["ARC_mobileOpsVehicleNetId", ""];
        if (_nid isEqualType "" && { _nid != "" }) then
        {
            _mob = objectFromNetId _nid;
            if (!isNull _mob) then { missionNamespace setVariable [_mobileOpsVar, _mob]; };
        };
    };

    // Fallback 2: scan by editor vehicleVarName
    if (isNull _mob) then
    {
        {
            if ((toLower (vehicleVarName _x)) isEqualTo _mobileOpsVar) exitWith { _mob = _x; };
        } forEach vehicles;

        if (!isNull _mob) then { missionNamespace setVariable [_mobileOpsVar, _mob]; };
    };

    if (!isNull _mob) then { _tocVars pushBack _mobileOpsVar; };
};

{
    private _varName = toLower _x;

    // Treat all ARC_toc_ops_* terminals as OPS terminals (shared action set)
    if (_varName find "arc_toc_ops_" == 0) then { _varName = "arc_toc_ops_1"; };

    private _obj = missionNamespace getVariable [_x, objNull];
    if (isNull _obj) then { continue; };

    // -----------------------------------------------------------------------
    // Bind (or re-bind) addActions for this TOC object on this client.
    //
    // Why:
    // - Mobile ops vehicles can swap locality (player driver vs AI driver), and some
    //   scripts/mods can rebuild vehicle actions (which can wipe ours).
    // - Some scripts/mods can clear addActions; locality timing can also race.
    //
    // For most TOC objects we track action IDs. For the mobile ops vehicle we
    // identify our actions by title prefix to avoid false-positives when action
    // IDs get reused by another script after a wipe/rebuild.
    // -----------------------------------------------------------------------
    private _isMobileOpsVehicle = (_varName isEqualTo "remote_ops_vehicle");

    private _stored = _obj getVariable ["ARC_toc_actionIds", []];
    if (!(_stored isEqualType [])) then { _stored = []; };

    private _needBind = true;

    if (_isMobileOpsVehicle) then
    {
        // Detect existing mobile ops actions by title prefix (robust vs action-ID reuse)
        private _curIds = actionIDs _obj;
        private _mine = [];

        {
            private _p = _obj actionParams _x;
            if (_p isEqualType [] && {(count _p) > 0}) then
            {
                private _t = _p select 0;
                if (_t isEqualType "") then
                {
                    private _tU = toUpper _t;
                    if ((_tU find "[MOBILE OPS]") == 0 || (_tU find "[MOBILE QUEUE]") == 0 || (_tU find "[MOBILE ORDER]") == 0) then
                    {
                        _mine pushBack _x;
                    };
                };
            };
        } forEach _curIds;

        private _expected = missionNamespace getVariable ["ARC_mobileOpsExpectedActionCount", 17];
        if (!(_expected isEqualType 0)) then { _expected = 17; };

        // Rebind if any of our mobile ops actions are missing (or were wiped/rebuilt)
        _needBind = ((count _mine) < _expected);

        if (!_needBind) then { continue; };

        // Remove only our own mobile ops actions (by title prefix)
        { _obj removeAction _x; } forEach _mine;
    }
    else
    {
        if ((count _stored) > 0) then
        {
            _needBind = false;
            private _cur = actionIDs _obj;
            {
                if !(_x in _cur) exitWith { _needBind = true; };
            } forEach _stored;
        };

        if (!_needBind) then { continue; };

        // Remove previously-bound actions (only those we created on this client)
        { _obj removeAction _x; } forEach _stored;
    };

    // Snapshot action IDs before we add ours so we can store only our additions.
    private _before = actionIDs _obj;


    switch (_varName) do
    {
        case "arc_toc_ops_1":
        {
            _obj addAction ["[TOC OPS] Open Ops Screen", { [] call ARC_fnc_uiOpenOpsScreen; }];

            // Assignment / acceptance workflow
            _obj addAction [
                "[TOC OPS] Generate Next Incident",
                { [player] remoteExec ["ARC_fnc_tocRequestNextIncident", 2]; },
                [],
                1.6,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) isEqualTo '' && !(missionNamespace getVariable ['ARC_resetInProgress', false]) }"
            ];

            _obj addAction [
                "[TOC OPS] Accept Active Incident",
                { [player] remoteExec ["ARC_fnc_tocRequestAcceptIncident", 2]; },
                [],
                1.5,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' && !(missionNamespace getVariable ['ARC_activeIncidentAccepted', false]) }"
            ];

            _obj addAction [
                "[TOC OPS] Rebuild Active Incident Task",
                { [] remoteExec ["ARC_fnc_tocRequestRebuildActive", 2]; },
                [],
                1.4,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' }"
            ];

            // Closure options (kept TOC-gated)
            _obj addAction [
                "[TOC OPS] Close Active Incident (SUCCESS)",
                { ["SUCCEEDED"] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2]; },
                [],
                1.2,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' && (missionNamespace getVariable ['ARC_activeIncidentCloseReady', false]) }"
            ];

            _obj addAction [
                "[TOC OPS] Close Active Incident (FAIL)",
                { ["FAILED"] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2]; },
                [],
                1.2,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' && (missionNamespace getVariable ['ARC_activeIncidentCloseReady', false]) }"
            ];

            _obj addAction [
                "[TOC OPS] FORCE Close Active Incident (SUCCESS)",
                { ["SUCCEEDED", true, player] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2]; },
                [],
                1.0,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' }"
            ];

            _obj addAction [
                "[TOC OPS] FORCE Close Active Incident (FAIL)",
                { ["FAILED", true, player] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2]; },
                [],
                1.0,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' }"
            ];

            _obj addAction ["[TOC OPS] Save World State", {
                [] remoteExec ["ARC_fnc_tocRequestSave", 2];
            }, [], 0.85, true, true, "", "([player] call ARC_fnc_rolesCanApproveQueue)"]; 

            _obj addAction [
                "[TOC OPS] Reset Persistence + Tasks",
                { [] remoteExec ["ARC_fnc_tocRequestResetAll", 2]; },
                [],
                0.8,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) isEqualTo '' }"
            ];

            _obj addAction ["[TOC OPS] Show Current Incident", {
                private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
                if (_taskId isEqualTo "") exitWith { ["No active incident.", "INFO", "TOAST"] call ARC_fnc_clientHint; };

                private _disp  = missionNamespace getVariable ["ARC_activeIncidentDisplayName", ""]; 
                private _type  = missionNamespace getVariable ["ARC_activeIncidentType", ""]; 
                private _zone  = missionNamespace getVariable ["ARC_activeIncidentZone", ""]; 
                private _mkr   = missionNamespace getVariable ["ARC_activeIncidentMarker", ""]; 
                private _pos   = missionNamespace getVariable ["ARC_activeIncidentPos", []];

                private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
                private _accGroup = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""]; 
                private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];
                private _sitrepFromG = missionNamespace getVariable ["ARC_activeIncidentSitrepFromGroup", ""]; 
                private _sitrepSum = missionNamespace getVariable ["ARC_activeIncidentSitrepSummary", ""]; 
                private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
                private _suggRes = missionNamespace getVariable ["ARC_activeIncidentSuggestedResult", ""]; 
                private _closeReason = missionNamespace getVariable ["ARC_activeIncidentCloseReason", ""]; 

                private _status = "ASSIGNED";
                if (!_accepted) then { _status = "ASSIGNED (NOT ACCEPTED)"; };
                if (_accepted) then { _status = "ACCEPTED"; };
                if (_sitrepSent) then { _status = "SITREP SENT"; };
                if (_closeReady) then
                {
                    _status = if (_suggRes isEqualTo "") then { "READY TO CLOSE" } else { format ["READY TO CLOSE (%1)", _suggRes] };
                };

                private _grid = "";
                if (_pos isEqualType [] && { (count _pos) >= 2 }) then { _grid = mapGridPosition _pos; };

                // Exec snapshot (best-effort; depends on exec broadcast)
                private _kind = missionNamespace getVariable ["ARC_activeExecKind", ""]; 
                private _rad  = missionNamespace getVariable ["ARC_activeExecRadius", -1];
                private _holdReq = missionNamespace getVariable ["ARC_activeExecHoldReq", -1];
                private _holdAcc = missionNamespace getVariable ["ARC_activeExecHoldAccum", -1];
                private _deadlineAt = missionNamespace getVariable ["ARC_activeExecDeadlineAt", -1];

                private _deadlineTxt = "";
                if (_deadlineAt isEqualType 0 && { _deadlineAt > 0 }) then
                {
                    private _tLeft = round (_deadlineAt - serverTime);
                    _deadlineTxt = format ["%1s", (_tLeft max 0)];
                };

                private _txt = "";
                _txt = _txt + format ["Status: %1\n", _status];
                _txt = _txt + format ["Task: %1\n", _taskId];
                if (_disp != "") then { _txt = _txt + format ["Name: %1\n", _disp]; };
                if (_type != "") then { _txt = _txt + format ["Type: %1\n", _type]; };
                if (_zone != "") then { _txt = _txt + format ["Zone: %1\n", _zone]; };
                if (_grid != "") then { _txt = _txt + format ["Grid: %1\n", _grid]; };
                if (_mkr != "") then { _txt = _txt + format ["Marker: %1\n", _mkr]; };

                if (_accGroup != "") then { _txt = _txt + format ["Accepted: %1\n", _accGroup]; };

                if (_sitrepSent) then
                {
                    private _sLine = "";
                    if (_sitrepFromG != "") then { _sLine = _sLine + format ["From %1", _sitrepFromG]; };
                    if (_sitrepSum != "") then
                    {
                        if (_sLine != "") then { _sLine = _sLine + ": "; };
                        _sLine = _sLine + _sitrepSum;
                    };
                    if (_sLine != "") then { _txt = _txt + format ["SITREP: %1\n", _sLine]; };
                };

                if (_closeReady) then
                {
                    if (_closeReason != "") then { _txt = _txt + format ["Close: %1\n", _closeReason]; };
                };

                if (_kind != "") then
                {
                    private _e = format ["Exec: %1", _kind];
                    if (_rad isEqualType 0 && { _rad > 0 }) then { _e = _e + format [" | AO %1m", round _rad]; };
                    if (_holdReq isEqualType 0 && { _holdReq > 0 } && { _holdAcc isEqualType 0 }) then { _e = _e + format [" | Hold %1/%2s", round _holdAcc, round _holdReq]; };
                    if (_deadlineTxt != "") then { _e = _e + format [" | Deadline in %1", _deadlineTxt]; };
                    _txt = _txt + _e;
                };

                [_txt, "INFO", "HINT"] call ARC_fnc_clientHint;
            }];
            // TOC tasking queue (S3 approval workflow)
            // Moved from hint/id-entry to a dialog-driven workflow to reduce addAction clutter.
            _obj addAction [
                "[TOC QUEUE] Open Queue Manager (View/Approve)",
                { [] call ARC_fnc_intelUiOpenQueueManager; },
                [],
                0.95,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesIsAuthorized"
            ];

            // Follow-on orders (unit must accept)
            _obj addAction [
                "[TOC ORDER] Issue RTB (REFIT)",
                { ["RTB", "REFIT"] spawn ARC_fnc_intelClientTocIssueOrderPrompt; },
                [],
                0.90,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesCanApproveQueue"
            ];
            _obj addAction [
                "[TOC ORDER] Issue RTB (INTEL)",
                { ["RTB", "INTEL"] spawn ARC_fnc_intelClientTocIssueOrderPrompt; },
                [],
                0.89,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesCanApproveQueue"
            ];
            _obj addAction [
                "[TOC ORDER] Issue RTB (EPW)",
                { ["RTB", "EPW"] spawn ARC_fnc_intelClientTocIssueOrderPrompt; },
                [],
                0.88,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesCanApproveQueue"
            ];
            _obj addAction [
                "[TOC ORDER] Issue HOLD",
                { ["HOLD", ""] spawn ARC_fnc_intelClientTocIssueOrderPrompt; },
                [],
                0.87,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesCanApproveQueue"
            ];
            _obj addAction [
                "[TOC ORDER] Issue PROCEED (Assign Lead)",
                { ["PROCEED", ""] spawn ARC_fnc_intelClientTocIssueOrderPrompt; },
                [],
                0.86,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (count (missionNamespace getVariable ['ARC_leadPoolPublic', []])) > 0 }"
            ];

        };

        case "remote_ops_vehicle":
        {
            // Mobile Ops / Mobile Orders addActions must be removable and idempotent.
            // We track any action IDs we add on this object so toggles can hide them later.
            private _actKey = "ARC_mobOps_actIds";
            private _oldIds = _obj getVariable [_actKey, []];
            if (!(_oldIds isEqualType [])) then { _oldIds = []; };
            {
                if (_x isEqualType 0 && { _x >= 0 } && { _x in (actionIDs _obj) }) then { _obj removeAction _x; };
            } forEach _oldIds;
            _obj setVariable [_actKey, [], false];

            // Feature toggle: when disabled, do not add any Mobile Ops/Mobile Orders actions.
            if (!(missionNamespace getVariable ["ARC_rtbInWorldActionsEnabled", false])) exitWith { true };

            private _beforeIds = actionIDs _obj;

_obj addAction ["[MOBILE OPS] Open Ops Screen", { [] call ARC_fnc_uiOpenOpsScreen; }];

            // Assignment / acceptance workflow
            _obj addAction [
                "[MOBILE OPS] Generate Next Incident",
                { [player] remoteExec ["ARC_fnc_tocRequestNextIncident", 2]; },
                [],
                1.6,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) isEqualTo '' && !(missionNamespace getVariable ['ARC_resetInProgress', false]) }"
            ];

            _obj addAction [
                "[MOBILE OPS] Accept Active Incident",
                { [player] remoteExec ["ARC_fnc_tocRequestAcceptIncident", 2]; },
                [],
                1.5,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' && !(missionNamespace getVariable ['ARC_activeIncidentAccepted', false]) }"
            ];

            _obj addAction [
                "[MOBILE OPS] Rebuild Active Incident Task",
                { [] remoteExec ["ARC_fnc_tocRequestRebuildActive", 2]; },
                [],
                1.4,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' }"
            ];

            _obj addAction [
                "[MOBILE OPS] Close Active Incident (SUCCESS)",
                { ["SUCCEEDED"] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2]; },
                [],
                1.2,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' && (missionNamespace getVariable ['ARC_activeIncidentCloseReady', false]) }"
            ];

            _obj addAction [
                "[MOBILE OPS] Close Active Incident (FAIL)",
                { ["FAILED"] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2]; },
                [],
                1.2,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' && (missionNamespace getVariable ['ARC_activeIncidentCloseReady', false]) }"
            ];

            _obj addAction [
                "[MOBILE OPS] FORCE Close Active Incident (SUCCESS)",
                { ["SUCCEEDED", true, player] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2]; },
                [],
                1.0,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' }"
            ];

            _obj addAction [
                "[MOBILE OPS] FORCE Close Active Incident (FAIL)",
                { ["FAILED", true, player] remoteExec ["ARC_fnc_tocRequestCloseIncident", 2]; },
                [],
                1.0,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' }"
            ];

            _obj addAction ["[MOBILE OPS] Save World State", {
                [] remoteExec ["ARC_fnc_tocRequestSave", 2];
            }, [], 0.85, true, true, "", "([player] call ARC_fnc_rolesCanApproveQueue)"];

            _obj addAction [
                "[MOBILE OPS] Reset Persistence + Tasks",
                { [] remoteExec ["ARC_fnc_tocRequestResetAll", 2]; },
                [],
                0.8,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (missionNamespace getVariable ['ARC_activeTaskId','']) isEqualTo '' }"
            ];

            _obj addAction ["[MOBILE OPS] Show Current Incident", {
                private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
                if (_taskId isEqualTo "") exitWith { ["No active incident.", "INFO", "TOAST"] call ARC_fnc_clientHint; };

                private _disp  = missionNamespace getVariable ["ARC_activeIncidentDisplayName", ""]; 
                private _type  = missionNamespace getVariable ["ARC_activeIncidentType", ""]; 
                private _zone  = missionNamespace getVariable ["ARC_activeIncidentZone", ""]; 
                private _mkr   = missionNamespace getVariable ["ARC_activeIncidentMarker", ""]; 
                private _pos   = missionNamespace getVariable ["ARC_activeIncidentPos", []];

                private _accepted = missionNamespace getVariable ["ARC_activeIncidentAccepted", false];
                private _accGroup = missionNamespace getVariable ["ARC_activeIncidentAcceptedByGroup", ""]; 
                private _sitrepSent = missionNamespace getVariable ["ARC_activeIncidentSitrepSent", false];
                private _sitrepFromG = missionNamespace getVariable ["ARC_activeIncidentSitrepFromGroup", ""]; 
                private _sitrepSum = missionNamespace getVariable ["ARC_activeIncidentSitrepSummary", ""]; 
                private _closeReady = missionNamespace getVariable ["ARC_activeIncidentCloseReady", false];
                private _suggRes = missionNamespace getVariable ["ARC_activeIncidentSuggestedResult", ""]; 
                private _closeReason = missionNamespace getVariable ["ARC_activeIncidentCloseReason", ""]; 

                private _status = "ASSIGNED";
                if (!_accepted) then { _status = "ASSIGNED (NOT ACCEPTED)"; };
                if (_accepted) then { _status = "ACCEPTED"; };
                if (_sitrepSent) then { _status = "SITREP SENT"; };
                if (_closeReady) then
                {
                    _status = if (_suggRes isEqualTo "") then { "READY TO CLOSE" } else { format ["READY TO CLOSE (%1)", _suggRes] };
                };

                private _grid = "";
                if (_pos isEqualType [] && { (count _pos) >= 2 }) then { _grid = mapGridPosition _pos; };

                // Exec snapshot (best-effort)
                private _kind = missionNamespace getVariable ["ARC_activeExecKind", ""]; 
                private _rad  = missionNamespace getVariable ["ARC_activeExecRadius", -1];
                private _holdReq = missionNamespace getVariable ["ARC_activeExecHoldReq", -1];
                private _holdAcc = missionNamespace getVariable ["ARC_activeExecHoldAccum", -1];
                private _deadlineAt = missionNamespace getVariable ["ARC_activeExecDeadlineAt", -1];

                private _deadlineTxt = "";
                if (_deadlineAt isEqualType 0 && { _deadlineAt > 0 }) then
                {
                    private _tLeft = round (_deadlineAt - serverTime);
                    _deadlineTxt = format ["%1s", (_tLeft max 0)];
                };

                private _txt = "";
                _txt = _txt + format ["Status: %1\n", _status];
                _txt = _txt + format ["Task: %1\n", _taskId];
                if (_disp != "") then { _txt = _txt + format ["Name: %1\n", _disp]; };
                if (_type != "") then { _txt = _txt + format ["Type: %1\n", _type]; };
                if (_zone != "") then { _txt = _txt + format ["Zone: %1\n", _zone]; };
                if (_grid != "") then { _txt = _txt + format ["Grid: %1\n", _grid]; };
                if (_mkr != "") then { _txt = _txt + format ["Marker: %1\n", _mkr]; };

                if (_accGroup != "") then { _txt = _txt + format ["Accepted: %1\n", _accGroup]; };

                if (_sitrepSent) then
                {
                    private _sLine = "";
                    if (_sitrepFromG != "") then { _sLine = _sLine + format ["From %1", _sitrepFromG]; };
                    if (_sitrepSum != "") then
                    {
                        if (_sLine != "") then { _sLine = _sLine + ": "; };
                        _sLine = _sLine + _sitrepSum;
                    };
                    if (_sLine != "") then { _txt = _txt + format ["SITREP: %1\n", _sLine]; };
                };

                if (_closeReady) then
                {
                    if (_closeReason != "") then { _txt = _txt + format ["Close: %1\n", _closeReason]; };
                };

                if (_kind != "") then
                {
                    private _e = format ["Exec: %1", _kind];
                    if (_rad isEqualType 0 && { _rad > 0 }) then { _e = _e + format [" | AO %1m", round _rad]; };
                    if (_holdReq isEqualType 0 && { _holdReq > 0 } && { _holdAcc isEqualType 0 }) then { _e = _e + format [" | Hold %1/%2s", round _holdAcc, round _holdReq]; };
                    if (_deadlineTxt != "") then { _e = _e + format [" | Deadline in %1", _deadlineTxt]; };
                    _txt = _txt + _e;
                };

                [_txt, "INFO", "HINT"] call ARC_fnc_clientHint;
            }];
            // TOC tasking queue (mobile ops)
            _obj addAction [
                "[MOBILE QUEUE] Open Queue (View/Approve)",
                { [] call ARC_fnc_intelUiOpenQueueManager; },
                [],
                0.95,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesIsAuthorized"
            ];

            // Follow-on orders (unit must accept)
            _obj addAction [
                "[MOBILE ORDER] Issue RTB (REFIT)",
                { ["RTB", "REFIT"] spawn ARC_fnc_intelClientTocIssueOrderPrompt; },
                [],
                0.90,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesCanApproveQueue"
            ];
            _obj addAction [
                "[MOBILE ORDER] Issue RTB (INTEL)",
                { ["RTB", "INTEL"] spawn ARC_fnc_intelClientTocIssueOrderPrompt; },
                [],
                0.89,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesCanApproveQueue"
            ];
            _obj addAction [
                "[MOBILE ORDER] Issue RTB (EPW)",
                { ["RTB", "EPW"] spawn ARC_fnc_intelClientTocIssueOrderPrompt; },
                [],
                0.88,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesCanApproveQueue"
            ];
            _obj addAction [
                "[MOBILE ORDER] Issue HOLD",
                { ["HOLD", ""] spawn ARC_fnc_intelClientTocIssueOrderPrompt; },
                [],
                0.87,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesCanApproveQueue"
            ];
            _obj addAction [
                "[MOBILE ORDER] Issue PROCEED (Assign Lead)",
                { ["PROCEED", ""] spawn ARC_fnc_intelClientTocIssueOrderPrompt; },
                [],
                0.86,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesCanApproveQueue) && { (count (missionNamespace getVariable ['ARC_leadPoolPublic', []])) > 0 }"
            ];



            // Cache action IDs added this init pass so we can remove them later.
            _obj setVariable [_actKey, (actionIDs _obj) - _beforeIds, false];

        };

        case "arc_toc_intel_1":
        {
            _obj addAction ["[TOC INTEL] Open Intel Screen", { [] call ARC_fnc_uiOpenIntelScreen; }];

            _obj addAction ["[TOC INTEL] Show Lead Pool (Hint)", {
                [] call ARC_fnc_tocShowLeadPoolLocal;
            }];

            _obj addAction ["[TOC INTEL] Show Intel Threads (Hint)", {
                [] call ARC_fnc_tocShowThreadsLocal;
            }];

            _obj addAction ["[S2] Log Sighting (Map Click + Note)", {
                ["SIGHTING"] call ARC_fnc_clientBeginIntelMapClick;
            }, [], 0.92, true, true, "", "([player] call ARC_fnc_rolesIsTocS2) || ([player] call ARC_fnc_rolesIsTocCommand)" ];

            _obj addAction ["[S2] Log HUMINT Tip (Map Click + Note)", {
                ["HUMINT"] call ARC_fnc_clientBeginIntelMapClick;
            }, [], 0.91, true, true, "", "([player] call ARC_fnc_rolesIsTocS2) || ([player] call ARC_fnc_rolesIsTocCommand)" ];

            _obj addAction ["[S2] Log ISR Report (Map Click + Note)", {
                ["ISR"] call ARC_fnc_clientBeginIntelMapClick;
            }, [], 0.90, true, true, "", "([player] call ARC_fnc_rolesIsTocS2) || ([player] call ARC_fnc_rolesIsTocCommand)" ];

            _obj addAction ["[S2] Log Sighting (Cursor Target)", {
                [] call ARC_fnc_clientLogCursorSighting;
            }, [], 0.89, true, true, "", "([player] call ARC_fnc_rolesIsTocS2) || ([player] call ARC_fnc_rolesIsTocCommand)" ];

            _obj addAction ["[S2] Request Intel Refresh", {
                [] remoteExec ["ARC_fnc_tocRequestRefreshIntel", 2];
            }, [], 0.88, true, true, "", "([player] call ARC_fnc_rolesIsTocS2) || ([player] call ARC_fnc_rolesIsTocCommand)" ];

            _obj addAction ["[TOC INTEL] Show Latest Intel (Hint)", {
                private _log = missionNamespace getVariable ["ARC_pub_intelLog", []];
                if (!(_log isEqualType []) || {(count _log) isEqualTo 0}) exitWith { ["No intel entries yet.", "INFO", "TOAST"] call ARC_fnc_clientHint; };

                private _last = _log select ((count _log) - 1);
                _last params ["_iid", "_t", "_cat", "_sum", "_p", "_meta"];
                [format ["%1 (%2)\n%3", _iid, _cat, _sum], "INFO", "HINT"] call ARC_fnc_clientHint;
            }];

            // TOC tasking queue visibility + S2 lead requests (approval workflow)
            _obj addAction [
                "[TOC QUEUE] Open Queue (View/Approve)",
                { [] call ARC_fnc_intelUiOpenQueueManager; },
                [],
                0.95,
                true,
                true,
                "",
                "[player] call ARC_fnc_rolesIsAuthorized"
            ];

            _obj addAction [
                "[S2] Create Lead Request (RECON) (Map Click)",
                { ["RECON"] call ARC_fnc_intelClientBeginLeadRequestMapClick; },
                [],
                0.92,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesIsTocS2) || ([player] call ARC_fnc_rolesIsTocCommand)"
            ];
            _obj addAction [
                "[S2] Create Lead Request (PATROL) (Map Click)",
                { ["PATROL"] call ARC_fnc_intelClientBeginLeadRequestMapClick; },
                [],
                0.91,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesIsTocS2) || ([player] call ARC_fnc_rolesIsTocCommand)"
            ];
            _obj addAction [
                "[S2] Create Lead Request (CHECKPOINT) (Map Click)",
                { ["CHECKPOINT"] call ARC_fnc_intelClientBeginLeadRequestMapClick; },
                [],
                0.90,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesIsTocS2) || ([player] call ARC_fnc_rolesIsTocCommand)"
            ];
            _obj addAction [
                "[S2] Create Lead Request (CIVIL) (Map Click)",
                { ["CIVIL"] call ARC_fnc_intelClientBeginLeadRequestMapClick; },
                [],
                0.89,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesIsTocS2) || ([player] call ARC_fnc_rolesIsTocCommand)"
            ];
            _obj addAction [
                "[S2] Create Lead Request (IED) (Map Click)",
                { ["IED"] call ARC_fnc_intelClientBeginLeadRequestMapClick; },
                [],
                0.88,
                true,
                true,
                "",
                "([player] call ARC_fnc_rolesIsTocS2) || ([player] call ARC_fnc_rolesIsTocCommand)"
            ];
        };

        case "arc_toc_screen_1":
        {
            _obj addAction ["SITREP: Open SITREP Screen", { [] call ARC_fnc_uiOpenSitrepScreen; }];
            _obj addAction ["SITREP: Open Intel Screen", { [] call ARC_fnc_uiOpenIntelScreen; }];
            _obj addAction ["SITREP: Open Ops Screen", { [] call ARC_fnc_uiOpenOpsScreen; }];
        };

        case "arc_toc_air_1":
        {
            _obj addAction ["AIR: Open Ops Screen", { [] call ARC_fnc_uiOpenOpsScreen; }];
            _obj addAction ["AIR: Open SITREP Screen", { [] call ARC_fnc_uiOpenSitrepScreen; }];
            _obj addAction ["AIR: (Placeholder) Air tasking not implemented yet", {
                ["Air tasking screen is reserved for a later iteration (AFCENT / CAOC hooks, CAS requests, etc.).", "INFO", "TOAST"] call ARC_fnc_clientHint;
            }];
        };

        default
        {
            _obj addAction ["TOC: Open SITREP Screen", { [] call ARC_fnc_uiOpenSitrepScreen; }];
        };
    };


    // Store newly-added actions so we can verify/rebind later.
    private _after = actionIDs _obj;
    private _added = _after - _before;
    _obj setVariable ["ARC_toc_actionIds", _added, false];

} forEach _tocVars;


// ---------------------------------------------------------------------------
// FIELD COMMAND ACTIONS (radio-style) - available on the player anywhere.
// - Field commanders can ACCEPT the active incident without requiring an OPS object.
// - SITREP actions remain gated until the incident has been ACCEPTED.
// ---------------------------------------------------------------------------

if (missionNamespace getVariable ["ARC_sitrepInWorldActionsEnabled", false]) then
{
if (!(player getVariable ['ARC_fieldSitrepActionsAdded', false])) then
{
    player setVariable ['ARC_fieldSitrepActionsAdded', true];

    private _tag = [player] call ARC_fnc_rolesGetTag;
    private _pfx = format ['[Player] Actions [%1]:', _tag];

    private _condSitrep  = "[player] call ARC_fnc_clientCanSendSitrep";
    private _condFollow  = "[] call ARC_fnc_intelClientCanRequestFollowOn";
    private _condAccept  = "[] call ARC_fnc_intelClientCanAcceptOrder";
    private _condIncAcc  = "([player] call ARC_fnc_rolesIsAuthorized) && { (missionNamespace getVariable ['ARC_activeTaskId','']) != '' } && { !(missionNamespace getVariable ['ARC_activeIncidentAccepted', false]) }";

    // Accept outstanding TOC order (if any)
    player addAction [
        format ['%1 Accept TOC Order', _pfx],
        { [] spawn ARC_fnc_intelClientAcceptOrder; },
        [],
        1.25,
        true,
        true,
        '',
        _condAccept
    ];

    // Accept the currently active incident from the field (no OPS object required)
    player addAction [
        format ['%1 Accept Active Incident', _pfx],
        { [player] remoteExec ["ARC_fnc_tocRequestAcceptIncident", 2]; },
        [],
        1.24,
        true,
        true,
        '',
        _condIncAcc
    ];

    // ACE3 parity: add the same acceptance actions into the ACE self-interact menu.
    // This removes dependence on the vanilla scroll menu for core command-cycle steps.
    [] spawn {
        uiSleep 0.5;
        if (isNil "ace_interact_menu_fnc_createAction" || { isNil "ace_interact_menu_fnc_addActionToObject" }) exitWith {};

        if (player getVariable ["ARC_aceFieldCommandActionsAdded", false]) exitWith {};
        player setVariable ["ARC_aceFieldCommandActionsAdded", true];

        private _aAcceptOrder = [
            "ARC_ACCEPT_TOC_ORDER",
            "ARC: Accept TOC Order",
            "",
            {
                params ["_target", "_player", "_params"];
                [] spawn ARC_fnc_intelClientAcceptOrder;
            },
            {
                params ["_target", "_player", "_params"];
                [] call ARC_fnc_intelClientCanAcceptOrder
            }
        ] call ace_interact_menu_fnc_createAction;
        [player, 1, ["ACE_SelfActions"], _aAcceptOrder] call ace_interact_menu_fnc_addActionToObject;

        private _aAcceptInc = [
            "ARC_ACCEPT_ACTIVE_INCIDENT",
            "ARC: Accept Active Incident",
            "",
            {
                params ["_target", "_player", "_params"];
                [_player] remoteExec ["ARC_fnc_tocRequestAcceptIncident", 2];
            },
            {
                params ["_target", "_player", "_params"];
                ([_player] call ARC_fnc_rolesIsAuthorized)
                && { (missionNamespace getVariable ["ARC_activeTaskId", ""]) != "" }
                && { !(missionNamespace getVariable ["ARC_activeIncidentAccepted", false]) }
            }
        ] call ace_interact_menu_fnc_createAction;
        [player, 1, ["ACE_SelfActions"], _aAcceptInc] call ace_interact_menu_fnc_addActionToObject;

        diag_log "[ARC][ACE] Added field command ACE self-interact actions (accept order / accept incident).";
    };

    // SITREP recommendations
    player addAction [
        format ['%1 Send SITREP (Recommend SUCCESS)', _pfx],
        { ['SUCCEEDED', false] spawn ARC_fnc_clientSendSitrep; },
        [],
        1.20,
        true,
        true,
        '',
        _condSitrep
    ];

    player addAction [
        format ['%1 Send SITREP (Recommend FAIL)', _pfx],
        { ['FAILED', false] spawn ARC_fnc_clientSendSitrep; },
        [],
        1.10,
        true,
        true,
        '',
        _condSitrep
    ];

    // Follow-on requests are captured inside the SITREP workflow (no separate request actions).

};
};

true
