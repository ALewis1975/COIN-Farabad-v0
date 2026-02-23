/*
    ARC_fnc_uiConsoleS1Paint

    Client: paint the S-1 Personnel echelon tree view (read-only).

    Left panel  — collapsible category tree; clicking a branch expands/
                  collapses it; clicking a leaf selects it for detail.
    Right panel — aggregate stats for branch nodes; unit roster for leaves.

    Rev-check: skips full repaint when ARC_pub_s1_registryUpdatedAt has not
    changed, no expand/collapse action occurred, and the selection is
    unchanged since the last paint cycle.

    Params:
      0: DISPLAY
*/

if (!hasInterface) exitWith { false };

params [
    ["_display", displayNull, [displayNull]]
];

if (isNull _display) exitWith { false };

private _ctrlMain    = _display displayCtrl 78010;
private _ctrlList    = _display displayCtrl 78011;
private _ctrlDetails = _display displayCtrl 78012;
if (isNull _ctrlMain || { isNull _ctrlList } || { isNull _ctrlDetails }) exitWith { false };

// --- Pair accessor: get field value from a pairs record (avoids findIf) ---
private _getPair = {
    params ["_rec", "_key", "_def"];
    private _result = _def;
    {
        if ((_x isEqualType []) && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _key) }) exitWith {
            _result = _x select 1;
        };
    } forEach _rec;
    _result
};

// --- Rev-check inputs ---
private _updatedAt = missionNamespace getVariable ["ARC_pub_s1_registryUpdatedAt", -1];
if (!(_updatedAt isEqualType 0)) then { _updatedAt = -1; };

private _lastRev = uiNamespace getVariable ["ARC_console_s1LastRev", -1];
if (!(_lastRev isEqualType 0)) then { _lastRev = -1; };

private _expandToggled = uiNamespace getVariable ["ARC_console_s1ExpandToggled", false];
if (!(_expandToggled isEqualType false)) then { _expandToggled = false; };

private _lastSelData = uiNamespace getVariable ["ARC_console_s1LastSelData", ""];
if (!(_lastSelData isEqualType "")) then { _lastSelData = ""; };

// Current selection in the listbox (persists across paint calls)
private _curSelIdx = lbCurSel _ctrlList;
private _curSelData = "";
if (_curSelIdx >= 0) then { _curSelData = _ctrlList lbData _curSelIdx; };
if (!(_curSelData isEqualType "")) then { _curSelData = ""; };

// Skip if nothing changed (rev, expand state, or selection)
if (_updatedAt isEqualTo _lastRev && { !_expandToggled } && { _curSelData isEqualTo _lastSelData }) exitWith { true };

// Reset expand-toggle flag now that we're doing a full repaint
uiNamespace setVariable ["ARC_console_s1ExpandToggled", false];

// --- Read registry (v2 schema) ---
private _registry = missionNamespace getVariable ["ARC_pub_s1_registry", []];
if (!(_registry isEqualType [])) then { _registry = []; };

private _schema = [_registry, "schema", ""] call _getPair;
private _isV2 = _schema isEqualTo "s1_tree_v2";

private _groups   = [];
private _units    = [];
private _catStats = [];
private _catOrder = [];
if (_isV2) then {
    _groups   = [_registry, "groups",   []] call _getPair;
    _units    = [_registry, "units",    []] call _getPair;
    _catStats = [_registry, "catStats", []] call _getPair;
    _catOrder = [_registry, "catOrder", []] call _getPair;
    if (!(_groups   isEqualType [])) then { _groups   = []; };
    if (!(_units    isEqualType [])) then { _units    = []; };
    if (!(_catStats isEqualType [])) then { _catStats = []; };
    if (!(_catOrder isEqualType [])) then { _catOrder = []; };
};

// --- Read expand state ---
private _expandedNodes = uiNamespace getVariable ["ARC_console_s1ExpandedNodes", []];
if (!(_expandedNodes isEqualType [])) then { _expandedNodes = []; };

// --- Set up expand/collapse event handler on this control (once per display) ---
if (isNil { _ctrlList getVariable "ARC_s1EhAdded" }) then {
    _ctrlList setVariable ["ARC_s1EhAdded", true];
    _ctrlList ctrlAddEventHandler ["LBSelChanged", {
        params ["_ctrl", "_selIdx"];
        if (_ctrl getVariable ["ARC_s1SuppressSelChanged", false]) exitWith {};
        if (_selIdx < 0) exitWith {};
        private _nodeData = _ctrl lbData _selIdx;
        // Only branch nodes (prefixed "cat:") toggle expand/collapse
        if ((_nodeData find "cat:") isEqualTo 0) then {
            private _exp = uiNamespace getVariable ["ARC_console_s1ExpandedNodes", []];
            if (!(_exp isEqualType [])) then { _exp = []; };
            private _found = false;
            { if (_x isEqualTo _nodeData) exitWith { _found = true; }; } forEach _exp;
            if (_found) then {
                private _newExp = [];
                { if (!(_x isEqualTo _nodeData)) then { _newExp pushBack _x; }; } forEach _exp;
                uiNamespace setVariable ["ARC_console_s1ExpandedNodes", _newExp];
            } else {
                _exp pushBack _nodeData;
                uiNamespace setVariable ["ARC_console_s1ExpandedNodes", _exp];
            };
            uiNamespace setVariable ["ARC_console_s1ExpandToggled", true];
        };
    }];
};

// Preserve previous selection data string to restore after repaint
private _prevSelData = _curSelData;

// --- Paint left panel (echelon tree) ---
lbClear _ctrlList;
private _paintedSelData = "";

if (!_isV2 || { (count _catOrder) isEqualTo 0 }) then {
    _ctrlList lbAdd "No S-1 registry snapshot yet.";
    _ctrlList lbSetData [0, "__EMPTY__"];
    _ctrlList setVariable ["ARC_s1SuppressSelChanged", true];
    _ctrlList lbSetCurSel 0;
    _ctrlList setVariable ["ARC_s1SuppressSelChanged", false];
} else {
    {
        private _cat      = _x;
        private _catNodeId = format ["cat:%1", _cat];

        // Look up category aggregate stats
        private _catTotalPax = 0;
        private _catRd       = 0;
        private _catGrpCount = 0;
        {
            if ((_x isEqualType []) && { (count _x) >= 6 } && { ((_x select 0) isEqualTo _cat) }) exitWith {
                _catTotalPax = _x select 1;
                _catRd       = _x select 4;
                _catGrpCount = _x select 5;
            };
        } forEach _catStats;
        private _catRdPct = if (_catGrpCount > 0) then { format ["%1%%", round ((_catRd / _catGrpCount) * 100)] } else { "-" };

        private _isExpanded = false;
        { if (_x isEqualTo _catNodeId) exitWith { _isExpanded = true; }; } forEach _expandedNodes;

        private _expandIcon = if (_isExpanded) then { "v" } else { ">" };
        private _catLabel   = format ["%1 %2 | %3 pax | %4", _expandIcon, _cat, _catTotalPax, _catRdPct];
        private _catLbIdx   = _ctrlList lbAdd _catLabel;
        _ctrlList lbSetData [_catLbIdx, _catNodeId];
        if (_catNodeId isEqualTo _prevSelData) then { _paintedSelData = _catNodeId; };

        if (_isExpanded) then {
            // Collect groups belonging to this category
            private _catGroups = [];
            {
                if (!(_x isEqualType [])) then { continue; };
                if (!(([_x, "s1TopCategory", ""] call _getPair) isEqualTo _cat)) then { continue; };
                _catGroups pushBack _x;
            } forEach _groups;

            if (_cat isEqualTo "TF REDFALCON") then {
                // BN staff (depth 0) listed first
                {
                    if (!(_x isEqualType [])) then { continue; };
                    if (!(([_x, "s1EchelonDepth", -1] call _getPair) isEqualTo 0)) then { continue; };
                    private _cs  = [_x, "callsign", ""] call _getPair;
                    private _gid = [_x, "groupId",  ""] call _getPair;
                    private _pax = [_x, "s1PaxCount", 0] call _getPair;
                    private _act = [_x, "s1ActivePax", 0] call _getPair;
                    private _lbl = format ["    - %1 | %2/%3", if (_cs isEqualTo "") then {_gid} else {_cs}, _act, _pax];
                    private _li  = _ctrlList lbAdd _lbl;
                    _ctrlList lbSetData [_li, _gid];
                    if (_gid isEqualTo _prevSelData) then { _paintedSelData = _gid; };
                } forEach _catGroups;

                // Collect company letters (depth 1)
                private _companies = [];
                {
                    if (!(_x isEqualType [])) then { continue; };
                    if (!(([_x, "s1EchelonDepth", -1] call _getPair) isEqualTo 1)) then { continue; };
                    private _co = [_x, "s1CompanyLetter", ""] call _getPair;
                    private _coExists = false;
                    { if (_x isEqualTo _co) exitWith { _coExists = true; }; } forEach _companies;
                    if (!_coExists) then { _companies pushBack _co; };
                } forEach _catGroups;

                {
                    private _co       = _x;
                    private _coNodeId = format ["cat:REDF_CO_%1", _co];

                    // Find company HQ record (depth 1)
                    private _coPax = 0;
                    private _coAct = 0;
                    private _coCs  = format ["CO %1", _co];
                    private _coGid = "";
                    {
                        if ((_x isEqualType []) && { ([_x, "s1EchelonDepth", -1] call _getPair) isEqualTo 1 } && { ([_x, "s1CompanyLetter", ""] call _getPair) isEqualTo _co }) exitWith {
                            _coPax = [_x, "s1PaxCount", 0] call _getPair;
                            _coAct = [_x, "s1ActivePax", 0] call _getPair;
                            private _csRaw = [_x, "callsign", ""] call _getPair;
                            if (!(_csRaw isEqualTo "")) then { _coCs = _csRaw; };
                            _coGid = [_x, "groupId", ""] call _getPair;
                        };
                    } forEach _catGroups;

                    private _coExpanded = false;
                    { if (_x isEqualTo _coNodeId) exitWith { _coExpanded = true; }; } forEach _expandedNodes;
                    private _coIcon  = if (_coExpanded) then { "v" } else { ">" };
                    private _coLabel = format ["  %1 %2 | %3/%4 pax", _coIcon, _coCs, _coAct, _coPax];
                    private _coLbIdx = _ctrlList lbAdd _coLabel;
                    _ctrlList lbSetData [_coLbIdx, _coNodeId];
                    if (_coNodeId isEqualTo _prevSelData) then { _paintedSelData = _coNodeId; };
                    if (!(_coGid isEqualTo "") && { _coGid isEqualTo _prevSelData }) then { _paintedSelData = _coGid; };

                    if (_coExpanded) then {
                        // Platoons (depth 2) under this company
                        {
                            if (!(_x isEqualType [])) then { continue; };
                            if (!(([_x, "s1EchelonDepth", -1] call _getPair) isEqualTo 2)) then { continue; };
                            if (!(([_x, "s1CompanyLetter", ""] call _getPair) isEqualTo _co)) then { continue; };

                            private _pltGid    = [_x, "groupId",          ""] call _getPair;
                            private _pltCs     = [_x, "callsign",         ""] call _getPair;
                            private _pltPax    = [_x, "s1PaxCount",       0]  call _getPair;
                            private _pltAct    = [_x, "s1ActivePax",      0]  call _getPair;
                            private _pltPe     = [_x, "parentEchelon",    ""] call _getPair;
                            private _pltNodeId = format ["cat:REDF_PLT_%1", _pltPe];

                            private _pltExpanded = false;
                            { if (_x isEqualTo _pltNodeId) exitWith { _pltExpanded = true; }; } forEach _expandedNodes;
                            private _pltIcon  = if (_pltExpanded) then { "v" } else { ">" };
                            private _pltLabel = format ["    %1 %2 | %3/%4 pax", _pltIcon, if (_pltCs isEqualTo "") then {_pltGid} else {_pltCs}, _pltAct, _pltPax];
                            private _pltLbIdx = _ctrlList lbAdd _pltLabel;
                            _ctrlList lbSetData [_pltLbIdx, _pltNodeId];
                            if (_pltNodeId isEqualTo _prevSelData) then { _paintedSelData = _pltNodeId; };
                            if (_pltGid isEqualTo _prevSelData)    then { _paintedSelData = _pltGid; };

                            if (_pltExpanded) then {
                                // Squads (depth >= 3) whose parent echelon matches this platoon
                                {
                                    if (!(_x isEqualType [])) then { continue; };
                                    if (!(([_x, "s1EchelonDepth",      -1] call _getPair) >= 3))          then { continue; };
                                    if (!(([_x, "s1CompanyLetter",     ""] call _getPair) isEqualTo _co)) then { continue; };
                                    if (!(([_x, "s1ParentEchelonStr",  ""] call _getPair) isEqualTo _pltPe)) then { continue; };

                                    private _sqdGid = [_x, "groupId",     ""] call _getPair;
                                    private _sqdCs  = [_x, "callsign",    ""] call _getPair;
                                    private _sqdPax = [_x, "s1PaxCount",  0]  call _getPair;
                                    private _sqdAct = [_x, "s1ActivePax", 0]  call _getPair;
                                    private _sqdLbl = format ["      - %1 | %2/%3 pax", if (_sqdCs isEqualTo "") then {_sqdGid} else {_sqdCs}, _sqdAct, _sqdPax];
                                    private _sqdIdx = _ctrlList lbAdd _sqdLbl;
                                    _ctrlList lbSetData [_sqdIdx, _sqdGid];
                                    if (_sqdGid isEqualTo _prevSelData) then { _paintedSelData = _sqdGid; };
                                } forEach _catGroups;
                            };
                        } forEach _catGroups;
                    };
                } forEach _companies;

            } else {
                // Non-REDFALCON: flat list of groups under this category
                {
                    if (!(_x isEqualType [])) then { continue; };
                    private _cs  = [_x, "callsign",    ""] call _getPair;
                    private _gid = [_x, "groupId",     ""] call _getPair;
                    private _pax = [_x, "s1PaxCount",  0]  call _getPair;
                    private _act = [_x, "s1ActivePax", 0]  call _getPair;
                    private _displayName = if (_cs isEqualTo "") then { _gid } else { _cs };
                    private _lbl  = format ["    - %1 | %2/%3 pax", _displayName, _act, _pax];
                    private _lIdx = _ctrlList lbAdd _lbl;
                    _ctrlList lbSetData [_lIdx, _gid];
                    if (_gid isEqualTo _prevSelData) then { _paintedSelData = _gid; };
                } forEach _catGroups;
            };
        };
    } forEach _catOrder;

    // Restore or default selection
    private _newSel = 0;
    if (!(_paintedSelData isEqualTo "")) then {
        private _cnt = lbSize _ctrlList;
        private _si = 0;
        while { _si < _cnt } do {
            if ((_ctrlList lbData _si) isEqualTo _paintedSelData) exitWith { _newSel = _si; };
            _si = _si + 1;
        };
    };
    _ctrlList setVariable ["ARC_s1SuppressSelChanged", true];
    _ctrlList lbSetCurSel _newSel;
    _ctrlList setVariable ["ARC_s1SuppressSelChanged", false];
};

// --- Paint header (main text area) ---
private _main = "<t size='1.15' color='#B89B6B' font='PuristaMedium'>S-1 / Personnel Registry</t><br/>";
if (_updatedAt < 0 || { !_isV2 } || { (count _catOrder) isEqualTo 0 }) then {
    _main = _main + "<t color='#FFD166'>Snapshot unavailable (cold join / JIP sync pending).</t><br/>";
    _main = _main + "<t color='#AAAAAA'>Wait for server broadcast, then refresh.</t><br/>";
} else {
    private _totalPax = 0;
    {
        if (_x isEqualType [] && { (count _x) >= 2 }) then { _totalPax = _totalPax + (_x select 1); };
    } forEach _catStats;
    _main = _main + format ["<t color='#DDDDDD'>Updated T+%1s</t>  <t color='#DDDDDD'>BLUFOR groups: %2 | Strength: %3 pax</t><br/>", round _updatedAt, count _groups, _totalPax];
    _main = _main + "<t color='#AAAAAA'>Click category to expand/collapse. Click group for roster.</t><br/>";
};
_ctrlMain ctrlSetStructuredText parseText _main;

// --- Paint right panel (detail for selected node) ---
private _selIdx2 = lbCurSel _ctrlList;
private _selData2 = "";
if (_selIdx2 >= 0) then { _selData2 = _ctrlList lbData _selIdx2; };
if (!(_selData2 isEqualType "")) then { _selData2 = ""; };

private _details2 = "<t size='1.05' color='#B89B6B' font='PuristaMedium'>Echelon / Group Detail</t><br/>";

if (_selData2 isEqualTo "" || { _selData2 isEqualTo "__EMPTY__" }) then {
    _details2 = _details2 + "<t color='#AAAAAA'>No selection.</t>";
} else {
    // Determine node type: top-category branch, REDFALCON sub-branch, or leaf group
    private _isCatBranch  = ((_selData2 find "cat:") isEqualTo 0) && { !((_selData2 find "cat:REDF_") isEqualTo 0) };
    private _isRedfBranch = ((_selData2 find "cat:REDF_") isEqualTo 0);

    if (_isCatBranch) then {
        // Strip "cat:" prefix to recover category name
        private _catName = _selData2 select [4, (count _selData2) - 4];

        private _csPax    = 0;
        private _csAct    = 0;
        private _csKia    = 0;
        private _csRd     = 0;
        private _csGrpCnt = 0;
        {
            if ((_x isEqualType []) && { (count _x) >= 6 } && { ((_x select 0) isEqualTo _catName) }) exitWith {
                _csPax    = _x select 1;
                _csAct    = _x select 2;
                _csKia    = _x select 3;
                _csRd     = _x select 4;
                _csGrpCnt = _x select 5;
            };
        } forEach _catStats;
        private _csRdPct = if (_csGrpCnt > 0) then { format ["%1%%", round ((_csRd / _csGrpCnt) * 100)] } else { "-" };

        _details2 = _details2 + format ["<t color='#B89B6B'>Category:</t> <t color='#FFFFFF'>%1</t><br/>", _catName];
        _details2 = _details2 + format ["<t color='#B89B6B'>Groups:</t> <t color='#FFFFFF'>%1</t><br/>", _csGrpCnt];
        _details2 = _details2 + format ["<t color='#B89B6B'>Strength:</t> <t color='#FFFFFF'>%1 active / %2 total (%3 KIA)</t><br/>", _csAct, _csPax, _csKia];
        _details2 = _details2 + format ["<t color='#B89B6B'>Avg Readiness:</t> <t color='#FFFFFF'>%1</t><br/>", _csRdPct];
        _details2 = _details2 + "<br/><t color='#B89B6B' font='PuristaMedium'>Subordinate Groups</t><br/>";
        {
            if (!(_x isEqualType [])) then { continue; };
            if (!(([_x, "s1TopCategory", ""] call _getPair) isEqualTo _catName)) then { continue; };
            private _cs         = [_x, "callsign",    ""] call _getPair;
            private _grpId      = [_x, "groupId",     ""] call _getPair;
            private _pax        = [_x, "s1PaxCount",  0]  call _getPair;
            private _act        = [_x, "s1ActivePax", 0]  call _getPair;
            private _rd         = [_x, "s1AvgReadiness", 0] call _getPair;
            private _rdTxt      = format ["%1%%", round (_rd * 100)];
            private _displayName = if (_cs isEqualTo "") then { _grpId } else { _cs };
            _details2 = _details2 + format ["<t color='#DDDDDD'>- %1 | %2/%3 pax | %4</t><br/>", _displayName, _act, _pax, _rdTxt];
        } forEach _groups;

    } else { if (_isRedfBranch) then {
        // REDFALCON company or platoon branch summary
        _details2 = _details2 + format ["<t color='#B89B6B'>Node:</t> <t color='#FFFFFF'>%1</t><br/>", _selData2];
        _details2 = _details2 + "<br/><t color='#AAAAAA'>Expand node to see subordinate units.</t>";

    } else {
        // Leaf node: individual group roster
        private _selGid = _selData2;
        private _gRec = [];
        {
            if ((_x isEqualType []) && { ([_x, "groupId", ""] call _getPair) isEqualTo _selGid }) exitWith { _gRec = _x; };
        } forEach _groups;

        if ((count _gRec) isEqualTo 0) then {
            _details2 = _details2 + "<t color='#AAAAAA'>Group not found in snapshot.</t>";
        } else {
            private _cs  = [_gRec, "callsign",       ""] call _getPair;
            private _pax = [_gRec, "s1PaxCount",     0]  call _getPair;
            private _act = [_gRec, "s1ActivePax",    0]  call _getPair;
            private _kia = [_gRec, "s1KiaPax",       0]  call _getPair;
            private _rd  = [_gRec, "s1AvgReadiness", 0]  call _getPair;
            private _sub = [_gRec, "s1SubCategory",  ""] call _getPair;
            private _cat = [_gRec, "s1TopCategory",  ""] call _getPair;
            private _rdPct = format ["%1%%", round (_rd * 100)];

            _details2 = _details2 + format ["<t color='#B89B6B'>Group:</t> <t color='#FFFFFF'>%1</t><br/>", _selGid];
            _details2 = _details2 + format ["<t color='#B89B6B'>Callsign:</t> <t color='#FFFFFF'>%1</t><br/>", if (_cs isEqualTo "") then {"(none)"} else {_cs}];
            _details2 = _details2 + format ["<t color='#B89B6B'>Category:</t> <t color='#FFFFFF'>%1 / %2</t><br/>", _cat, _sub];
            _details2 = _details2 + format ["<t color='#B89B6B'>Strength:</t> <t color='#FFFFFF'>%1 active / %2 total (%3 KIA)</t><br/>", _act, _pax, _kia];
            _details2 = _details2 + format ["<t color='#B89B6B'>Readiness:</t> <t color='#FFFFFF'>%1</t><br/><br/>", _rdPct];
            _details2 = _details2 + "<t color='#B89B6B' font='PuristaMedium'>Unit Roster</t><br/>";

            private _rosterRows = [];
            {
                if (!(_x isEqualType [])) then { continue; };
                if (!(([_x, "groupId", ""] call _getPair) isEqualTo _selGid)) then { continue; };
                private _role  = [_x, "role",          "RIFLEMAN"] call _getPair;
                if (!(_role  isEqualType "")) then { _role  = "RIFLEMAN"; };
                private _state = [_x, "virtualStatus", "UNKNOWN"]  call _getPair;
                if (!(_state isEqualType "")) then { _state = "UNKNOWN"; };
                private _rdU   = [_x, "readiness",     0]          call _getPair;
                if (!(_rdU   isEqualType 0)) then { _rdU = 0; };
                private _task  = [_x, "currentTaskId", ""]         call _getPair;
                if (!(_task  isEqualType "")) then { _task = ""; };
                private _rdTxt   = format ["%1%%", round (_rdU * 100)];
                private _taskTxt = if (_task isEqualTo "") then { "None" } else { _task };
                _rosterRows pushBack format ["<t color='#DDDDDD'>- %1</t> <t color='#AAAAAA'>(%2 | %3 | Task: %4)</t>", _role, _state, _rdTxt, _taskTxt];
            } forEach _units;

            if ((count _rosterRows) isEqualTo 0) then {
                _details2 = _details2 + "<t color='#AAAAAA'>No units indexed for this group.</t>";
            } else {
                _details2 = _details2 + (_rosterRows joinString "<br/>");
            };
        };
    }; };
};

_ctrlDetails ctrlSetStructuredText parseText _details2;

// --- Update rev + selection trackers ---
uiNamespace setVariable ["ARC_console_s1LastRev",     _updatedAt];
uiNamespace setVariable ["ARC_console_s1LastSelData", _selData2];

// Toast on new snapshot
private _lastSnapshotAt = uiNamespace getVariable ["ARC_console_s1LastSnapshotAt", -1];
if (!(_lastSnapshotAt isEqualType 0)) then { _lastSnapshotAt = -1; };
if (_updatedAt > _lastSnapshotAt) then {
    uiNamespace setVariable ["ARC_console_s1LastSnapshotAt", _updatedAt];
    if (_updatedAt >= 0) then {
        ["S-1", format ["Registry sync updated (%1 BLUFOR groups).", count _groups]] call ARC_fnc_clientToast;
    } else {
        ["S-1", "Waiting for personnel snapshot broadcast."] call ARC_fnc_clientHint;
    };
};

true
