/*
    ARC_fnc_uiConsoleIntelPaint

    UI09-HF: paint the Intelligence (S2) tab.

    Changes vs UI09 baseline:
      - Consolidate "create lead request" into ONE tool with a request-type dropdown
      - Consolidate intel logging into ONE tool with dropdowns (method + category)
      - Keep admin tools and the intel feed separate + readable

    Controls:
      MainList (78011): mixed tool + feed list
      MainDetails (78012): selected item details

    S2 workflow controls (CfgDialogs.hpp):
      78050 Label Method
      78051 Combo Method
      78052 Label Category
      78053 Combo Category
      78054 Label Lead Type
      78055 Combo Lead Type

    Params:
      0: DISPLAY
      1: BOOL rebuildList

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]],
    ["_rebuild", true, [true]]
];

if (isNull _display) exitWith {false};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";

private _rxMaxItems = missionNamespace getVariable ["ARC_consoleRxMaxItems", 80];
if (!(_rxMaxItems isEqualType 0) || { _rxMaxItems < 10 }) then { _rxMaxItems = 80; };
_rxMaxItems = (_rxMaxItems min 160) max 10;

private _rxMaxText = missionNamespace getVariable ["ARC_consoleRxMaxTextLen", 220];
if (!(_rxMaxText isEqualType 0) || { _rxMaxText < 40 }) then { _rxMaxText = 220; };
_rxMaxText = (_rxMaxText min 500) max 40;

private _trimRxText = {
    params ["_v", ["_fallback", ""]];
    private _s = if (_v isEqualType "") then { trim _v } else { _fallback };
    if ((count _s) > _rxMaxText) then { _s = _s select [0, _rxMaxText]; };
    _s
};

// Own MainList while INTEL is active so cross-tab rebuild logic can detect transitions.
private _owner = uiNamespace getVariable ["ARC_console_mainListOwner", ""];
if (!(_owner isEqualType "")) then { _owner = ""; };
_owner = toUpper (trim _owner);
if (_owner isNotEqualTo "INTEL") then { _rebuild = true; };
uiNamespace setVariable ["ARC_console_mainListOwner", "INTEL"];

private _list    = _display displayCtrl 78011;
private _details = _display displayCtrl 78012;
private _b1      = _display displayCtrl 78021;
private _b2      = _display displayCtrl 78022;

// S2 workflow controls
private _lblMethod = _display displayCtrl 78050;
private _cmbMethod = _display displayCtrl 78051;
private _lblCat    = _display displayCtrl 78052;
private _cmbCat    = _display displayCtrl 78053;
private _lblLead   = _display displayCtrl 78054;
private _cmbLead   = _display displayCtrl 78055;

if (isNull _list || { isNull _details }) exitWith {false};

// ---------------------------------------------------------------------------
// S2 layout support: split the middle pane into two sub-panels (like OPS):
//   - Left: tool/feed list (MainList)
//   - Right: workflow controls (Method/Category/Lead Type)
// This prevents overlap and keeps the right details pane clean.
// ---------------------------------------------------------------------------

private _ensureS2Split = {
    params ["_display", "_listCtrl"];

    private _grpDetails = _display displayCtrl 78016; // right-pane details group
    if (isNull _grpDetails) exitWith { [0, 0, 0] };

    // Capture default list position once (for restoration by the refresh loop).
    private _k = "ARC_ui_mainListPosDefault";
    private _p0 = uiNamespace getVariable [_k, []];
    if (_p0 isEqualTo []) then {
        uiNamespace setVariable [_k, ctrlPosition _listCtrl];
        _p0 = uiNamespace getVariable [_k, ctrlPosition _listCtrl];
    };

    private _pG = ctrlPosition _grpDetails;
    private _xR = _pG # 0;         // left edge of details pane (absolute)
    private _pL = _p0;             // start from default each paint

    private _xL = _pL # 0;
    private _yL = _pL # 1;
    private _hL = _pL # 3;

    private _padOuter = 0.006;
    private _gap = 0.006;

    private _midW = (_xR - _padOuter) - _xL;
    if (_midW < 0.18) exitWith { [(_xL + (_pL # 2) + _gap), 0.10, _xR] };

    // Reserve ~32% for the workflow control column.
    private _listW = (_midW * 0.68) max 0.14;
    private _ctlW  = (_midW - _listW - _gap) max 0.10;

    // Ensure the widths don't exceed the available middle pane width.
    if ((_listW + _ctlW + _gap) > _midW) then {
        _listW = _midW - _ctlW - _gap;
    };
    if (_listW < 0.12) then { _listW = 0.12; };

    _listCtrl ctrlSetPosition [_xL, _yL, _listW, _hL];
    _listCtrl ctrlCommit 0;

    private _xCtl = _xL + _listW + _gap;
    private _wCtl = (_xR - _padOuter) - _xCtl;
    if (_wCtl < 0.10) then { _wCtl = 0.10; };

    [_xCtl, _wCtl, _xR]
};


// ---------------------------------------------------------------------------
// S2 category panels (TOOLS mode):
// Break the long mixed list into stacked sub-panels (similar to OPS frames).
// We keep MainList (78011) as a hidden master list for data + selection logic,
// and render 4 visible panel listboxes as UI-only projections.
// ---------------------------------------------------------------------------

private _ensureS2CatPanels = {
    params ["_display"];

    private _k = "ARC_s2_catPanels";
    private _panels = uiNamespace getVariable [_k, []];

    private _ok = (_panels isEqualType [] && { (count _panels) == 4 });
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
                if (uiNamespace getVariable ["ARC_s2_catPanels_suppressSel", false]) exitWith {};

                private _d = _ctrl lbData _idx;
                if (!(_d isEqualType "")) exitWith {};
                if (_d isEqualTo "" || { _d in ["HDR", "SEP"] }) exitWith {};

                private _disp = ctrlParent _ctrl;
                if (isNull _disp) exitWith {};

                private _master = _disp displayCtrl 78011;
                if (isNull _master) exitWith {};

                private _found = -1;
                for "_i" from 0 to ((lbSize _master) - 1) do {
                    if ((_master lbData _i) isEqualTo _d) exitWith { _found = _i; };
                };
                if (_found >= 0) then {
                    uiNamespace setVariable ["ARC_s2_catPanels_suppressSel", true];
                    _master lbSetCurSel _found;
                    uiNamespace setVariable ["ARC_s2_catPanels_suppressSel", false];
                };
            }];

            [_bg, _lbl, _lb]
        };

        _panels pushBack (["INTEL / LEADS"] call _mkPanel);
        _panels pushBack (["CIVSUB / MDT"] call _mkPanel);
        _panels pushBack (["ADMIN / TOOLS"] call _mkPanel);
        _panels pushBack (["INTEL FEED"] call _mkPanel);

        uiNamespace setVariable [_k, _panels];
    };

    uiNamespace getVariable [_k, _panels]
};

private _layoutS2CatPanels = {
    params ["_display", "_listMaster", "_panels"];

    private _pL = ctrlPosition _listMaster;
    private _x = _pL # 0;
    private _y = _pL # 1;
    private _w = _pL # 2;
    private _h = _pL # 3;

    private _hHdr = 0.03 * safeZoneH;
    private _probe = _display displayCtrl 78031;
    if (!isNull _probe) then {
        private _pp = ctrlPosition _probe;
        if ((_pp # 3) > 0) then { _hHdr = _pp # 3; };
    };

    private _gap = 0.006;
    private _avail = _h - (_gap * 3);
    if (_avail < 0.20) then { _avail = _h; _gap = 0; };

    // Combined Intel/Lead panel keeps the top footprint compact so CIVSUB starts higher.
    // CIVSUB receives a larger ratio for better in-pane browsing.
    private _weights = [0.14, 0.36, 0.20, 0.30];

    private _yCur = _y;
    for "_pi" from 0 to 3 do {
        private _p = _panels # _pi;
        _p params ["_bg","_lbl","_lb"];

        private _ph = _avail * (_weights # _pi);
        if (_pi == 3) then { _ph = (_y + _h) - _yCur; };

        _bg  ctrlSetPosition [_x, _yCur, _w, _ph];
        _lbl ctrlSetPosition [_x, _yCur, _w, _hHdr];

        private _hLB = (_ph - _hHdr) max 0.02;
        _lb  ctrlSetPosition [_x, _yCur + _hHdr, _w, _hLB];

        { _x ctrlCommit 0; } forEach [_bg,_lbl,_lb];

        _yCur = _yCur + _ph + _gap;
    };
};

private _renderS2CatPanelsFromMaster = {
    params ["_display", "_listMaster", "_panels"];

    { lbClear (_x # 2); } forEach _panels;

    private _map = [[
        ["INTEL / LEADS",      (_panels # 0) # 2],
        ["CIVSUB / MDT",       (_panels # 1) # 2],
        ["ADMIN / TOOLS",      (_panels # 2) # 2],
        ["INTEL FEED",         (_panels # 3) # 2]
    ]] call _hmCreate;

    private _section = "";
    for "_i" from 0 to ((lbSize _listMaster) - 1) do {
        private _d = _listMaster lbData _i;
        private _t = _listMaster lbText _i;

        if (_d in ["HDR", "SEP"]) then {
            private _sectionCandidate = toUpper (trim _t);
            if (_sectionCandidate in ["INTEL LOGGING", "LEAD REQUESTS (S2)"]) then {
                _sectionCandidate = "INTEL / LEADS";
            };

            if (!isNull (_map getOrDefault [_sectionCandidate, controlNull])) then {
                _section = _sectionCandidate;
            };
        } else {
            if (_section isEqualTo "") then { continue; };
            private _lb = _map getOrDefault [_section, controlNull];
            if (isNull _lb) then { continue; };
            if (!(_d isEqualType "")) then { continue; };
            if (_d in ["", "HDR", "SEP"]) then { continue; };

            private _idx = _lb lbAdd _t;
            _lb lbSetData [_idx, _d];
        };
    };

    private _sel = uiNamespace getVariable ["ARC_console_intelSelData", ""];
    if (!(_sel isEqualType "")) then { _sel = ""; };

    uiNamespace setVariable ["ARC_s2_catPanels_suppressSel", true];
    {
        private _lb = (_x # 2);
        private _found = -1;
        for "_j" from 0 to ((lbSize _lb) - 1) do {
            if ((_lb lbData _j) isEqualTo _sel) exitWith { _found = _j; };
        };
        _lb lbSetCurSel (if (_found >= 0) then {_found} else {-1});
    } forEach _panels;
    uiNamespace setVariable ["ARC_s2_catPanels_suppressSel", false];
};

// If the list is empty (first entry to the S2 tab), force a one-time rebuild.
if (!_rebuild) then {
    if ((lbSize _list) == 0) then { _rebuild = true; };
};

private _hideAllS2Ctrls = {
    { if (!isNull _x) then { _x ctrlShow false; }; } forEach [
        _lblMethod,_cmbMethod,
        _lblCat,_cmbCat,
        _lblLead,_cmbLead
    ];
};

// Persist combo selections across scheduled refreshes
private _storeComboSel = {
    params ["_ctrl", "_key", "_defData"];
    if (isNull _ctrl) exitWith { uiNamespace setVariable [_key, _defData]; };
    private _i = lbCurSel _ctrl;
    private _d = if (_i >= 0) then { _ctrl lbData _i } else { "" };
    if (!(_d isEqualType "")) then { _d = ""; };
    if ((trim _d) isEqualTo "") then { _d = _defData; };
    uiNamespace setVariable [_key, _d];
};

private _restoreComboSel = {
    params ["_ctrl", "_key", "_defaultData"];
    if (isNull _ctrl) exitWith {};
    private _want = uiNamespace getVariable [_key, _defaultData];
    if (!(_want isEqualType "")) then { _want = _defaultData; };
    _want = trim _want;
    if (_want isEqualTo "") then { _want = _defaultData; };

    private _n = lbSize _ctrl;
    if (_n <= 0) exitWith {};
    private _found = -1;
    for "_k" from 0 to (_n - 1) do
    {
        if ((_ctrl lbData _k) isEqualTo _want) exitWith { _found = _k; };
    };
    if (_found < 0) then { _found = 0; };
    _ctrl lbSetCurSel _found;
};

// Capture existing selections (if populated)
[_cmbMethod, "ARC_console_s2_intelMethod", "MAP"] call _storeComboSel;
[_cmbCat,    "ARC_console_s2_intelCategory", "SIGHTING"] call _storeComboSel;
[_cmbLead,   "ARC_console_s2_leadType", "RECON"] call _storeComboSel;

// Hide by default (paint below shows what it needs)
call _hideAllS2Ctrls;

// ---------------------------------------------------------------------------
// Role gating (who can see which tools)
// ---------------------------------------------------------------------------
private _isOmni = false;
private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
{ if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; }; } forEach _omniTokens;

private _isAuth = [player] call ARC_fnc_rolesIsAuthorized;
private _isS2   = [player] call ARC_fnc_rolesIsTocS2;
private _isCmd  = [player] call ARC_fnc_rolesIsTocCommand;

private _canLog     = _isAuth || _isS2 || _isCmd || _isOmni;
private _canLeadReq = _isS2 || _isCmd || _isOmni;
private _canAdmin   = _isS2 || _isCmd || _isOmni;

// Preserve selection by data string
private _selDataPrev = uiNamespace getVariable ["ARC_console_intelSelData", ""];
if (!(_selDataPrev isEqualType "")) then { _selDataPrev = ""; };

// Intel view mode
private _mode = uiNamespace getVariable ["ARC_console_intelMode", "TOOLS"];

private _civCtxTarget = uiNamespace getVariable ["ARC_civsubInteract_target", objNull];
private _inCivCtx = !(isNull _civCtxTarget);


// Apply the S2 split layout each paint. This keeps the workflow controls inside the middle pane
// and prevents them from colliding with the right details pane.
private _s2Split = [_display, _list] call _ensureS2Split;
private _xCtlBase = _s2Split # 0;
private _wCtlBase = _s2Split # 1;
private _xRBase   = _s2Split # 2;
if (!(_mode isEqualType "")) then { _mode = "TOOLS"; };
_mode = toUpper (trim _mode);


// ---------------------------------------------------------------------------
// Build list
// ---------------------------------------------------------------------------
if (_rebuild) then
{
    lbClear _list;

    private _addHdr = {
        params ["_t"];
        private _i = _list lbAdd format ["%1", _t];
        _list lbSetData [_i, "HDR"];
        _list lbSetColor [_i, [0.85,0.85,0.85,1]];
        _list lbSetSelectColor [_i, [0.85,0.85,0.85,1]];
        _i
    };

    private _addTool = {
        params ["_label", "_data"];
        private _i = _list lbAdd _label;
        _list lbSetData [_i, _data];
        _i
    };

    if (_mode isEqualTo "CENSUS") then
    {
        ["CIVSUB CENSUS"] call _addHdr;
        ["< BACK (S2 Tools)", "CIV_CENSUS_BACK"] call _addTool;

        // ── World-time header ─────────────────────────────────────────────
        // Show current mission date, local time, and day-phase cultural note.
        private _wtSnap = missionNamespace getVariable ["ARC_worldTimeSnap", []];
        if (_wtSnap isEqualType [] && { (count _wtSnap) >= 3 }) then
        {
            private _dateArr  = _wtSnap select 0;
            private _daytime  = _wtSnap select 1;
            private _phase    = _wtSnap select 2;
            if (!(_phase isEqualType "")) then { _phase = "UNKNOWN"; };
            _phase = toUpper _phase;

            private _dateStr = "---";
            if (_dateArr isEqualType [] && { (count _dateArr) >= 3 }) then
            {
                _dateStr = format ["%1-%2-%3", _dateArr select 0, _dateArr select 1, _dateArr select 2];
            };
            private _timeHH = floor _daytime;
            private _timeMM = round ((_daytime - _timeHH) * 60);
            private _timeStr = format ["%1%2:%3%4L",
                if (_timeHH < 10) then {"0"} else {""},
                _timeHH,
                if (_timeMM < 10) then {"0"} else {""},
                _timeMM
            ];

            // Central Asian cultural activity note by phase
            private _phaseNote = switch (_phase) do {
                case "NIGHT":   { "Night watch. Markets closed. Reduced movement." };
                case "MORNING": { "Fajr (morning prayer). Bazaar opening. Activity increasing." };
                case "WORK":    { "Market hours. Normal civilian movement. Midday prayer (Dhuhr)." };
                case "EVENING": { "Asr (afternoon prayer). Bazaar closing. Maghrib at sundown." };
                default         { "Phase unknown. Observe local pattern of life." };
            };

            [format ["TIME: %1  DATE: %2  PHASE: %3", _timeStr, _dateStr, _phase], "HDR"] call _addTool;
            [format ["  %1", _phaseNote], "HDR"] call _addTool;

            // Active cultural events from worldtime events subsystem
            private _wtEvents = missionNamespace getVariable ["ARC_worldTimeEvents", []];
            if (_wtEvents isEqualType [] && { (count _wtEvents) > 0 }) then
            {
                [format ["  Active: %1", _wtEvents joinString " | "], "HDR"] call _addTool;
            };
        };
        // ── end world-time header ─────────────────────────────────────────

        ["DISTRICTS"] call _addHdr;

        if !(missionNamespace getVariable ["civsub_v1_enabled", false]) then
        {
            ["(CIVSUB disabled)", "HDR"] call _addTool;
        }
        else
        {
            private _prefix = "civsub_v1_district_pub_";
            private _ids = [];

            {
                private _n = _x;
                if ((_n find _prefix) == 0) then
                {
                    _ids pushBack (_n select [count _prefix]);
                };
            } forEach (allVariables missionNamespace);

            _ids sort true;

            if ((count _ids) == 0) then
            {
                ["(No district snapshots yet)", "HDR"] call _addTool;
            }
            else
            {
                {
                    private _did = _x;

                    private _pub = missionNamespace getVariable [format ["civsub_v1_district_pub_%1", _did], []];
                    if (!(_pub isEqualType [])) then { _pub = []; };

                    private _W = 45;
                    private _R = 55;
                    private _G = 35;

                    private _kia = 0;
                    private _wia = 0;
                    private _hits = 0;
                    private _detI = 0;
                    private _detH = 0;
                    private _aid = 0;
                    private _ts = 0;

                    if ((count _pub) > 0) then
                    {
                        private _ph = [_pub] call _hmCreate;
                        _W = _ph getOrDefault ["W", _W];
                        _R = _ph getOrDefault ["R", _R];
                        _G = _ph getOrDefault ["G", _G];

                        _kia = _ph getOrDefault ["civ_cas_kia", 0];
                        _wia = _ph getOrDefault ["civ_cas_wia", 0];
                        _hits = _ph getOrDefault ["crime_db_hits", 0];
                        _detI = _ph getOrDefault ["detentions_initiated", 0];
                        _detH = _ph getOrDefault ["detentions_handed_off", 0];
                        _aid = _ph getOrDefault ["aid_events", 0];
                        _ts = _ph getOrDefault ["ts", 0];
                    };

                    // Derived scores (locked v1 math, using W/R/G from pub snapshot)
                    private _Scoop = (0.55 * _W) + (0.35 * _G) - (0.70 * _R);
                    private _Sthreat = (1.00 * _R) - (0.35 * _W) - (0.25 * _G);

                    if (_Scoop < 0) then { _Scoop = 0; };
                    if (_Scoop > 100) then { _Scoop = 100; };
                    if (_Sthreat < 0) then { _Sthreat = 0; };
                    if (_Sthreat > 100) then { _Sthreat = 100; };

                    private _label = format [
                        "%1  Pop:%2  Alive:%3  W/R/G:%4/%5/%6  K/W:%7/%8  Coop:%9  Threat:%10",
                        _did, "n/a", "n/a",
                        round _W, round _R, round _G,
                        _kia, _wia,
                        round _Scoop, round _Sthreat
                    ];

                    // R/A/G status badge (prepended to label)
                    private _ragBadge = "A";   // Amber default
                    private _ragColor = [1.0, 0.87, 0.50, 1]; // Amber
                    if (_Scoop >= 55 && { _Sthreat <= 35 }) then {
                        _ragBadge = "G"; _ragColor = [0.65, 0.90, 0.65, 1]; // Green
                    } else {
                        if (_Sthreat >= 65 || { _Scoop <= 30 }) then {
                            _ragBadge = "R"; _ragColor = [1.0, 0.52, 0.40, 1]; // Red
                        };
                    };
                    _label = format ["[%1] %2", _ragBadge, _label];

                    private _i = _list lbAdd _label;
                    _list lbSetData [_i, format ["CIV_CENSUS_DID|%1", _did]];

                    // Apply R/A/G color to the row
                    _list lbSetColor [_i, _ragColor];
                } forEach _ids;
            };
        };
    }
    else
    {
        // Intel logging + lead requests (consolidated into one panel/menu)
        ["INTEL / LEADS"] call _addHdr;
        if (_canLog) then
        {
            ["Log Intel / Sighting", "INTEL_LOG"] call _addTool;
        }
        else
        {
            ["(Access denied)", "HDR"] call _addTool;
        };

        if (_canLeadReq) then
        {
            ["Create Lead Request", "LEAD_REQ"] call _addTool;
        }
        else
        {
            ["(S2/TOC only)", "HDR"] call _addTool;
        };

        // CIVSUB MDT + contact context tools
        ["CIVSUB / MDT"] call _addHdr;
        ["CIVSUB Census (District Stats)", "CIV_CENSUS_OPEN"] call _addTool;
        ["AO Threat Summary", "CIV_THREAT_SUMMARY"] call _addTool;

        // S2 analytical screens (Government + OPFOR)
        ["S2 / GOVERNMENT SITUATION"] call _addHdr;
        ["Government Status", "GOV_STATUS"] call _addTool;
        ["OPFOR Situation (Known Intel)", "OPFOR_STATUS"] call _addTool;
        ["AO Thread (Events + Activity)", "AO_THREAD"] call _addTool;

        if (_inCivCtx) then
        {
            ["CIVSUB INTERACTION (ACTIVE)", "HDR"] call _addTool;
            ["Check ID", "CIV_CONTACT_CHECK_ID"] call _addTool;
            ["Background Check", "CIV_CONTACT_BACKGROUND"] call _addTool;
            ["Give Food", "CIV_CONTACT_GIVE_FOOD"] call _addTool;
            ["Give Water", "CIV_CONTACT_GIVE_WATER"] call _addTool;

            private _detained = false;
            private _snap = uiNamespace getVariable ["ARC_civsubInteract_snapshot", createHashMap];
            if (_snap isEqualType createHashMap) then { _detained = _snap getOrDefault ["detained", false]; };

            if (_detained) then {
                ["Release", "CIV_CONTACT_RELEASE"] call _addTool;
                ["Handoff to SHERIFF", "CIV_CONTACT_HANDOFF"] call _addTool;
            } else {
                ["Detain", "CIV_CONTACT_DETAIN"] call _addTool;
            };

            ["Ask: Where do you live?", "CIV_CONTACT_QUESTION|Q_LIVE"] call _addTool;
            ["Ask: Where do you work?", "CIV_CONTACT_QUESTION|Q_WORK"] call _addTool;
            ["Ask: Seen any IEDs?", "CIV_CONTACT_QUESTION|Q_IEDS"] call _addTool;
            ["Ask: Seen insurgent activity?", "CIV_CONTACT_QUESTION|Q_INS"] call _addTool;
            ["Ask: Opinion of us?", "CIV_CONTACT_QUESTION|Q_OP_US"] call _addTool;
            ["Ask: Area opinion of us?", "CIV_CONTACT_QUESTION|Q_OP_AREA"] call _addTool;
            ["End Interaction Mode", "CIV_CONTACT_END"] call _addTool;
        }
        else
        {
            ["(No active civ interaction target)", "HDR"] call _addTool;
        };

        // Admin/tools
        ["ADMIN / TOOLS"] call _addHdr;
        if (_canAdmin) then
        {
            ["Refresh Intel/Lead Pool", "REFRESH_INTEL"] call _addTool;
            ["Show Lead Pool (Local)",  "S2_SHOW_LEADS"] call _addTool;
            ["Show Threads (Local)",    "S2_SHOW_THREADS"] call _addTool;
            ["Show Latest Intel (Local)","S2_SHOW_INTEL"] call _addTool;
        }
        else
        {
            ["(S2/TOC only)", "HDR"] call _addTool;
        };

        // Intel feed
        ["INTEL FEED"] call _addHdr;

        private _intelLog = missionNamespace getVariable ["ARC_pub_intelLog", []];
        if (!(_intelLog isEqualType [])) then { _intelLog = []; };
        if ((count _intelLog) > _rxMaxItems) then { _intelLog = _intelLog select [((count _intelLog) - _rxMaxItems) max 0, _rxMaxItems]; };

        // Show last 25
        private _start = ((count _intelLog) - 25) max 0;
        for "_i" from _start to ((count _intelLog) - 1) do
        {
            private _e = _intelLog # _i;
            if (!(_e isEqualType [] && { (count _e) >= 6 })) then { continue; };
            _e params ["_id", "_t", "_cat", "_sum", "_p", "_meta"];
            _sum = [_sum, ""] call _trimRxText;
            private _g = if (_p isEqualType [] && { (count _p) >= 2 }) then { mapGridPosition _p } else { "" };
            private _label = format ["[%1] %2%3", toUpper _cat, _sum, if (_g isEqualTo "") then {""} else {format [" @ %1", _g]}];
            private _idx = _list lbAdd _label;
            _list lbSetData [_idx, format ["FEED|%1", _id]];
        };
    };

    // Restore selection (or pick first actionable row by default)
    if (_selDataPrev isNotEqualTo "") then
    {
        private _found = -1;
        for "_j" from 0 to ((lbSize _list) - 1) do
        {
            if ((_list lbData _j) isEqualTo _selDataPrev) exitWith { _found = _j; };
        };

        if (_found >= 0) then { _list lbSetCurSel _found; }
        else
        {
            private _def = 0;
            if (_mode isEqualTo "CENSUS") then
            {
                _def = -1;
                for "_k" from 0 to ((lbSize _list) - 1) do
                {
                    private _d = _list lbData _k;
                    if ((_d find "CIV_CENSUS_DID|") == 0) exitWith { _def = _k; };
                };
                if (_def < 0) then { _def = (lbSize _list) min 1; };
                if (_def < 0) then { _def = 0; };
            }
            else
            {
                _def = if ((lbSize _list) > 1) then { 1 } else { 0 };
            };
            _list lbSetCurSel _def;
        };
    }
    else
    {
        private _def = 0;
        if (_mode isEqualTo "CENSUS") then
        {
            _def = -1;
            for "_k" from 0 to ((lbSize _list) - 1) do
            {
                private _d = _list lbData _k;
                if ((_d find "CIV_CENSUS_DID|") == 0) exitWith { _def = _k; };
            };
            if (_def < 0) then { _def = 1; };
            if (_def < 0) then { _def = 0; };
        }
        else
        {
            _def = if ((lbSize _list) > 1) then { 1 } else { 0 };
        };
        _list lbSetCurSel _def;
    };
};


// ---------------------------------------------------------------------------
// Selection handling
// ---------------------------------------------------------------------------
private _sel = lbCurSel _list;
private _data = if (_sel >= 0) then { _list lbData _sel } else { "" };
if (!(_data isEqualType "")) then { _data = ""; };
uiNamespace setVariable ["ARC_console_intelSelData", _data];

private _txt = "";

private _appendCivsubResult = {
    params ["_txtIn", "_expectType"];

    private _txtOut = _txtIn;
    private _typeExpect = _expectType;
    if !(_typeExpect isEqualType "") then { _typeExpect = ""; };
    _typeExpect = toUpper (trim _typeExpect);

    private _rs = uiNamespace getVariable ["ARC_console_civsubLastResult", createHashMap];
    if !(_rs isEqualType createHashMap) exitWith { _txtOut };

    private _type = _rs getOrDefault ["type", ""];
    if !(_type isEqualType "") then { _type = ""; };
    _type = toUpper (trim _type);
    if (_type isEqualTo "" || {_typeExpect isEqualTo ""} || {_type isNotEqualTo _typeExpect}) exitWith { _txtOut };

    private _html = _rs getOrDefault ["html", ""];
    if !(_html isEqualType "") then { _html = ""; };

    private _ok = _rs getOrDefault ["ok", false];
    if !(_ok isEqualType true) then { _ok = false; };

    private _updatedAt = _rs getOrDefault ["updatedAtText", "--:--:--"];
    if !(_updatedAt isEqualType "") then { _updatedAt = "--:--:--"; };

    private _statusLbl = if (_ok) then { "COMPLETE" } else { "WARNING" };
    private _statusColor = if (_ok) then { "#9FD39F" } else { "#FFB0B0" };

    private _resultBlock = format [
        "<br/><br/><t size='0.96' font='PuristaMedium' color='#CFE8FF'>Latest Result</t><br/>" +
        "<t size='0.85' color='#AAAAAA'>Last updated:</t> <t size='0.85' color='#DDDDDD'>%1</t>  " +
        "<t size='0.85' color='#AAAAAA'>Status:</t> <t size='0.85' color='%2'>%3</t>",
        _updatedAt,
        _statusColor,
        _statusLbl
    ];

    if (!(_html isEqualTo "")) then {
        _resultBlock = _resultBlock + format ["<br/><br/>%1", _html];
    };

    _txtOut + _resultBlock
};

// Default action button state
if (!isNull _b1) then { _b1 ctrlSetText "EXECUTE"; _b1 ctrlEnable false; };

// Tool descriptions / intel details
if (_mode isEqualTo "CENSUS") then
{
if (_data in ["HDR", "SEP"]) then
{
    _txt = "<t size='1.05'>Select a district below.</t><br/><br/>" +
           "This view reads published district snapshots (refreshed each CIVSUB tick).<br/><br/>" +
           "EXECUTE: open map at district center.";
}
else
{
    private _parts = _data splitString "|";
    private _kind = if ((count _parts) > 0) then { _parts # 0 } else { "" };
    private _arg  = if ((count _parts) > 1) then { _parts # 1 } else { "" };

    switch (_kind) do
    {
        case "CIV_CENSUS_BACK":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>Back</t><br/><br/>Return to S2 tools.";
            if (!isNull _b1) then { _b1 ctrlEnable true; _b1 ctrlSetText "BACK"; };
        };

        case "CIV_CENSUS_DID":
        {
            private _did = trim _arg;
            if (_did isEqualTo "") exitWith { _txt = "<t color='#FFB0B0'>No district selected.</t>"; };

            if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith
            {
                _txt = "<t color='#FFB0B0'>CIVSUB is disabled.</t>";
            };

            private _pop = -1;
            private _centroid = [];
            private _rad = 0;

            private _pub = missionNamespace getVariable [format ["civsub_v1_district_pub_%1", _did], []];
            if (!(_pub isEqualType [])) then { _pub = []; };
            private _ph = if ((count _pub) > 0) then { [_pub] call _hmCreate } else { createHashMap };

            private _W = _ph getOrDefault ["W", 45];
            private _R = _ph getOrDefault ["R", 55];
            private _G = _ph getOrDefault ["G", 35];

            private _kia = _ph getOrDefault ["civ_cas_kia", 0];
            private _wia = _ph getOrDefault ["civ_cas_wia", 0];
            private _hits = _ph getOrDefault ["crime_db_hits", 0];
            private _detI = _ph getOrDefault ["detentions_initiated", 0];
            private _detH = _ph getOrDefault ["detentions_handed_off", 0];
            private _aid  = _ph getOrDefault ["aid_events", 0];
            private _ts   = _ph getOrDefault ["ts", 0];

            private _Scoop = (0.55 * _W) + (0.35 * _G) - (0.70 * _R);
            private _Sthreat = (1.00 * _R) - (0.35 * _W) - (0.25 * _G);
            if (_Scoop < 0) then { _Scoop = 0; };
            if (_Scoop > 100) then { _Scoop = 100; };
            if (_Sthreat < 0) then { _Sthreat = 0; };
            if (_Sthreat > 100) then { _Sthreat = 100; };

            private _aliveEst = -1;
            private _popS = "n/a";
            private _aliveS = "n/a";
            if (_pop >= 0) then
            {
                _aliveEst = (_pop - _kia) max 0;
                _popS = str _pop;
                _aliveS = str _aliveEst;
            };

            private _grid = "";
            if (_centroid isEqualType [] && { (count _centroid) >= 2 }) then { _grid = mapGridPosition _centroid; };

            // -------------------------------------------------------------------
            // Key settlements (player-readable)
            // -------------------------------------------------------------------
            private _settByDid = [[
                ["D01", ["Farabad"]],
                ["D02", ["Lashgar Kuh", "Hamza", "Fort Kelati", "Shirazan"]],
                ["D03", ["Shahruk"]],
                ["D04", []],
                ["D05", ["Kandah"]],
                ["D06", ["Pashtat"]],
                ["D07", ["Naseri"]],
                ["D08", ["Karkanak", "Karkanak Prison"]],
                ["D09", ["Al-Nazara"]],
                ["D10", ["Ali Kala"]],
                ["D11", ["Kaftar Kar"]],
                ["D12", []],
                ["D13", []],
                ["D14", ["Lashgar Kuh", "Camp Bulwark", "Fort Kelati", "Hamza", "Shirazan", "Port Farabad"]],
                ["D15", []],
                ["D16", []],
                ["D17", []],
                ["D18", []],
                ["D19", []],
                ["D20", []]
            ]] call _hmCreate;

            private _sett = _settByDid getOrDefault [_did, []];
            private _settLine = if ((count _sett) > 0) then { _sett joinString "; " } else { "None (rural / dispersed)" };

// -------------------------------------------------------------------
            // Player-readable interpretation (heuristics; does not change CIVSUB math)
            // -------------------------------------------------------------------
            private _coopLbl = "Low";
            if (_Scoop >= 65) then { _coopLbl = "High"; } else { if (_Scoop >= 40) then { _coopLbl = "Medium"; }; };

            private _threatLbl = "Low";
            if (_Sthreat >= 65) then { _threatLbl = "High"; } else { if (_Sthreat >= 35) then { _threatLbl = "Medium"; }; };

            private _harmRate = 0;
            if (_pop > 0) then { _harmRate = (_kia + (0.5 * _wia)) / _pop; };
            private _harmLbl = "Low";
            if (_harmRate >= 0.020) then { _harmLbl = "Heavy"; } else { if (_harmRate >= 0.008) then { _harmLbl = "Moderate"; }; };

            private _env = "Mixed";
            private _assess = "Mixed. Cooperation varies. Intimidation present.";
            private _posture = "Engagement plus checkpoints; prioritize wanted detentions and avoid wrongful detains.";

            if ((_coopLbl isEqualTo "High") && { _threatLbl isEqualTo "Low" }) then
            {
                _env = "Stable";
                _assess = "Stable. Locals generally cooperative. Low intimidation.";
                _posture = "Engagement first; light checkpoint presence. Use cooperative ID checks.";
            }
            else
            {
                if ((_coopLbl isEqualTo "Low") && { _threatLbl isEqualTo "High" }) then
                {
                    _env = "Contested";
                    _assess = "Contested. Low cooperation. High intimidation risk.";
                    _posture = "Security first. Increase checkpoints/patrol presence. Verify before detaining.";
                };
            };

            private _what = "";
            _what = _what + "• Wanted detentions improve trust; wrongful detentions reduce trust quickly.<br/>";
            if (_threatLbl isEqualTo "High") then { _what = _what + "• Expect intimidation and rumor noise; fewer voluntary tips.<br/>"; };
            if (_coopLbl isEqualTo "Low") then { _what = _what + "• Expect refusals; use cooperative 'Show Papers' before escalation.<br/>"; };
            if (_harmLbl in ["Moderate","Heavy"]) then { _what = _what + "• Civilian harm is visible; reduce collateral damage and provide aid when possible.<br/>"; };
            if (_hits > 0) then { _what = _what + "• Crime DB activity present; checkpoints/MDT are likely to produce hits.<br/>"; };

            _txt =
                format ["<t size='1.25' font='PuristaMedium'>CIVSUB Census: %1</t><br/><br/>", _did] +
                "<t size='1.05' font='PuristaMedium'>District Readout</t><br/><br/>" +
                format ["<t color='#AAAAAA'>Environment:</t> %1<br/>", _env] +
                format ["<t color='#AAAAAA'>Assessment:</t> %1<br/>", _assess] +
                format ["<t color='#AAAAAA'>Key settlements:</t> %1<br/>", _settLine] +
                format ["<t color='#AAAAAA'>Recommended posture:</t> %1<br/><br/>", _posture] +
                format ["<t color='#AAAAAA'>Cooperation:</t> %1 (%2)   <t color='#AAAAAA'>Threat:</t> %3 (%4)   <t color='#AAAAAA'>Civilian harm:</t> %5 (%6)<br/><br/>",
                        (_Scoop toFixed 1), _coopLbl,
                        (_Sthreat toFixed 1), _threatLbl,
                        ((100 * _harmRate) toFixed 2) + "%", _harmLbl
                ] +
                "<t color='#AAAAAA'>What this means</t><br/>" + _what +
                "<br/><br/><t size='1.05' font='PuristaMedium'>Raw Metrics</t><br/><br/>" +
                format ["<t color='#AAAAAA'>Centroid:</t> %1  <t color='#AAAAAA'>Grid:</t> %2  <t color='#AAAAAA'>Radius:</t> %3m<br/>",
                        if (_centroid isEqualType [] && { (count _centroid) >= 2 }) then { format ['[%1,%2]', (_centroid#0) toFixed 0, (_centroid#1) toFixed 0] } else { "(n/a)" },
                        if (_grid isEqualTo "") then {"(n/a)"} else {_grid},
                        _rad
                ] +
                "<br/>" +
                format ["<t color='#AAAAAA'>Population:</t> %1  <t color='#AAAAAA'>Alive est:</t> %2<br/>", _popS, _aliveS] +
                "<br/>" +
                format ["<t color='#AAAAAA'>W / R / G:</t> %1 / %2 / %3<br/>", (round _W), (round _R), (round _G)] +
                "<br/>" +
                format ["<t color='#AAAAAA'>S_COOP:</t> %1  <t color='#AAAAAA'>S_THREAT:</t> %2<br/>", (_Scoop toFixed 1), (_Sthreat toFixed 1)] +
                "<br/>" +
                format ["<t color='#AAAAAA'>CIV KIA:</t> %1  <t color='#AAAAAA'>CIV WIA:</t> %2<br/>", _kia, _wia] +
                "<br/>" +
                format ["<t color='#AAAAAA'>Crime DB hits:</t> %1<br/>", _hits] +
                "<br/>" +
                format ["<t color='#AAAAAA'>Detentions:</t> %1 initiated, %2 handed off<br/>", _detI, _detH] +
                "<br/>" +
                format ["<t color='#AAAAAA'>Aid events:</t> %1<br/>", _aid] +
                (if (_ts > 0) then { format ["<br/><t color='#666666'>Last update ts:</t> %1", _ts] } else { "<br/><t color='#666666'>Last update:</t> (not published yet)" }) +
                "<br/><br/><t color='#BBBBBB'>EXECUTE opens the map at the district center.</t>";


            if (!isNull _b1) then { _b1 ctrlEnable true; _b1 ctrlSetText "OPEN MAP"; };
        };

        default
        {
            _txt = "<t color='#BBBBBB'>Select a district.</t>";
        };
    };
};

}
else
{
if (_data in ["HDR", "SEP"]) then
{
    _txt = "<t size='1.05'>Select a tool or an intel log entry.</t>";
}
else
{
    private _parts = _data splitString "|";
    private _kind = if ((count _parts) > 0) then { _parts # 0 } else { "" };
    private _arg  = if ((count _parts) > 1) then { _parts # 1 } else { "" };

    switch (_kind) do
    {
        case "INTEL_LOG":
        {
            // Ensure combos are populated + restore selection
            if (!isNull _cmbMethod && { (lbSize _cmbMethod) isEqualTo 0 }) then
            {
                private _i0 = _cmbMethod lbAdd "Map Click";      _cmbMethod lbSetData [_i0, "MAP"];
                private _i1 = _cmbMethod lbAdd "Cursor Target";  _cmbMethod lbSetData [_i1, "CURSOR"];
            };
            if (!isNull _cmbCat && { (lbSize _cmbCat) isEqualTo 0 }) then
            {
                private _a0 = _cmbCat lbAdd "Sighting"; _cmbCat lbSetData [_a0, "SIGHTING"];
                private _a1 = _cmbCat lbAdd "HUMINT";   _cmbCat lbSetData [_a1, "HUMINT"];
                private _a2 = _cmbCat lbAdd "ISR";      _cmbCat lbSetData [_a2, "ISR"];
                private _a3 = _cmbCat lbAdd "SIGINT";   _cmbCat lbSetData [_a3, "SIGINT"];
                private _a4 = _cmbCat lbAdd "Other";    _cmbCat lbSetData [_a4, "OTHER"];
            };

            [_cmbMethod, "ARC_console_s2_intelMethod", "MAP"] call _restoreComboSel;
            [_cmbCat,    "ARC_console_s2_intelCategory", "SIGHTING"] call _restoreComboSel;

            // Show controls
            { if (!isNull _x) then { _x ctrlShow true; }; } forEach [_lblMethod,_cmbMethod,_lblCat,_cmbCat];
            // Layout: stack combos under labels and constrain to the LEFT of the details pane.
            // This prevents overlap with the right-pane details and eliminates horizontal scroll regression.
            private _grpDetails = _display displayCtrl 78016; // right-pane details group
            if (!isNull _grpDetails) then {
                private _pG = ctrlPosition _grpDetails;
                private _xR = _pG # 0; // left edge of details pane

                                // Control column anchor comes from the S2 split layout.
                private _xL = _xCtlBase;
                private _wCtl = _wCtlBase;

                // Fallback if split data is unavailable.
                if (_wCtl <= 0) then {
                    private _pList = ctrlPosition _list;
                    private _xL2 = (_pList # 0) + (_pList # 2) + 0.006;
                    private _padX = 0.004;
                    _wCtl = (_xR - _padX) - _xL2;
                    _xL = _xL2;
                };
                if (_wCtl < 0.10) then { _wCtl = 0.10; };

                private _pLM = ctrlPosition _lblMethod;
                private _pCM = ctrlPosition _cmbMethod;
                private _hLbl = (_pLM # 3) max 0.02;
                private _hCmb = (_pCM # 3) max 0.03;

                private _y0 = _pLM # 1;
                private _gap = 0.002;
                private _gapBlk = 0.006;

                _lblMethod ctrlSetPosition [_xL, _y0, _wCtl, _hLbl];
                _cmbMethod ctrlSetPosition [_xL, _y0 + _hLbl + _gap, _wCtl, _hCmb];

                private _y1 = _y0 + _hLbl + _hCmb + _gapBlk;
                _lblCat ctrlSetPosition [_xL, _y1, _wCtl, _hLbl];
                _cmbCat ctrlSetPosition [_xL, _y1 + _hLbl + _gap, _wCtl, _hCmb];

                { if (!isNull _x) then { _x ctrlCommit 0; }; } forEach [_lblMethod,_cmbMethod,_lblCat,_cmbCat];
            };


	            _txt = "<br/><br/><br/><t size='1.1' font='PuristaMedium'>Log Intel / Sighting</t><br/><br/>" +
                   "Use the drop-downs above to select the reporting method and category.<br/><br/>" +
                   "Map Click: opens the map, click a point, then submit the report.<br/>" +
                   "Cursor Target: logs a sighting at cursor target (best effort).";

            if (!isNull _b1) then { _b1 ctrlEnable _canLog; _b1 ctrlSetText "EXECUTE"; };
        };

        case "LEAD_REQ":
        {
            if (!isNull _cmbLead && { (lbSize _cmbLead) isEqualTo 0 }) then
            {
                private _l0 = _cmbLead lbAdd "Recon";      _cmbLead lbSetData [_l0, "RECON"];
                private _l1 = _cmbLead lbAdd "Patrol";     _cmbLead lbSetData [_l1, "PATROL"];
                private _l2 = _cmbLead lbAdd "Checkpoint"; _cmbLead lbSetData [_l2, "CHECKPOINT"];
                private _l3 = _cmbLead lbAdd "Civil";      _cmbLead lbSetData [_l3, "CIVIL"];
                private _l4 = _cmbLead lbAdd "IED";        _cmbLead lbSetData [_l4, "IED"];
            };

            [_cmbLead, "ARC_console_s2_leadType", "RECON"] call _restoreComboSel;

            { if (!isNull _x) then { _x ctrlShow true; }; } forEach [_lblLead,_cmbLead];
            // Layout: stack lead request dropdown under its label and constrain left of details pane.
            private _grpDetails = _display displayCtrl 78016;
            if (!isNull _grpDetails) then {
                private _pG = ctrlPosition _grpDetails;
                private _xR = _pG # 0;

                                // Control column anchor comes from the S2 split layout.
                private _xL = _xCtlBase;
                private _wCtl = _wCtlBase;

                // Fallback if split data is unavailable.
                if (_wCtl <= 0) then {
                    private _pList = ctrlPosition _list;
                    private _xL2 = (_pList # 0) + (_pList # 2) + 0.006;
                    private _padX = 0.004;
                    _wCtl = (_xR - _padX) - _xL2;
                    _xL = _xL2;
                };
                if (_wCtl < 0.10) then { _wCtl = 0.10; };

                private _pLL = ctrlPosition _lblLead;
                private _pCL = ctrlPosition _cmbLead;
                private _hLbl = (_pLL # 3) max 0.02;
                private _hCmb = (_pCL # 3) max 0.03;

                private _y0 = _pLL # 1;
                private _gap = 0.002;

                _lblLead ctrlSetPosition [_xL, _y0, _wCtl, _hLbl];
                _cmbLead ctrlSetPosition [_xL, _y0 + _hLbl + _gap, _wCtl, _hCmb];

                { if (!isNull _x) then { _x ctrlCommit 0; }; } forEach [_lblLead,_cmbLead];
            };


	            _txt = "<br/><br/><br/><t size='1.1' font='PuristaMedium'>Create Lead Request</t><br/><br/>" +
                   "Select a request type above, then EXECUTE to open the map and place a request marker.<br/><br/>" +
                   "The request enters the TOC queue for approval (S3/Command).";

            if (!isNull _b1) then { _b1 ctrlEnable _canLeadReq; _b1 ctrlSetText "EXECUTE"; };
        };

        case "REFRESH_INTEL":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>Refresh Intel/Lead Pool</t><br/><br/>" +
                   "Requests a refresh of S2 lead pools / intel state (server authoritative).";
            if (!isNull _b1) then { _b1 ctrlEnable _canAdmin; _b1 ctrlSetText "EXECUTE"; };
        };
        case "S2_SHOW_LEADS":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>Show Lead Pool (Local)</t><br/><br/>" +
                   "Shows a local snapshot of current leads for quick debugging.";
            if (!isNull _b1) then { _b1 ctrlEnable _canAdmin; _b1 ctrlSetText "EXECUTE"; };
        };
        case "S2_SHOW_THREADS":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>Show Threads (Local)</t><br/><br/>" +
                   "Shows current intel threads / link graph summary (debug helper).";
            if (!isNull _b1) then { _b1 ctrlEnable _canAdmin; _b1 ctrlSetText "EXECUTE"; };
        };
        case "S2_SHOW_INTEL":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>Show Latest Intel (Local)</t><br/><br/>" +
                   "Shows the latest intel log entry (debug helper).";
            if (!isNull _b1) then { _b1 ctrlEnable _canAdmin; _b1 ctrlSetText "EXECUTE"; };
        };

        case "FEED":
        {
            private _id = _arg;
            private _intelLog = missionNamespace getVariable ["ARC_pub_intelLog", []];
            if (!(_intelLog isEqualType [])) then { _intelLog = []; };
            if ((count _intelLog) > _rxMaxItems) then { _intelLog = _intelLog select [((count _intelLog) - _rxMaxItems) max 0, _rxMaxItems]; };

            private _match = [];
            {
                if (_x isEqualType [] && { (count _x) >= 6 } && { (_x # 0) isEqualTo _id }) exitWith { _match = _x; };
            } forEach _intelLog;

            if (_match isEqualTo []) then
            {
                _txt = format ["<t color='#FFB0B0'>Intel entry not found.</t><br/><t color='#AAAAAA'>ID:</t> %1", _id];
            }
            else
            {
                _match params ["_iid", "_t", "_cat", "_sum", "_p", "_meta"];
                _sum = [_sum, ""] call _trimRxText;
                private _g = if (_p isEqualType [] && { (count _p) >= 2 }) then { mapGridPosition _p } else { "" };

                private _detailsTxt = "";
                if (_meta isEqualType [] && { (count _meta) > 0 }) then
                {
                    {
                        if (_x isEqualType [] && { (count _x) >= 2 }) then
                        {
                            private _k = _x # 0;
                            private _v = _x # 1;
                            _k = [_k, ""] call _trimRxText;
                            if !(_v isEqualType "") then { _v = str _v; };
                            _v = [_v, ""] call _trimRxText;
                            _detailsTxt = _detailsTxt + format ["<br/><t color='#AAAAAA'>%1:</t> %2", _k, _v];
                        };
                    } forEach _meta;
                };

                _txt = format [
                    "<t size='1.1' font='PuristaMedium'>Intel Log Entry</t><br/><br/>" +
                    "<t color='#AAAAAA'>ID:</t> %1<br/>" +
                    "<t color='#AAAAAA'>Category:</t> %2<br/>" +
                    "<t color='#AAAAAA'>Grid:</t> %3<br/><br/>" +
                    "<t color='#DDDDDD'>%4</t>%5",
                    _iid,
                    toUpper _cat,
                    if (_g isEqualTo "") then {"(n/a)"} else {_g},
                    _sum,
                    _detailsTxt
                ];
            };

            if (!isNull _b1) then { _b1 ctrlEnable true; _b1 ctrlSetText "OPEN MAP"; };
        };

        case "CIV_CONTACT_CHECK_ID":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>CIVSUB: Check ID</t><br/><br/>" +
                   "Runs identity verification for the active civilian interaction target.<br/>" +
                   "Result renders in-console via CIVSUB response handlers.";

            private _idCardHtml = uiNamespace getVariable ["ARC_civsubInteract_idCardHtml", ""];
            if (_idCardHtml isEqualType "" && {!(_idCardHtml isEqualTo "")}) then {
                _txt = _txt + "<br/><br/>" + _idCardHtml;
            };

            _txt = [_txt, "CHECK_ID"] call _appendCivsubResult;
            if (!isNull _b1) then { _b1 ctrlEnable _inCivCtx; _b1 ctrlSetText "EXECUTE"; };
        };

        case "CIV_CONTACT_BACKGROUND":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>CIVSUB: Background Check</t><br/><br/>" +
                   "Runs wanted/flags background check for the active civilian target.";
            _txt = [_txt, "BACKGROUND_CHECK"] call _appendCivsubResult;
            if (!isNull _b1) then { _b1 ctrlEnable _inCivCtx; _b1 ctrlSetText "EXECUTE"; };
        };

        case "CIV_CONTACT_GIVE_FOOD":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>CIVSUB: Give Food</t><br/><br/>" +
                   "Provides rations to the active civilian target and records a CIVSUB aid event.";
            _txt = [_txt, "AID_RATIONS"] call _appendCivsubResult;
            if (!isNull _b1) then { _b1 ctrlEnable _inCivCtx; _b1 ctrlSetText "EXECUTE"; };
        };

        case "CIV_CONTACT_GIVE_WATER":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>CIVSUB: Give Water</t><br/><br/>" +
                   "Provides drinking water to the active civilian target and records a CIVSUB aid event.";
            _txt = [_txt, "AID_WATER"] call _appendCivsubResult;
            if (!isNull _b1) then { _b1 ctrlEnable _inCivCtx; _b1 ctrlSetText "EXECUTE"; };
        };

        case "CIV_CONTACT_DETAIN":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>CIVSUB: Detain</t><br/><br/>" +
                   "Requests server-authoritative detention for the active civilian target.";
            _txt = [_txt, "DETAIN"] call _appendCivsubResult;
            if (!isNull _b1) then { _b1 ctrlEnable _inCivCtx; _b1 ctrlSetText "EXECUTE"; };
        };

        case "CIV_CONTACT_RELEASE":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>CIVSUB: Release</t><br/><br/>" +
                   "Requests server-authoritative release for the active civilian target.";
            _txt = [_txt, "RELEASE"] call _appendCivsubResult;
            if (!isNull _b1) then { _b1 ctrlEnable _inCivCtx; _b1 ctrlSetText "EXECUTE"; };
        };

        case "CIV_CONTACT_HANDOFF":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>CIVSUB: Handoff to SHERIFF</t><br/><br/>" +
                   "Use when detainee is ready for sheriff transfer and all handoff conditions are met.";
            _txt = [_txt, "HANDOFF_SHERIFF"] call _appendCivsubResult;
            if (!isNull _b1) then { _b1 ctrlEnable _inCivCtx; _b1 ctrlSetText "EXECUTE"; };
        };

        case "CIV_CONTACT_QUESTION":
        {
            private _qid = _arg;
            private _qMap = [[
                ["Q_LIVE", "Where do you live?"],
                ["Q_WORK", "Where do you work?"],
                ["Q_IEDS", "Have you seen any IEDs?"],
                ["Q_INS", "Have you seen any insurgent activity?"],
                ["Q_OP_US", "What is your opinion of us?"],
                ["Q_OP_AREA", "What is the overall opinion of us in the area?"]
            ]] call _hmCreate;
            private _qlbl = _qMap getOrDefault [_qid, _qid];

            _txt = format [
                "<t size='1.1' font='PuristaMedium'>CIVSUB: Ask Question</t><br/><br/>" +
                "Selected: <t color='#CFE8FF'>%1</t><br/><br/>" +
                "Executes through server-authoritative CIVSUB action routing.",
                _qlbl
            ];
            _txt = [_txt, "QUESTION"] call _appendCivsubResult;
            if (!isNull _b1) then { _b1 ctrlEnable (_inCivCtx && {_qid isNotEqualTo ""}); _b1 ctrlSetText "ASK"; };
        };

        case "CIV_CONTACT_END":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>Exit CIVSUB Interaction Mode</t><br/><br/>" +
                   "Ends the current interaction session and clears CIVSUB context from INTEL tools.";
            if (!isNull _b1) then { _b1 ctrlEnable true; _b1 ctrlSetText "END"; };
        };

        case "CIV_CENSUS_OPEN":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>CIVSUB Census</t><br/><br/>" +
                   "Opens the district census view (population, casualties, W/R/G, derived cooperation/threat).<br/><br/>" +
                   "Select a district to view details. EXECUTE opens the map at the district center.";
            if (!isNull _b1) then { _b1 ctrlEnable true; _b1 ctrlSetText "OPEN"; };
        };

        case "CIV_THREAT_SUMMARY":
        {
            // AO-wide CIVSUB threat summary
            private _allDistricts = [];
            {
                private _vn = _x;
                if ((_vn find "civsub_v1_district_pub_") isEqualTo 0) then {
                    private _d = missionNamespace getVariable [_vn, createHashMap];
                    if (_d isEqualType createHashMap && { !(_d isEqualTo createHashMap) }) then {
                        _allDistricts pushBack _d;
                    };
                };
            } forEach (allVariables missionNamespace);

            private _districtRows = [];
            private _contestedCnt = 0;
            private _stableCnt = 0;
            private _mixedCnt = 0;

            {
                private _did = _x getOrDefault ["districtId", ""];
                if (_did isEqualTo "") then { continue; };

                private _W = _x getOrDefault ["W", 0];
                private _R = _x getOrDefault ["R", 0];
                private _G = _x getOrDefault ["G", 0];
                private _pop = _x getOrDefault ["population", 0];
                private _alive = _x getOrDefault ["alive", 0];

                // Locked v1 math
                private _Scoop = 0;
                private _Sthreat = 0;
                if (_pop > 0 && { _alive > 0 }) then {
                    private _Wcap = (_W min _alive);
                    private _Rcap = (_R min _alive);
                    private _Gcap = (_G min _alive);
                    private _sum = _Wcap + _Rcap + _Gcap;
                    if (_sum > 0) then {
                        _Scoop = 100.0 * (_Gcap / _sum);
                        _Sthreat = 100.0 * (_Wcap / _sum);
                    };
                };

                private _coopLbl = "Moderate";
                if (_Scoop >= 75) then { _coopLbl = "High"; } else {
                    if (_Scoop <= 35) then { _coopLbl = "Low"; };
                };
                private _coopColor = "#FFD166";
                if (_Scoop >= 75) then { _coopColor = "#9FE870"; } else {
                    if (_Scoop <= 35) then { _coopColor = "#FF7A7A"; };
                };

                private _threatLbl = "Moderate";
                if (_Sthreat >= 70) then { _threatLbl = "High"; } else {
                    if (_Sthreat <= 30) then { _threatLbl = "Low"; };
                };
                private _threatColor = "#FFD166";
                if (_Sthreat >= 70) then { _threatColor = "#FF7A7A"; } else {
                    if (_Sthreat <= 30) then { _threatColor = "#9FE870"; };
                };

                private _env = "Mixed";
                if (_Scoop >= 60 && { _Sthreat <= 40 }) then { _env = "Stable"; _stableCnt = _stableCnt + 1; } else {
                    if (_Scoop <= 40 && { _Sthreat >= 60 }) then { _env = "Contested"; _contestedCnt = _contestedCnt + 1; } else {
                        _mixedCnt = _mixedCnt + 1;
                    };
                };

                _districtRows pushBack format [
                    "<t color='#BDBDBD'>%1:</t> Coop <t color='%2'>%3</t> (%4) | Threat <t color='%5'>%6</t> (%7) | %8",
                    _did,
                    _coopColor, (_Scoop toFixed 1), _coopLbl,
                    _threatColor, (_Sthreat toFixed 1), _threatLbl,
                    _env
                ];
            } forEach _allDistricts;

            private _summary = format [
                "<t size='1.0' font='PuristaMedium' color='#B89B6B'>AO Summary</t><br/>" +
                "<t color='#BDBDBD'>Districts:</t> %1 total<br/>" +
                "<t color='#9FE870'>Stable:</t> %2  <t color='#FFD166'>Mixed:</t> %3  <t color='#FF7A7A'>Contested:</t> %4<br/><br/>",
                count _allDistricts,
                _stableCnt,
                _mixedCnt,
                _contestedCnt
            ];

            _txt = "<t size='1.25' font='PuristaMedium'>AO Threat Summary</t><br/><br/>" +
                   _summary;

            if ((count _districtRows) > 0) then {
                _txt = _txt + "<t size='1.0' font='PuristaMedium' color='#B89B6B'>District Breakdown</t><br/><br/>" +
                       (_districtRows joinString "<br/>") + "<br/><br/>";
            } else {
                _txt = _txt + "<t color='#BBBBBB'>No district data published yet.</t><br/><br/>";
            };

            _txt = _txt + "<t size='0.9' color='#AAAAAA'>This is a read-only summary. Use CIVSUB Census for detailed per-district stats.</t>";

            if (!isNull _b1) then { _b1 ctrlEnable false; };
        };

        // ── GOVERNMENT STATUS ────────────────────────────────────────────────
        case "GOV_STATUS":
        {
            // Aggregate governance picture across all districts using G_EFF_U from
            // published district snapshots.
            private _prefix2 = "civsub_v1_district_pub_";
            private _govIds = [];
            {
                private _n = _x;
                if ((_n find _prefix2) == 0) then { _govIds pushBack (_n select [count _prefix2]); };
            } forEach (allVariables missionNamespace);
            _govIds sort true;

            private _govTotal = 0;
            private _govCnt   = 0;
            private _govRows  = [];
            private _govStable = 0; private _govFrag = 0; private _govFail = 0;

            {
                private _did2 = _x;
                private _pub2 = missionNamespace getVariable [format ["%1%2", _prefix2, _did2], []];
                if (!(_pub2 isEqualType [])) then { continue; };
                if ((count _pub2) == 0) then { continue; };
                private _ph2 = [_pub2] call _hmCreate;
                private _G2  = _ph2 getOrDefault ["G", 35];
                if (!(_G2 isEqualType 0)) then { _G2 = 35; };
                _govTotal = _govTotal + _G2;
                _govCnt   = _govCnt + 1;

                private _gLbl = "Developing";
                private _gCol = "#FFD166";
                if (_G2 >= 55) then { _gLbl = "Stable";  _gCol = "#9FE870"; _govStable = _govStable + 1; } else {
                    if (_G2 <= 30) then { _gLbl = "Failing"; _gCol = "#FF7A7A"; _govFail = _govFail + 1; } else {
                        _govFrag = _govFrag + 1;
                    };
                };
                _govRows pushBack format ["<t color='#BDBDBD'>%1:</t> Gov <t color='%2'>%3</t> (%4)", _did2, _gCol, round _G2, _gLbl];
            } forEach _govIds;

            private _avgG = if (_govCnt > 0) then { _govTotal / _govCnt } else { 0 };
            private _govRating = "C — Developing";
            private _govRatingColor = "#FFD166";
            if (_avgG >= 65) then { _govRating = "A — Strong";    _govRatingColor = "#9FE870"; } else {
            if (_avgG >= 50) then { _govRating = "B — Functional"; _govRatingColor = "#C8E87A"; } else {
            if (_avgG <= 25) then { _govRating = "F — Failed";    _govRatingColor = "#FF7A7A"; } else {
            if (_avgG <= 35) then { _govRating = "D — Fragile";   _govRatingColor = "#FF9966"; };
            };};};

            _txt = "<t size='1.25' font='PuristaMedium'>Government Status</t><br/>" +
                   "<t size='0.9' color='#AAAAAA'>S2 Assessment — Government/Host-Nation Situation</t><br/><br/>" +
                   format ["<t color='#AAAAAA'>Overall Rating:</t> <t color='%1'>%2</t>  (avg G-index: %3)<br/>", _govRatingColor, _govRating, round _avgG] +
                   format ["<t color='#9FE870'>Stable:</t> %1   <t color='#FFD166'>Fragile:</t> %2   <t color='#FF7A7A'>Failing:</t> %3<br/><br/>", _govStable, _govFrag, _govFail];

            if ((count _govRows) > 0) then {
                _txt = _txt + "<t size='1.0' font='PuristaMedium' color='#B89B6B'>District Breakdown</t><br/><br/>" +
                       (_govRows joinString "<br/>") + "<br/><br/>";
            } else {
                _txt = _txt + "<t color='#BBBBBB'>No district data published yet.</t><br/><br/>";
            };

            _txt = _txt + "<t size='0.9' color='#AAAAAA'>G-index: Host-Nation government legitimacy/effectiveness (0–100). " +
                          "Increase via aid events, successful detentions (handoff), and low civilian casualties. " +
                          "Decreases with civilian harm and unchallenged insurgent activity.</t>";

            // Security force effectiveness + aid from ARC_govStats aggregate (if available)
            private _gs = missionNamespace getVariable ["ARC_govStats", []];
            if (_gs isEqualType [] && { (count _gs) > 0 }) then
            {
                private _hmGs = compile "params ['_a']; createHashMapFromArray _a";
                private _gsMap = [_gs] call _hmGs;
                private _secEff    = _gsMap getOrDefault ["security_effectiveness", -1];
                private _secRating = _gsMap getOrDefault ["security_rating", ""];
                private _aidTotal  = _gsMap getOrDefault ["aid_events_total", -1];
                private _closed    = _gsMap getOrDefault ["incidents_closed", -1];
                private _total     = _gsMap getOrDefault ["incidents_total",  -1];
                if (_secEff isEqualType 0 && { _secEff >= 0 }) then
                {
                    private _secCol = "#FFD166";
                    if (_secRating isEqualTo "HIGH") then { _secCol = "#9FE870"; } else {
                        if (_secRating isEqualTo "LOW") then { _secCol = "#FF7A7A"; };
                    };
                    _txt = _txt + "<br/><br/><t size='1.0' font='PuristaMedium' color='#B89B6B'>S2 Force Metrics</t><br/><br/>";
                    _txt = _txt + format [
                        "<t color='#AAAAAA'>Security Force Effectiveness:</t> <t color='%1'>%2</t> (%3%%)<br/>",
                        _secCol, _secRating, round _secEff
                    ];
                    if (_total isEqualType 0 && { _total > 0 }) then
                    {
                        _txt = _txt + format [
                            "<t color='#AAAAAA'>Incident Close Rate:</t> %1 / %2 (%3%%)<br/>",
                            _closed, _total, round ((_closed / _total) * 100)
                        ];
                    };
                    if (_aidTotal isEqualType 0 && { _aidTotal >= 0 }) then
                    {
                        _txt = _txt + format ["<t color='#AAAAAA'>Cumulative Aid Events:</t> %1<br/>", _aidTotal];
                    };
                };
            };

            if (!isNull _b1) then { _b1 ctrlEnable false; };
        };

        // ── OPFOR STATUS ─────────────────────────────────────────────────────
        case "OPFOR_STATUS":
        {
            // Known enemy situation from S2 perspective:
            // - Overall threat level (aggregate S_THREAT from districts)
            // - Active incident (if any)
            // - Last 10 threat/sighting intel log entries
            private _prefix3 = "civsub_v1_district_pub_";
            private _opforIds = [];
            {
                private _n = _x;
                if ((_n find _prefix3) == 0) then { _opforIds pushBack (_n select [count _prefix3]); };
            } forEach (allVariables missionNamespace);

            private _threatSum = 0; private _threatCnt = 0;
            {
                private _did3 = _x;
                private _pub3 = missionNamespace getVariable [format ["%1%2", _prefix3, _did3], []];
                if (!(_pub3 isEqualType []) || { (count _pub3) == 0 }) then { continue; };
                private _ph3 = [_pub3] call _hmCreate;
                private _W3  = _ph3 getOrDefault ["W", 45]; if (!(_W3  isEqualType 0)) then { _W3  = 45; };
                private _R3  = _ph3 getOrDefault ["R", 55]; if (!(_R3  isEqualType 0)) then { _R3  = 55; };
                private _G3  = _ph3 getOrDefault ["G", 35]; if (!(_G3  isEqualType 0)) then { _G3  = 35; };
                private _St3 = ((1.00 * _R3) - (0.35 * _W3) - (0.25 * _G3)) max 0 min 100;
                _threatSum = _threatSum + _St3;
                _threatCnt = _threatCnt + 1;
            } forEach _opforIds;

            private _avgThreat = if (_threatCnt > 0) then { _threatSum / _threatCnt } else { 0 };
            private _threatLevel = "MODERATE";
            private _threatColor = "#FFD166";
            if (_avgThreat >= 65) then { _threatLevel = "HIGH";    _threatColor = "#FF7A7A"; } else {
                if (_avgThreat <= 30) then { _threatLevel = "LOW"; _threatColor = "#9FE870"; };
            };

            // Active incident
            private _activeTaskId = missionNamespace getVariable ["ARC_activeTaskId", ""];
            if (!(_activeTaskId isEqualType "")) then { _activeTaskId = ""; };
            private _activeIncDisp = missionNamespace getVariable ["ARC_activeIncidentDisplayName", ""];
            if (!(_activeIncDisp isEqualType "")) then { _activeIncDisp = ""; };

            _txt = "<t size='1.25' font='PuristaMedium'>Enemy Situation</t><br/>" +
                   "<t size='0.9' color='#AAAAAA'>S2 Estimate — Based on collected HUMINT/SIGINT</t><br/><br/>" +
                   format ["<t color='#AAAAAA'>AO Threat Level:</t> <t color='%1'>%2</t>  (avg S-Threat: %3)<br/>", _threatColor, _threatLevel, round _avgThreat] +
                   format ["<t color='#AAAAAA'>Active Incident:</t> %1<br/><br/>",
                       if (_activeTaskId isEqualTo "") then {"None"} else { format ["%1 (ID: %2)", _activeIncDisp, _activeTaskId] }];

            // Last 10 SIGHTING/THREAT intel log entries
            private _iLog = missionNamespace getVariable ["ARC_pub_intelLog", []];
            if (!(_iLog isEqualType [])) then { _iLog = []; };
            private _opforEntries = [];
            {
                if (!(_x isEqualType []) || { (count _x) < 6 }) then { continue; };
                private _cat = if ((count _x) > 2) then { toUpper (trim (_x # 2)) } else { "" };
                if (_cat in ["SIGHTING", "THREAT", "ISR"]) then { _opforEntries pushBack _x; };
            } forEach _iLog;

            // Take last 10
            if ((count _opforEntries) > 10) then { _opforEntries = _opforEntries select [((count _opforEntries) - 10), 10]; };

            if ((count _opforEntries) > 0) then {
                _txt = _txt + "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Recent Intel (SIGHTING/THREAT/ISR)</t><br/><br/>";
                {
                    if ((count _x) < 6) then { continue; };
                    private _cat2  = toUpper (trim (_x # 2));
                    private _summ  = trim (_x # 3);
                    if ((count _summ) > 80) then { _summ = (_summ select [0, 80]) + "..."; };
                    private _grid2 = if ((count _x) > 4) then {
                        private _iPos = _x # 4;
                        if (_iPos isEqualType [] && { (count _iPos) >= 2 }) then { mapGridPosition _iPos } else { "---" }
                    } else { "---" };
                    _txt = _txt + format ["<t color='#AAAAAA'>%1</t>  Grid:<t color='#DDDDDD'>%2</t>  %3<br/>", _cat2, _grid2, _summ];
                } forEach _opforEntries;
            } else {
                _txt = _txt + "<t color='#BBBBBB'>No SIGHTING/THREAT/ISR intel logged yet. Log sightings via S2 tools.</t><br/>";
            };

            _txt = _txt + "<br/><t size='0.9' color='#AAAAAA'>This is an S2 estimate based on collected field intelligence. " +
                          "Threat level is derived from district W/R/G influence indices.</t>";

            if (!isNull _b1) then { _b1 ctrlEnable false; };
        };

        default
        {
            _txt = "<t color='#BBBBBB'>Select a tool or an intel log entry.</t>";
        };

        // ── AO THREAD ─────────────────────────────────────────────────────
        case "AO_THREAD":
        {
            // Combined activity feed: active world-time cultural events
            // + most recent intel log entries across all categories.

            // World-time events
            private _wtSnap2 = missionNamespace getVariable ["ARC_worldTimeSnap", []];
            private _activeEvents = missionNamespace getVariable ["ARC_worldTimeEvents", []];
            if (!(_activeEvents isEqualType [])) then { _activeEvents = []; };
            private _nextEvt = missionNamespace getVariable ["ARC_worldTimeNextEvent", ["", 25.0]];
            if (!(_nextEvt isEqualType []) || { (count _nextEvt) < 2 }) then { _nextEvt = ["", 25.0]; };

            private _evtHeader = "";
            if (_wtSnap2 isEqualType [] && { (count _wtSnap2) >= 3 }) then
            {
                private _dt2    = _wtSnap2 select 1;
                private _phase2 = _wtSnap2 select 2;
                if (!(_phase2 isEqualType "")) then { _phase2 = "UNKNOWN"; };
                private _hh2 = floor _dt2;
                private _mm2 = round ((_dt2 - _hh2) * 60);
                _evtHeader = format [
                    "<t color='#AAAAAA'>Local time:</t> %1%2:%3%4  <t color='#AAAAAA'>Phase:</t> %5<br/>",
                    if (_hh2 < 10) then {"0"} else {""},
                    _hh2,
                    if (_mm2 < 10) then {"0"} else {""},
                    _mm2,
                    _phase2
                ];
            };

            private _evtBody = "";
            if ((count _activeEvents) > 0) then
            {
                _evtBody = format [
                    "<t color='#9FE870'>Now:</t> %1<br/>",
                    _activeEvents joinString "  |  "
                ];
            } else {
                _evtBody = "<t color='#888888'>No active cultural events for current time.</t><br/>";
            };

            private _nextEvtName  = _nextEvt select 0;
            private _nextEvtStart = _nextEvt select 1;
            private _nextStr = "";
            if (!(_nextEvtName isEqualTo "") && { _nextEvtStart < 25 }) then
            {
                private _nHH = floor _nextEvtStart;
                private _nMM = round ((_nextEvtStart - _nHH) * 60);
                _nextStr = format [
                    "<t color='#FFD166'>Next:</t> %1 (~%2%3:%4%5L)<br/><br/>",
                    _nextEvtName,
                    if (_nHH < 10) then {"0"} else {""},
                    _nHH,
                    if (_nMM < 10) then {"0"} else {""},
                    _nMM
                ];
            };

            // Intel feed: last 15 entries (all categories)
            private _iLog2 = missionNamespace getVariable ["ARC_pub_intelLog", []];
            if (!(_iLog2 isEqualType [])) then { _iLog2 = []; };
            private _feedEntries = [];
            {
                if (!(_x isEqualType []) || { (count _x) < 4 }) then { continue; };
                _feedEntries pushBack _x;
            } forEach _iLog2;

            // Take last 15
            if ((count _feedEntries) > 15) then
            {
                _feedEntries = _feedEntries select [((count _feedEntries) - 15), 15];
            };
            // Reverse (newest first) using index walk
            private _feedRevArr = [];
            private _fi = (count _feedEntries) - 1;
            while { _fi >= 0 } do { _feedRevArr pushBack (_feedEntries select _fi); _fi = _fi - 1; };

            private _feedLines = "";
            if ((count _feedRevArr) > 0) then
            {
                {
                    if ((count _x) < 4) then { continue; };
                    private _cat3  = toUpper (_x select 2);
                    private _summ3 = _x select 3;
                    if (!(_summ3 isEqualType "")) then { _summ3 = ""; };
                    if ((count _summ3) > 90) then { _summ3 = (_summ3 select [0, 90]) + "..."; };
                    private _catCol = "#AAAAAA";
                    if (_cat3 isEqualTo "OPS")     then { _catCol = "#6EB8E0"; };
                    if (_cat3 isEqualTo "HUMINT")  then { _catCol = "#FFD166"; };
                    if (_cat3 isEqualTo "ISR")     then { _catCol = "#C8E87A"; };
                    if (_cat3 isEqualTo "SIGHTING" || { _cat3 isEqualTo "THREAT" }) then { _catCol = "#FF9966"; };
                    _feedLines = _feedLines + format [
                        "<t color='%1'>[%2]</t> %3<br/>",
                        _catCol, _cat3, _summ3
                    ];
                } forEach _feedRevArr;
            } else {
                _feedLines = "<t color='#888888'>No intel log entries yet.</t><br/>";
            };

            _txt = "<t size='1.25' font='PuristaMedium'>AO Thread</t><br/>" +
                   "<t size='0.9' color='#AAAAAA'>Pattern-of-Life + Activity Feed</t><br/><br/>" +
                   _evtHeader + _evtBody + _nextStr +
                   "<t size='1.0' font='PuristaMedium' color='#B89B6B'>Intel Activity (newest first)</t><br/><br/>" +
                   _feedLines;

            if (!isNull _b1) then { _b1 ctrlEnable false; };
        };
    };
};


};



// ---------------------------------------------------------------------------
// S2 category panels integration:
// In TOOLS mode, show stacked sub-panels and keep MainList hidden as master.
// In CENSUS mode, hide panels and use MainList normally.
// ---------------------------------------------------------------------------
private _useCatPanels = (_mode != "CENSUS");

if (_useCatPanels) then {
    if (!isNull _list) then {
        _list ctrlShow false;
        _list ctrlEnable false;

        private _panels = [_display] call _ensureS2CatPanels;
        [_display, _list, _panels] call _layoutS2CatPanels;
        [_display, _list, _panels] call _renderS2CatPanelsFromMaster;

        { (_x # 0) ctrlShow true; (_x # 1) ctrlShow true; (_x # 2) ctrlShow true; } forEach _panels;
    };
} else {
    private _panels = uiNamespace getVariable ["ARC_s2_catPanels", []];
    if (_panels isEqualType []) then {
        { 
            if (_x isEqualType [] && { (count _x) == 3 }) then {
                { if (!isNull _x) then { _x ctrlShow false; }; } forEach _x;
            };
        } forEach _panels;
    };
    if (!isNull _list) then { _list ctrlShow true; _list ctrlEnable true; };
};

// Queue button gating
if (!isNull _b2) then
{
    _b2 ctrlEnable _isAuth;
};

_details ctrlSetStructuredText parseText _txt;

// Auto-fit + clamp to the DetailsGroup (78016) so the group scrolls vertically when needed,
// but NEVER forces horizontal scrolling or overlaps the S2 workflow controls.
// IMPORTANT: 78012 is a child control of 78016, so x/y/w must remain in group-local
// coordinates (not absolute safeZone/display coordinates), otherwise the text pane drifts
// to the far right/off-screen on repeated paints.
private _defaultPos = uiNamespace getVariable ["ARC_console_intelDetailsDefaultPos", []];
if (!(_defaultPos isEqualType []) || { (count _defaultPos) < 4 }) then
{
    _defaultPos = ctrlPosition _details;
    uiNamespace setVariable ["ARC_console_intelDetailsDefaultPos", +_defaultPos];
};

[_details] call BIS_fnc_ctrlFitToTextHeight;

private _grp = _display displayCtrl 78016;
if (!isNull _grp) then {
    private _pg = ctrlPosition _grp;
    private _xG = _pg # 0;
    private _yG = _pg # 1;
    private _hG = _pg # 3;

    // Determine the lowest visible workflow control bottom edge that intersects
    // the details group horizontally.
    private _padY = 0.006;

    private _maxBottom = _yG;
    {
        if (!isNull _x && {ctrlShown _x}) then {
            private _pC = ctrlPosition _x;
            private _r = (_pC # 0) + (_pC # 2);
            if (_r > _xG) then {
                private _b = (_pC # 1) + (_pC # 3);
                if (_b > _maxBottom) then { _maxBottom = _b; };
            };
        };
    } forEach [_lblMethod,_cmbMethod,_lblCat,_cmbCat,_lblLead,_cmbLead];

    // Convert absolute y into group-local y and pin x/w to the designed defaults.
    private _yLocal = ((_maxBottom + _padY) - _yG) max (_defaultPos # 1);
    private _availH = (_hG - _yLocal) max 0.02;

    private _pD = ctrlPosition _details;
    private _fitH = _pD # 3;

    _pD set [0, _defaultPos # 0];
    _pD set [1, _yLocal];
    _pD set [2, _defaultPos # 2];
    _pD set [3, _fitH max _availH];

    _details ctrlSetPosition _pD;
    _details ctrlCommit 0;
} else {
    // Fallback: keep inset x/y/w stable and apply fitted height.
    private _pD = ctrlPosition _details;
    _pD set [0, _defaultPos # 0];
    _pD set [1, _defaultPos # 1];
    _pD set [2, _defaultPos # 2];
    _details ctrlSetPosition _pD;
    _details ctrlCommit 0;
};

true
