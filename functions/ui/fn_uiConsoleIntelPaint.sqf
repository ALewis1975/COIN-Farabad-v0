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
// and render 5 visible panel listboxes as UI-only projections.
// ---------------------------------------------------------------------------

private _ensureS2CatPanels = {
    params ["_display"];

    private _k = "ARC_s2_catPanels";
    private _panels = uiNamespace getVariable [_k, []];

    private _ok = (_panels isEqualType [] && { (count _panels) == 5 });
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
                if (_d isEqualTo "" || { _d isEqualTo "HDR" }) exitWith {};

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

        _panels pushBack (["INTEL LOGGING"] call _mkPanel);
        _panels pushBack (["LEAD REQUESTS (S2)"] call _mkPanel);
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
    private _avail = _h - (_gap * 4);
    if (_avail < 0.20) then { _avail = _h; _gap = 0; };

    private _weights = [0.16, 0.16, 0.18, 0.22, 0.28];

    private _yCur = _y;
    for "_pi" from 0 to 4 do {
        private _p = _panels # _pi;
        _p params ["_bg","_lbl","_lb"];

        private _ph = _avail * (_weights # _pi);
        if (_pi == 4) then { _ph = (_y + _h) - _yCur; };

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

    private _map = createHashMapFromArray [
        ["INTEL LOGGING",      (_panels # 0) # 2],
        ["LEAD REQUESTS (S2)", (_panels # 1) # 2],
        ["CIVSUB / MDT",       (_panels # 2) # 2],
        ["ADMIN / TOOLS",      (_panels # 3) # 2],
        ["INTEL FEED",         (_panels # 4) # 2]
    ];

    private _section = "";
    for "_i" from 0 to ((lbSize _listMaster) - 1) do {
        private _d = _listMaster lbData _i;
        private _t = _listMaster lbText _i;

        if (_d isEqualTo "HDR") then {
            _section = toUpper (trim _t);
        } else {
            if (_section isEqualTo "") then { continue; };
            private _lb = _map getOrDefault [_section, controlNull];
            if (isNull _lb) then { continue; };
            if (!(_d isEqualType "")) then { continue; };

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
                        private _ph = createHashMapFromArray _pub;
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

                    private _i = _list lbAdd _label;
                    _list lbSetData [_i, format ["CIV_CENSUS_DID|%1", _did]];

                    // Subtle coloring when district is "hot" (threat high)
                    if (_Sthreat >= 70) then { _list lbSetColor [_i, [1.0, 0.72, 0.55, 1]]; };
                    if (_Scoop >= 75 && { _Sthreat <= 35 }) then { _list lbSetColor [_i, [0.70, 0.95, 0.70, 1]]; };
                } forEach _ids;
            };
        };
    }
    else
    {
        // Intel logging (consolidated)
        ["INTEL LOGGING"] call _addHdr;
        if (_canLog) then
        {
            ["Log Intel / Sighting", "INTEL_LOG"] call _addTool;
        }
        else
        {
            ["(Access denied)", "HDR"] call _addTool;
        };

        // Lead requests (consolidated)
        ["LEAD REQUESTS (S2)"] call _addHdr;
        if (_canLeadReq) then
        {
            ["Create Lead Request", "LEAD_REQ"] call _addTool;
        }
        else
        {
            ["(S2/TOC only)", "HDR"] call _addTool;
        };

        // CIVSUB MDT (run last shown ID card)
        ["CIVSUB / MDT"] call _addHdr;
        ["Run Last Civ ID (MDT)", "CIV_MDT_RUN"] call _addTool;
        ["CIVSUB Census (District Stats)", "CIV_CENSUS_OPEN"] call _addTool;

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

        // Show last 25
        private _start = ((count _intelLog) - 25) max 0;
        for "_i" from _start to ((count _intelLog) - 1) do
        {
            private _e = _intelLog # _i;
            if (!(_e isEqualType [] && { (count _e) >= 6 })) then { continue; };
            _e params ["_id", "_t", "_cat", "_sum", "_p", "_meta"];
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

// Default action button state
if (!isNull _b1) then { _b1 ctrlSetText "EXECUTE"; _b1 ctrlEnable false; };

// Tool descriptions / intel details
if (_mode isEqualTo "CENSUS") then
{
if (_data isEqualTo "HDR") then
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
            private _ph = if ((count _pub) > 0) then { createHashMapFromArray _pub } else { createHashMap };

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
            private _settByDid = createHashMapFromArray [
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
            ];

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
                "<t size='1.05' font='PuristaMedium'>District Readout</t><br/>" +
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
                "<br/><t size='1.05' font='PuristaMedium'>Raw Metrics</t><br/><br/>" +
                format ["<t color='#AAAAAA'>Centroid:</t> %1  <t color='#AAAAAA'>Grid:</t> %2  <t color='#AAAAAA'>Radius:</t> %3m<br/>",
                        if (_centroid isEqualType [] && { (count _centroid) >= 2 }) then { format ['[%1,%2]', (_centroid#0) toFixed 0, (_centroid#1) toFixed 0] } else { "(n/a)" },
                        if (_grid isEqualTo "") then {"(n/a)"} else {_grid},
                        _rad
                ] +
                "<br/>" +
                format ["<t color='#AAAAAA'>Population:</t> %1  <t color='#AAAAAA'>Alive est:</t> %2<br/>", _popS, _aliveS] +
                format ["<t color='#AAAAAA'>W / R / G:</t> %1 / %2 / %3<br/>", (round _W), (round _R), (round _G)] +
                format ["<t color='#AAAAAA'>S_COOP:</t> %1  <t color='#AAAAAA'>S_THREAT:</t> %2<br/>", (_Scoop toFixed 1), (_Sthreat toFixed 1)] +
                "<br/>" +
                format ["<t color='#AAAAAA'>CIV KIA:</t> %1  <t color='#AAAAAA'>CIV WIA:</t> %2<br/>", _kia, _wia] +
                format ["<t color='#AAAAAA'>Crime DB hits:</t> %1<br/>", _hits] +
                format ["<t color='#AAAAAA'>Detentions:</t> %1 initiated, %2 handed off<br/>", _detI, _detH] +
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
if (_data isEqualTo "HDR") then
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
                private _g = if (_p isEqualType [] && { (count _p) >= 2 }) then { mapGridPosition _p } else { "" };

                private _detailsTxt = "";
                if (_meta isEqualType [] && { (count _meta) > 0 }) then
                {
                    {
                        if (_x isEqualType [] && { (count _x) >= 2 }) then
                        {
                            private _k = _x # 0;
                            private _v = _x # 1;
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

            if (!isNull _b1) then { _b1 ctrlEnable true; _b1 ctrlSetText "Open Map"; };
        };

        case "CIV_CENSUS_OPEN":
        {
            _txt = "<t size='1.1' font='PuristaMedium'>CIVSUB Census</t><br/><br/>" +
                   "Opens the district census view (population, casualties, W/R/G, derived cooperation/threat).<br/><br/>" +
                   "Select a district to view details. EXECUTE opens the map at the district center.";
            if (!isNull _b1) then { _b1 ctrlEnable true; _b1 ctrlSetText "OPEN"; };
        };

case "CIV_MDT_RUN":
{
    _txt = "<t size='1.05'>MDT: Run the most recently shown civilian ID card against the Crime DB.</t><br/><br/>" +
           "<t size='0.95'>Workflow:</t><br/>" +
           "1) Show Papers on a civilian<br/>" +
           "2) Return here and Execute<br/>" +
           "3) If hit: detain + transport for sheriff handoff<br/>";

    if (!isNull _b1) then { _b1 ctrlEnable true; };
};



        default
        {
            _txt = "<t color='#BBBBBB'>Select a tool or an intel log entry.</t>";
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
