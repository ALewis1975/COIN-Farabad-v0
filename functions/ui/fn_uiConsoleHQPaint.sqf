/*
    ARC_fnc_uiConsoleHQPaint

    UI09: paint the Headquarters (Admin) tab.

    Access rules:
      - OMNI group OR TOC Command OR TOC S3 OR BN Command group token.
      - This tab is the consolidation point for legacy reset/save/debug tools.

    Params:
      0: DISPLAY
      1: BOOL - rebuild list (default true)
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]],
    ["_rebuild", true, [true]]
];
if (isNull _display) exitWith {false};

private _ctrlList = _display displayCtrl 78011;

// Force rebuild if the main list currently belongs to another tab.
// This prevents INTEL list items persisting when switching to HQ (and vice versa).
private _owner = uiNamespace getVariable ["ARC_console_mainListOwner", ""];
if (!(_owner isEqualType "")) then { _owner = ""; };
_owner = toUpper (trim _owner);
private _ownerChanged = (!(_owner isEqualTo "HQ"));
if (_ownerChanged) then { _rebuild = true; };
uiNamespace setVariable ["ARC_console_mainListOwner", "HQ"];
private _ctrlDetails = _display displayCtrl 78012;
private _b1 = _display displayCtrl 78021;
private _b2 = _display displayCtrl 78022;

// HQ sub-panel layout (TOOLS mode): mirror S2 stacked panes.
// Keep MainList as hidden master data source so existing execution routing remains unchanged.
private _ensureHQSubPanels = {
    params ["_display"];

    private _k = "ARC_hq_subPanels";
    private _panels = uiNamespace getVariable [_k, []];

    private _ok = (_panels isEqualType [] && { (count _panels) == 3 });
    if (_ok) then {
        {
            if !(_x isEqualType [] && { (count _x) == 3 }) exitWith { _ok = false; };
            if (_ok) then {
                if (isNull (_x # 0) || { isNull (_x # 1) } || { isNull (_x # 2) }) exitWith { _ok = false; };
            };
        } forEach _panels;
    };
    if (!_ok) then { _panels = []; };

    if (_panels isEqualTo []) then {
        private _mkPanel = {
            params ["_title"];

            private _bg  = _display ctrlCreate ["RscText", -1];
            private _lbl = _display ctrlCreate ["RscText", -1];
            private _lb  = _display ctrlCreate ["RscListbox", -1];

            _lbl ctrlSetText _title;
            _bg  ctrlSetBackgroundColor [0.05,0.05,0.05,0.65];
            _lbl ctrlSetBackgroundColor [0.05,0.05,0.05,0.92];
            _lbl ctrlSetTextColor [0.722,0.608,0.420,1];
            _lb  ctrlSetBackgroundColor [0.05,0.05,0.05,0.65];

            _lb ctrlAddEventHandler ["LBSelChanged", {
                params ["_ctrl", "_idx"];
                if (_idx < 0) exitWith {};
                if (uiNamespace getVariable ["ARC_hq_subPanels_suppressSel", false]) exitWith {};

                private _d = _ctrl lbData _idx;
                if (!(_d isEqualType "") || { _d isEqualTo "" || { _d isEqualTo "HDR" } }) exitWith {};

                private _disp = ctrlParent _ctrl;
                if (isNull _disp) exitWith {};

                private _master = _disp displayCtrl 78011;
                if (isNull _master) exitWith {};

                private _found = -1;
                for "_i" from 0 to ((lbSize _master) - 1) do {
                    if ((_master lbData _i) isEqualTo _d) exitWith { _found = _i; };
                };

                if (_found >= 0) then {
                    _master lbSetCurSel _found;
                    [_disp, false] call ARC_fnc_uiConsoleHQPaint;
                };
            }];

            [_bg, _lbl, _lb]
        };

        _panels = [
            ["ADMIN TOOLS"] call _mkPanel,
            ["INCIDENTS"] call _mkPanel,
            ["DIAGNOSTICS"] call _mkPanel
        ];

        uiNamespace setVariable [_k, _panels];
    };

    _panels
};

private _layoutHQSubPanels = {
    params ["_ctrlList", "_panels"];
    if (isNull _ctrlList) exitWith {};

    private _pL = ctrlPosition _ctrlList;
    private _xPos = _pL # 0;
    private _y = _pL # 1;
    private _w = _pL # 2;
    private _h = _pL # 3;

    private _gap = 0.004;
    private _hHdr = 0.03;
    private _hTotalGap = _gap * 2;
    private _hLB = ((_h - _hTotalGap) / 3) - _hHdr;
    if (_hLB < 0.04) then { _hLB = 0.04; };

    private _yCur = _y;
    {
        _x params ["_bg", "_lbl", "_lb"];
        private _ph = _hHdr + _hLB;

        _bg  ctrlSetPosition [_xPos, _yCur, _w, _ph];
        _lbl ctrlSetPosition [_xPos, _yCur, _w, _hHdr];
        _bg ctrlCommit 0;
        _lbl ctrlCommit 0;

        _lb  ctrlSetPosition [_xPos, _yCur + _hHdr, _w, _hLB];
        _lb ctrlCommit 0;

        _yCur = _yCur + _ph + _gap;
    } forEach _panels;
};

private _renderHQSubPanelsFromMaster = {
    params ["_display", "_master", "_panels"];
    if (isNull _master) exitWith {};

    _panels params ["_pAdmin", "_pInc", "_pDiag"];
    private _lbAdmin = _pAdmin # 2;
    private _lbInc   = _pInc # 2;
    private _lbDiag  = _pDiag # 2;

    { lbClear _x; } forEach [_lbAdmin, _lbInc, _lbDiag];

    private _in = {
        params ["_needle", "_arr"];
        (_arr find _needle) >= 0
    };

    private _adminRows = [
        "ADMIN_SAVE", "ADMIN_CIVSUB_SAVE", "ADMIN_RESET", "ADMIN_CIVSUB_RESET",
        "ADMIN_FORCE_CLOSE_SUCC", "ADMIN_FORCE_CLOSE_FAIL", "ADMIN_REBUILD_ACTIVE", "ADMIN_BROADCAST"
    ];
    private _incRows = ["ADMIN_INCIDENTS"];
    private _diagRows = ["ADMIN_COVERAGE", "ADMIN_QA", "ADMIN_COMPILE", "ADMIN_DUMP_LEADS", "ADMIN_DUMP_INTEL", "ADMIN_DIAG_STATUS", "ADMIN_DIAG_TOGGLE_DEBUG"];

    for "_i" from 0 to ((lbSize _master) - 1) do {
        private _d = _master lbData _i;
        if (!(_d isEqualType "") || { _d isEqualTo "" || { toUpper _d isEqualTo "HDR" } }) then { continue; };

        private _lbl = _master lbText _i;
        private _target = controlNull;

        if ([_d, _adminRows] call _in) then { _target = _lbAdmin; };
        if ([_d, _incRows] call _in) then { _target = _lbInc; };
        if ([_d, _diagRows] call _in) then { _target = _lbDiag; };

        if (!isNull _target) then {
            private _j = _target lbAdd _lbl;
            _target lbSetData [_j, _d];
        };
    };

    {
        if ((lbSize _x) <= 0) then {
            private _j = _x lbAdd "(No items)";
            _x lbSetData [_j, "HDR"];
            _x lbSetColor [_j, [0.70,0.70,0.70,1]];
            _x lbSetSelectColor [_j, [0.70,0.70,0.70,1]];
        };
    } forEach [_lbAdmin, _lbInc, _lbDiag];

    // Sync panel selection from master selected item.
    private _sel = lbCurSel _master;
    private _selData = if (_sel < 0) then { "" } else { _master lbData _sel };

    uiNamespace setVariable ["ARC_hq_subPanels_suppressSel", true];
    {
        private _lb = _x # 2;
        _lb lbSetCurSel -1;
        if (!(_selData isEqualTo "")) then {
            for "_k" from 0 to ((lbSize _lb) - 1) do {
                if ((_lb lbData _k) isEqualTo _selData) exitWith { _lb lbSetCurSel _k; };
            };
        };
    } forEach _panels;
    uiNamespace setVariable ["ARC_hq_subPanels_suppressSel", false];
};

// HQ mode: TOOLS (default) or INCIDENTS (incident picker)
private _mode = uiNamespace getVariable ["ARC_console_hqMode", "TOOLS"];
if (!(_mode isEqualType "")) then { _mode = "TOOLS"; };
_mode = toUpper (trim _mode);
if !(_mode in ["TOOLS", "INCIDENTS"]) then { _mode = "TOOLS"; };

// Prevent the 1.2s console refresh loop from clearing/rebuilding the HQ list every tick.
// Rebuild only when:
//  - the caller explicitly forces it AND the list is currently empty, OR
//  - the HQ mode changed (TOOLS <-> INCIDENTS), OR
//  - the list has never been built for this mode.
private _lastMode = uiNamespace getVariable ["ARC_console_hqLastMode", ""]; 
if (!(_lastMode isEqualType "")) then { _lastMode = ""; };

private _needRebuild = _rebuild;
if (!isNull _ctrlList) then
{
    private _hasRows = (lbSize _ctrlList) > 0;

    // Validate that the existing rows look like HQ-owned data.
    // If not, force rebuild even when owner/mode appears unchanged.
    private _hasHqRow = false;
    for "_i" from 0 to ((lbSize _ctrlList) - 1) do
    {
        private _d = _ctrlList lbData _i;

        if (_mode isEqualTo "INCIDENTS") then
        {
            // Incident picker rows are grouped with HDR rows and marker|type|display payload rows.
            if (_d isEqualTo "HDR") exitWith { _hasHqRow = true; };
            if (_d isEqualType "") then
            {
                private _parts = _d splitString "|";
                if ((count _parts) >= 3) exitWith { _hasHqRow = true; };
            };
        }
        else
        {
            if (_d in ["ADMIN_SAVE","ADMIN_CIVSUB_SAVE","ADMIN_RESET","ADMIN_AIRBASE_RESET_CTRL","ADMIN_CIVSUB_RESET","ADMIN_FORCE_CLOSE_SUCC","ADMIN_FORCE_CLOSE_FAIL","ADMIN_REBUILD_ACTIVE","ADMIN_BROADCAST","ADMIN_INCIDENTS","ADMIN_COVERAGE","ADMIN_QA","ADMIN_COMPILE","ADMIN_DUMP_LEADS","ADMIN_DUMP_INTEL","ADMIN_DIAG_STATUS","ADMIN_DIAG_TOGGLE_DEBUG"]) exitWith { _hasHqRow = true; };
        };
    };

    // Always rebuild when entering HQ from another tab to replace any foreign rows
    // (e.g., INTEL/S2 data) with HQ data before projecting into sub-panels.
    if (_ownerChanged || { !_hasHqRow }) then
    {
        _needRebuild = true;
    }
    else
    {
        if (!(_lastMode isEqualTo _mode)) then
        {
            _needRebuild = true;
        }
        else
        {
            // Same mode as last paint: only rebuild if the list is empty.
            if (_hasRows) then { _needRebuild = false; };
        };
    };
};

uiNamespace setVariable ["ARC_console_hqLastMode", _mode];

// Access gating
private _isOmni = [player, "OMNI"] call ARC_fnc_rolesHasGroupIdToken;
private _isCmd = [player] call ARC_fnc_rolesIsTocCommand;
private _isTocS3 = [player] call ARC_fnc_rolesIsTocS3;

private _hqTokens = missionNamespace getVariable [
    "ARC_consoleHQTokens",
    ["BNHQ","BN CMD","BN_COMMAND","BNCOMMAND","BN CO","BNCO","BN CDR","REDFALCON 6","REDFALCON6","FALCON 6","FALCON6"]
];
private _isBnCmd = false;
{
    if ([player, _x] call ARC_fnc_rolesHasGroupIdToken) exitWith { _isBnCmd = true; };
} forEach _hqTokens;

private _canHQ = _isOmni || _isCmd || _isTocS3 || _isBnCmd;

if (!_canHQ) exitWith
{
    private _hqPanels = uiNamespace getVariable ["ARC_hq_subPanels", []];
    if (_hqPanels isEqualType []) then {
        {
            if (_x isEqualType [] && { (count _x) == 3 }) then {
                { if (!isNull _x) then { _x ctrlShow false; _x ctrlEnable false; }; } forEach _x;
            };
        } forEach _hqPanels;
    };

    if (!isNull _ctrlDetails) then
    {
        _ctrlDetails ctrlSetStructuredText parseText (
            "<t size='1.2' font='PuristaMedium'>HQ / ADMIN</t><br/><br/>" +
            "Access denied. This tab is restricted to TOC leadership and BN command staff." +
            "<br/><br/><t size='0.9' color='#AAAAAA'>If you need this access for testing, use the OMNI group or add a groupId token in ARC_consoleHQTokens.</t>"
        );

        // Auto-fit + clamp to viewport so the controls group can scroll when needed.
        [_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
        private _grp = _display displayCtrl 78016;
        private _minH = if (!isNull _grp) then { (ctrlPosition _grp) # 3 } else { 0.74 };
        private _p = ctrlPosition _ctrlDetails;
        _p set [3, (_p # 3) max _minH];
        _ctrlDetails ctrlSetPosition _p;
        _ctrlDetails ctrlCommit 0;
    };
    if (!isNull _b1) then { _b1 ctrlEnable false; _b1 ctrlSetText "EXECUTE"; };
    if (!isNull _b2) then { _b2 ctrlEnable false; _b2 ctrlSetText ""; };
    true
};

// Populate HQ list (tools or incident picker)
if (_needRebuild && {!isNull _ctrlList}) then
{
    private _rememberKey = if (_mode isEqualTo "INCIDENTS") then {"ARC_console_hqIncSelData"} else {"ARC_console_hqSelData"};
    private _remember = uiNamespace getVariable [_rememberKey, ""]; 

    lbClear _ctrlList;

    private _addHdr = {
        params ["_label"];
        private _i = _ctrlList lbAdd ("--- " + _label + " ---");
        _ctrlList lbSetData [_i, "HDR"];
        _ctrlList lbSetColor [_i, [0.75,0.75,0.75,1]];
        _i
    };

    private _addRow = {
        params ["_label", "_data"];
        private _i = _ctrlList lbAdd _label;
        _ctrlList lbSetData [_i, _data];
        _i
    };

    if (_mode isEqualTo "INCIDENTS") then
    {
        ["INCIDENT PICKER"] call _addHdr;

        // Load incident catalog from mission files.
        // NOTE: do NOT use fileExists here. In MP / packed mission contexts, fileExists can be misleading.
        // Instead, attempt to preprocess+compile and treat non-array results as "missing/invalid".
        // Cache the parsed catalog in uiNamespace so the 1.2s refresh loop does not recompile it every tick.
        private _catalog = uiNamespace getVariable ["ARC_console_incidentCatalogCache", []];
        if (!(_catalog isEqualType [])) then { _catalog = []; };

        if ((count _catalog) <= 0) then
        {
            private _catPath = "data\incident_markers.sqf";
            private _tmp = call compile preprocessFileLineNumbers _catPath;
            if (_tmp isEqualType []) then
            {
                _catalog = _tmp;
                uiNamespace setVariable ["ARC_console_incidentCatalogCache", _catalog];
            }
            else
            {
                _catalog = [];
                uiNamespace setVariable ["ARC_console_incidentCatalogCache", []];

                // Fail soft: show a visible message and keep HQ functional.
                [format ["Catalog load failed: %1", _catPath], "HDR"] call _addRow;
            };
        };

        // Group by incident type for quick scanning.
        private _types = ["PATROL","RECON","CIVIL","CHECKPOINT","LOGISTICS","ESCORT","IED","RAID","DEFEND","QRF"];

        {
            private _tU = _x;
            private _rows = _catalog select {
                _x isEqualType [] && { (count _x) >= 3 } && { toUpper (_x # 2) isEqualTo _tU }
            };

            if ((count _rows) > 0) then
            {
                [_tU] call _addHdr;
                {
                    _x params ["_rawMarker", "_disp", "_t"]; 
                    private _m = [_rawMarker] call ARC_fnc_worldResolveMarker;
                    if (!(_m in allMapMarkers)) then { continue; };

                    // Data encoding: marker|type|display
                    private _data = format ["%1|%2|%3", _rawMarker, _t, _disp];
                    [_disp, _data] call _addRow;
                } forEach _rows;
            };
        } forEach _types;

        if ((lbSize _ctrlList) <= 0) then
        {
            ["No catalog entries found.", "HDR"] call _addRow;
        };
    }
    else
    {
        ["ADMIN TOOLS"] call _addHdr;
        ["Save World State (Persistence)", "ADMIN_SAVE"] call _addRow;
        ["Save CIVSUB (Campaign)", "ADMIN_CIVSUB_SAVE"] call _addRow;
        ["Reset All (CAUTION)", "ADMIN_RESET"] call _addRow;
        ["Reset AIRBASE Control State", "ADMIN_AIRBASE_RESET_CTRL"] call _addRow;
        ["Reset CIVSUB Campaign (CAUTION)", "ADMIN_CIVSUB_RESET"] call _addRow;
        ["Force Close Incident (SUCCEEDED)", "ADMIN_FORCE_CLOSE_SUCC"] call _addRow;
        ["Force Close Incident (FAILED)", "ADMIN_FORCE_CLOSE_FAIL"] call _addRow;
        ["Rebuild Active Incident Task", "ADMIN_REBUILD_ACTIVE"] call _addRow;
        ["Broadcast State to Clients", "ADMIN_BROADCAST"] call _addRow;

        ["INCIDENTS"] call _addHdr;
        ["Incident Picker", "ADMIN_INCIDENTS"] call _addRow;

        ["DIAGNOSTICS"] call _addHdr;
        ["Rebuild UI Coverage Map", "ADMIN_COVERAGE"] call _addRow;
        ["Run Console QA Audit (Server)", "ADMIN_QA"] call _addRow;
        ["Run Compile Audit (Server)", "ADMIN_COMPILE"] call _addRow;
        ["Dump Lead Pool (Local)", "ADMIN_DUMP_LEADS"] call _addRow;
        ["Dump Intel Log (Local)", "ADMIN_DUMP_INTEL"] call _addRow;
        ["Diagnostics Snapshot (Server)", "ADMIN_DIAG_STATUS"] call _addRow;
        ["Toggle Debug Mode (Server)", "ADMIN_DIAG_TOGGLE_DEBUG"] call _addRow;
    };

    // Restore selection
    if (_remember != "") then
    {
        for "_i" from 0 to ((lbSize _ctrlList) - 1) do
        {
            if ((_ctrlList lbData _i) isEqualTo _remember) exitWith { _ctrlList lbSetCurSel _i; };
        };
    };
};

// TOOLS mode uses S2-style stacked sub-panels; INCIDENTS keeps the classic list.
if (!isNull _ctrlList) then
{
    if (_mode isEqualTo "TOOLS") then
    {
        _ctrlList ctrlShow false;
        _ctrlList ctrlEnable false;

        private _hqPanels = [_display] call _ensureHQSubPanels;
        [_ctrlList, _hqPanels] call _layoutHQSubPanels;
        [_display, _ctrlList, _hqPanels] call _renderHQSubPanelsFromMaster;

        {
            (_x # 0) ctrlShow true;
            (_x # 1) ctrlShow true;
            (_x # 2) ctrlShow true;
            (_x # 2) ctrlEnable true;
        } forEach _hqPanels;
    }
    else
    {
        private _hqPanels = uiNamespace getVariable ["ARC_hq_subPanels", []];
        if (_hqPanels isEqualType []) then {
            {
                if (_x isEqualType [] && { (count _x) == 3 }) then {
                    { if (!isNull _x) then { _x ctrlShow false; _x ctrlEnable false; }; } forEach _x;
                };
            } forEach _hqPanels;
        };
        _ctrlList ctrlShow true;
        _ctrlList ctrlEnable true;
    };
};

// Selected tool details
private _sel = if (isNull _ctrlList) then { -1 } else { lbCurSel _ctrlList };
private _data = if (_sel < 0) then { "" } else { _ctrlList lbData _sel };
private _selKey = if (_mode isEqualTo "INCIDENTS") then {"ARC_console_hqIncSelData"} else {"ARC_console_hqSelData"};
uiNamespace setVariable [_selKey, _data];

private _txt = if (_mode isEqualTo "INCIDENTS") then
{
    "<t size='1.2' font='PuristaMedium'>HQ / INCIDENT PICKER</t><br/><br/>"
}
else
{
    "<t size='1.2' font='PuristaMedium'>HQ / ADMIN</t><br/><br/>"
};

private _enableExec = true;

switch (toUpper _data) do
{
    // INCIDENT PICKER selection rows store marker|type|display (do not uppercase the data payload)
    case "ADMIN_INCIDENTS":
    {
        _txt = _txt + "Open the incident picker. This lets HQ/TOC spawn a specific catalog incident (server-authoritative).";
        _enableExec = true;
    };

    case "ADMIN_SAVE":
    {
        _txt = _txt + "Save current mission state to persistence (server-side).";
    };

    case "ADMIN_CIVSUB_SAVE":
    {
        _txt = _txt + "Force-save CIVSUB campaign state (districts, identities, crime DB) to profileNamespace.";
    };
    case "ADMIN_RESET":
    {
        _txt = _txt + "<t color='#FF6666'>Reset all persistent state and clear active tasks.</t><br/><br/>" +
               "Use only for testing. This is destructive.";
    };

    case "ADMIN_AIRBASE_RESET_CTRL":
    {
        _txt = _txt + "Reset AIRBASE control state (runway lock, queue, pending clearances).<br/>" +
               "Keeps clearance history/events by default for audit continuity.";
    };

    case "ADMIN_CIVSUB_RESET":
    {
        _txt = _txt + "<t color='#FF6666'>Reset CIVSUB campaign persistence (district influence + identities + crime DB).</t><br/><br/>" +
               "This starts a new CIVSUB campaign_id. Use when district geometry or campaign seed changes.";
        _enableExec = true;
    };

    case "ADMIN_REBUILD_ACTIVE":
    {
        _txt = _txt + "Rebuilds the active incident task (useful after script errors / partial cleanup).";
    };
    case "ADMIN_BROADCAST":
    {
        _txt = _txt + "Broadcasts current public state to clients (forces UI refresh consistency).";
    };
    case "ADMIN_COVERAGE":
    {
        _txt = _txt + "Rebuilds and publishes the UI coverage map. Also logs to server RPT.";
    };
    case "ADMIN_QA":
    {
        _txt = _txt + "Runs a server-side QA audit of Farabad Console integration (functions + state coherence).";

        private _rep = uiNamespace getVariable ["ARC_console_lastQAReport", ""];
        if (_rep isEqualType "" && { !(_rep isEqualTo "") }) then
        {
            _txt = _txt + "<br/><br/><t font='PuristaMedium'>Last report:</t><br/>" + _rep;
        };
    };

    case "ADMIN_COMPILE":
    {
        _txt = _txt + "Attempts to compile all ARC functions listed in CfgFunctions. This surfaces SQF syntax errors early (check server RPT for file/line details).";

        private _rep = uiNamespace getVariable ["ARC_console_lastCompileReport", ""];
        if (_rep isEqualType "" && { !(_rep isEqualTo "") }) then
        {
            _txt = _txt + "<br/><br/><t font='PuristaMedium'>Last report:</t><br/>" + _rep;
        };
    };
    case "ADMIN_DUMP_LEADS":
    {
        _txt = _txt + "Print the current lead pool to your client log / hint (local-only).";
    };
    case "ADMIN_DUMP_INTEL":
    {
        _txt = _txt + "Print the latest intel log entries to your client log / hint (local-only).";
    };
    case "ADMIN_DIAG_STATUS":
    {
        _txt = _txt + "Request a diagnostics snapshot from the server. Shows all debug toggle states, subsystem health, logger config, and key metrics." +
               "<br/><br/><t size='0.9' color='#AAAAAA'>Results appear in this detail pane after the server responds.</t>";

        private _rep = uiNamespace getVariable ["ARC_console_lastDiagReport", ""];
        if (_rep isEqualType "" && { !(_rep isEqualTo "") }) then
        {
            _txt = _txt + "<br/><br/><t font='PuristaMedium'>Last report:</t><br/>" + _rep;
        };
    };
    case "ADMIN_DIAG_TOGGLE_DEBUG":
    {
        private _debugOn = missionNamespace getVariable ["ARC_debugLogEnabled", false];
        private _stateLabel = if (_debugOn) then { "<t color='#6EE7B7'>ON</t>" } else { "<t color='#BDBDBD'>OFF</t>" };
        _txt = _txt + "Toggle all debug flags on/off as a group (server-authoritative).<br/><br/>" +
               "Current debug state: " + _stateLabel + "<br/><br/>" +
               "Toggles: ARC_debugLogEnabled, ARC_debugLogToChat, ARC_debugInspectorEnabled, civsub_v1_debug, civsub_v1_traffic_debug, airbase_v1_tower_authDebug, FARABAD_log_minLevel" +
               "<br/><br/><t size='0.9' color='#AAAAAA'>This mirrors the ARC_profile_devMode override block in initServer.sqf.</t>";
    };
    case "HDR":
    {
        _txt = _txt + "Select an admin tool.";
        _enableExec = false;
    };

    case "ADMIN_FORCE_CLOSE_SUCC":
    {
        _txt = _txt + "Force-close the active incident as SUCCEEDED.\n\n"
            + "<t color='#AAAAAA'>Use only for recovery/testing when the normal closeout flow is blocked.</t>";
        _enableExec = true;
    };

    case "ADMIN_FORCE_CLOSE_FAIL":
    {
        _txt = _txt + "Force-close the active incident as FAILED.\n\n"
            + "<t color='#AAAAAA'>Use only for recovery/testing when the normal closeout flow is blocked.</t>";
        _enableExec = true;
    };


    default
    {
        if (_mode isEqualTo "INCIDENTS") then
        {
            // Parse selection
            private _raw = _data;
            if (!(_raw isEqualType "")) then { _raw = ""; };

            if (_raw isEqualTo "" || { (toUpper _raw) isEqualTo "HDR" }) then
            {
                _txt = _txt + "Select a catalog incident, then press SPAWN.";
                _enableExec = false;
            }
            else
            {
                private _parts = _raw splitString "|";
                if ((count _parts) < 3) then
                {
                    _txt = _txt + "Invalid selection.";
                    _enableExec = false;
                }
                else
                {
                    private _mkr = _parts # 0;
                    private _typ = _parts # 1;
                    private _disp = _parts # 2;

                    private _m = [_mkr] call ARC_fnc_worldResolveMarker;
                    private _pos = getMarkerPos _m;
                    private _zone = [_mkr] call ARC_fnc_worldGetZoneForMarker;
                    private _grid = mapGridPosition _pos;

                    private _taskId = missionNamespace getVariable ["ARC_activeTaskId", ""]; 
                    if (!(_taskId isEqualType "")) then { _taskId = ""; };
                    private _blocked = (!(_taskId isEqualTo ""));

                    _txt = _txt + format [
                        "<t font='PuristaMedium'>%1</t><br/>Type: %2<br/>Marker: %3<br/>Grid: %4<br/>Zone: %5",
                        _disp,
                        toUpper _typ,
                        _mkr,
                        _grid,
                        _zone
                    ];

                    if (_blocked) then
                    {
                        _txt = _txt + "<br/><br/><t color='#FFAA66'>Blocked:</t> an incident is already active. Close it (and complete SITREP) before spawning a new one.";
                        _enableExec = false;
                    }
                    else
                    {
                        _txt = _txt + "<br/><br/><t color='#AAAAAA'>Press SPAWN to create this incident (server-authoritative).</t>";
                        _enableExec = true;
                    };
                };
            };
        }
        else
        {
            _txt = _txt + "Select an admin tool.";
            _enableExec = false;
        };
    };
};

if (!isNull _ctrlDetails) then
{
    _ctrlDetails ctrlSetStructuredText parseText _txt;

    // Auto-fit + clamp to viewport so the controls group can scroll when needed.
    [_ctrlDetails] call BIS_fnc_ctrlFitToTextHeight;
    private _grp = _display displayCtrl 78016;
    private _minH = if (!isNull _grp) then { (ctrlPosition _grp) # 3 } else { 0.74 };
    private _p = ctrlPosition _ctrlDetails;
    _p set [3, (_p # 3) max _minH];
    _ctrlDetails ctrlSetPosition _p;
    _ctrlDetails ctrlCommit 0;
};

if (!isNull _b1) then
{
    _b1 ctrlEnable _enableExec;
    _b1 ctrlSetText (if (_mode isEqualTo "INCIDENTS") then {"SPAWN"} else {"EXECUTE"});
};

if (!isNull _b2) then
{
    private _showBack = (_mode isEqualTo "INCIDENTS");
    _b2 ctrlShow _showBack;
    _b2 ctrlEnable _showBack;
    _b2 ctrlSetText (if (_showBack) then {"BACK"} else {""});
};

true
