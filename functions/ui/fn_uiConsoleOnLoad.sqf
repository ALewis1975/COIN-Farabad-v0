/*
    ARC_fnc_uiConsoleOnLoad

    Client: dialog onLoad for ARC_FarabadConsoleDialog.
    Populates the tab list based on group/role and starts a refresh loop.

    Params:
      0: DISPLAY

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]]
];

if (isNull _display) exitWith {false};

private _ctrlTabs    = _display displayCtrl 78001;
private _ctrlMainGrp = _display displayCtrl 78015;
private _ctrlMain    = _display displayCtrl 78010;
private _ctrlList    = _display displayCtrl 78011;
private _ctrlDetailsGrp = _display displayCtrl 78016;
private _ctrlDetails = _display displayCtrl 78012;


// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// UI-SKIN: enforce console typography defaults.
// Labels/navigation stay COYOTE; body/value text defaults to WHITE.
// ---------------------------------------------------------------------------
private _coyote = [0.722,0.608,0.420,1];
private _white  = [1,1,1,1];

// Title bar: coyote + 75% larger font height
private _ctrlTitle = _display displayCtrl 78091;
if (!isNull _ctrlTitle) then {
    _ctrlTitle ctrlSetTextColor _coyote;
    _ctrlTitle ctrlSetFontHeight ((safeZoneH / 25) * 1.75);
};

// TSH-INC1: Status strip indicators (NET/GPS/BATT/SYNC) + nav + buttons: coyote
{ if (!isNull _x) then { _x ctrlSetTextColor _coyote; }; } forEach [
    _display displayCtrl 78060,   // StatusNet
    _display displayCtrl 78061,   // StatusGps
    _display displayCtrl 78062,   // StatusBatt
    _display displayCtrl 78063,   // StatusSync
    _display displayCtrl 78001,   // Tabs list
    _display displayCtrl 78021,   // Primary
    _display displayCtrl 78022,   // Secondary
    _display displayCtrl 78023,   // Refresh
    _display displayCtrl 78024    // Close
];

// Main/value panes: white (structured text + list)
{ if (!isNull _x) then { _x ctrlSetTextColor _white; }; } forEach [
    _display displayCtrl 78010,   // Main structured text
    _display displayCtrl 78011,   // Main list
    _display displayCtrl 78012    // Details structured text
];
// Ops (S3) frame controls (UI09)
private _opsCtrls = [
    _display displayCtrl 78030,
    _display displayCtrl 78031,
    _display displayCtrl 78032,
    _display displayCtrl 78033,
    _display displayCtrl 78034,
    _display displayCtrl 78035,
    _display displayCtrl 78036,
    _display displayCtrl 78037,
    _display displayCtrl 78038
];

// Default: hide the list/details pane (only shown on specific tabs)
if (!isNull _ctrlList) then { _ctrlList ctrlShow false; };
if (!isNull _ctrlDetailsGrp) then { _ctrlDetailsGrp ctrlShow false; };
if (!isNull _ctrlDetails) then { _ctrlDetails ctrlShow false; };

// Default: ensure main group is visible (main control is the scrollable child)
if (!isNull _ctrlMainGrp) then { _ctrlMainGrp ctrlShow true; };

// Default: hide Ops lists (shown only on the Operations tab)
{ if (!isNull _x) then { _x ctrlShow false; }; } forEach _opsCtrls;

// Default: hide S2 workflow controls (shown only on Intelligence tab)
private _s2Ctrls = [
    _display displayCtrl 78050,
    _display displayCtrl 78051,
    _display displayCtrl 78052,
    _display displayCtrl 78053,
    _display displayCtrl 78054,
    _display displayCtrl 78055
];
{ if (!isNull _x) then { _x ctrlShow false; }; } forEach _s2Ctrls;

// ---------------------------------------------------------------------------
// Access flags
// ---------------------------------------------------------------------------
uiNamespace setVariable ["ARC_console_cmdMode", "OVERVIEW"];
uiNamespace setVariable ["ARC_console_cmdQueueForceRebuild", true];
uiNamespace setVariable ["ARC_console_cmdQueueSelectedQid", ""];
uiNamespace setVariable ["ARC_console_cmdQueueSelectedPending", false];

private _omniTokens = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
if (!(_omniTokens isEqualType [])) then { _omniTokens = ["OMNI"]; };
if ((count _omniTokens) isEqualTo 0) then { _omniTokens = ["OMNI"]; };

private _isOmni = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isOmni = true; };
} forEach _omniTokens;

private _isAuth  = [player] call ARC_fnc_rolesIsAuthorized;
private _isTocS2 = [player] call ARC_fnc_rolesIsTocS2;
private _isTocS3 = [player] call ARC_fnc_rolesIsTocS3;
private _isCmd   = [player] call ARC_fnc_rolesIsTocCommand;

private _atStation = [player] call ARC_fnc_uiConsoleIsAtStation;

// TOC Ops tab:
// - Full access: TOC staff or OMNI
// - View-only access: authorized leadership when physically at a TOC/mobile terminal
private _canTocFull = _isOmni || { _isCmd } || { _isTocS3 } || { _isTocS2 };
private _canTocTab  = _canTocFull || { _atStation && _isAuth };

// Intel feed is useful for TOC roles, and for authorized field leadership.
private _canIntel = _canTocFull || _isAuth || _isOmni;

// Headquarters (Admin) tab access (S3, TOC Command, BN Command group, OMNI)
private _hqTokens = missionNamespace getVariable ["ARC_consoleHQTokens", ["BNCMD", "BN COMMAND", "BNHQ", "BN CO", "BNCO", "BN CDR", "REDFALCON 6", "REDFALCON6", "FALCON 6", "FALCON6"]];
if (!(_hqTokens isEqualType [])) then { _hqTokens = ["BNCMD", "BN COMMAND", "BNHQ"]; };

private _isBnCmd = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isBnCmd = true; };
} forEach _hqTokens;

private _canHQ = _isOmni || _isCmd || _isTocS3 || _isBnCmd;

// S-1 (personnel) access mirrors HQ-style token/command controls.
private _s1Tokens = missionNamespace getVariable ["ARC_consoleS1Tokens", _hqTokens];
if (!(_s1Tokens isEqualType [])) then { _s1Tokens = _hqTokens; };
private _isS1Token = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _isS1Token = true; };
} forEach _s1Tokens;
private _canS1 = _isOmni || _isCmd || _isTocS3 || _isS1Token;

// Operations tab access: field leadership + TOC staff
private _canOps = _isOmni || _isCmd || _isTocS3 || _isAuth;

// Air tab access:
// - Action permissions are per capability (HOLD/RELEASE vs PRIORITIZE/CANCEL)
// - Read-only access: TOC staff + OMNI (situational awareness)
private _towerAllowsAction = {
    params ["_action"];

    private _ok = false;
    private _auth = [player, _action] call ARC_fnc_airbaseTowerAuthorize;
    if (_auth isEqualType [] && { (count _auth) > 0 }) then
    {
        _ok = _auth select 0;
        if (!(_ok isEqualType true) && !(_ok isEqualType false)) then { _ok = false; };
    };

    _ok
};

private _canAirHold = ["HOLD"] call _towerAllowsAction;
private _canAirRelease = ["RELEASE"] call _towerAllowsAction;
private _canAirPrioritize = ["PRIORITIZE"] call _towerAllowsAction;
private _canAirCancel = ["CANCEL"] call _towerAllowsAction;
private _canAirStaff = ["STAFF"] call _towerAllowsAction;

private _canAirHoldRelease = _canAirHold || _canAirRelease;
private _canAirQueueManage = _canAirPrioritize || _canAirCancel;
private _canAirControl = _canAirHoldRelease || _canAirQueueManage || _canAirStaff;

private _canAirRead = _canAirControl || _isOmni || _canTocFull || _isBnCmd;
private _pilotTokens = missionNamespace getVariable ["airbase_v1_pilotGroupTokens", ["EFS", "HAWG", "VIPER", "PILOT"]];
if (!(_pilotTokens isEqualType [])) then { _pilotTokens = ["EFS", "HAWG", "VIPER", "PILOT"]; };
private _canAirPilot = false;
{
    if (_x isEqualType "" && { [player, _x] call ARC_fnc_rolesHasGroupIdToken }) exitWith { _canAirPilot = true; };
} forEach _pilotTokens;
// Supplement: if the player is currently in an air vehicle (e.g. after FIR pilot replacement),
// preserve pilot status so AIR/TOWER options remain visible in the console.
if (!_canAirPilot) then {
    private _pVeh = vehicle player;
    if (_pVeh != player && { _pVeh isKindOf "Air" }) then { _canAirPilot = true; };
};
uiNamespace setVariable ["ARC_console_airCanHold", _canAirHold];
uiNamespace setVariable ["ARC_console_airCanRelease", _canAirRelease];
uiNamespace setVariable ["ARC_console_airCanPrioritize", _canAirPrioritize];
uiNamespace setVariable ["ARC_console_airCanCancel", _canAirCancel];
uiNamespace setVariable ["ARC_console_airCanHoldRelease", _canAirHoldRelease];
uiNamespace setVariable ["ARC_console_airCanQueueManage", _canAirQueueManage];
uiNamespace setVariable ["ARC_console_airCanStaff", _canAirStaff];
uiNamespace setVariable ["ARC_console_airCanRead", _canAirRead];
uiNamespace setVariable ["ARC_console_airCanControl", _canAirControl];
uiNamespace setVariable ["ARC_console_airCanPilot", _canAirPilot];
uiNamespace setVariable ["ARC_console_airMode", if (_canAirPilot && !_canAirControl) then {"PILOT"} else {"TOWER"}];
uiNamespace setVariable ["ARC_console_airSubmode", "AIRFIELD_OPS"];

// Farabad Tower staff (canAirControl) and pilots (canAirPilot) also need S3/OPS visibility.
_canOps = _canOps || _canAirControl || _canAirPilot;

// ---------------------------------------------------------------------------
// Build tab list (store ids so selection events map to stable strings)
// ---------------------------------------------------------------------------
private _tabIds = [];
lbClear _ctrlTabs;

// UI09 top-level tab model
_tabIds pushBack "DASH";
_ctrlTabs lbAdd "COP / DASH";

// TOC snapshot board (queue + orders + incident)
if (_canTocTab) then
{
    _tabIds pushBack "BOARDS";
    _ctrlTabs lbAdd "BOARDS (TOC)";
};

if (_canIntel) then
{
    _tabIds pushBack "INTEL";
    _ctrlTabs lbAdd "S2 / INTEL";
};

if (_canOps) then
{
    _tabIds pushBack "OPS";
    _ctrlTabs lbAdd "S3 / OPS";
};

if (_canAirRead || _canAirPilot) then
{
    _tabIds pushBack "AIR";
    _ctrlTabs lbAdd "AIR / TOWER";
};

_tabIds pushBack "HANDOFF";
_ctrlTabs lbAdd "HANDOFF (INTEL/EPW)";

if (_canTocTab) then
{
    _tabIds pushBack "CMD";
    _ctrlTabs lbAdd "TOC / CMD";
};

if (_canHQ) then
{
    _tabIds pushBack "HQ";
    _ctrlTabs lbAdd "HQ / ADMIN";
};

if (_canS1) then
{
    _tabIds pushBack "S1";
    _ctrlTabs lbAdd "S1 / PERSONNEL";
};

uiNamespace setVariable ["ARC_console_tabIds", _tabIds];

// ---------------------------------------------------------------------------
// Select default tab (supports "forced tab" open requests from station addActions)
// ---------------------------------------------------------------------------
private _forceTab = ["ARC_console_forceTab", ""] call ARC_fnc_uiNsGetString;
_forceTab = toUpper _forceTab;

// Clear after consumption to avoid "sticky" tab forcing
uiNamespace setVariable ["ARC_console_forceTab", nil];

private _sel = 0;
if (_forceTab != "") then
{
    private _i = _tabIds find _forceTab;
    if (_i >= 0) then { _sel = _i; };
};

if ((count _tabIds) > 0) then
{
    uiNamespace setVariable ["ARC_console_activeTab", _tabIds select _sel];
}
else
{
    uiNamespace setVariable ["ARC_console_activeTab", "HANDOFF"];
    _sel = 0;
};

_ctrlTabs lbSetCurSel _sel;

// Initial hint in the main panel (refresh overwrites this quickly)
if (!isNull _ctrlMain) then
{
    _ctrlMain ctrlSetStructuredText parseText "<t size='1.05' color='#B89B6B'>Loading...</t>";
};

private _clientRefreshEnabled = missionNamespace getVariable ["ARC_clientStateRefreshEnabled", true];
private _pubStateAvailable = !isNil { missionNamespace getVariable "ARC_pub_state" };

// Initial paint (guard against pre-snapshot refresh noise when client init is in timeout fallback mode)
if (_clientRefreshEnabled || _pubStateAvailable) then
{
    [_display] call ARC_fnc_uiConsoleRefresh;
}
else
{
    diag_log "[ARC][INFO] uiConsoleOnLoad: deferring initial refresh until ARC_serverReady/ARC_pub_state are available.";
};

// Refresh loop (event-first + fallback polling)
uiNamespace setVariable ["ARC_console_refreshLoop", true];
uiNamespace setVariable ["ARC_console_dirty", false];
[_display] spawn {
    params ["_display"];

    private _fallbackCadenceSec = 3;
    private _nextFallbackAt = diag_tickTime + _fallbackCadenceSec;
    private _focusedCtrlFromDisplay = compile "params ['_display']; focusedCtrl _display";
    private _shouldSkipRefreshForFocus = {
        params ["_display"];

        // Guard: display can close while this spawned loop is still winding down.
        if (isNull _display) exitWith {false};

        private _focusedCtrl = [_display] call _focusedCtrlFromDisplay;

        // Guard: focusedCtrl can return non-Control values during teardown.
        if (!(_focusedCtrl isEqualType controlNull)) exitWith {false};
        if (isNull _focusedCtrl) exitWith {false};

        // Guard: control can become null between retrieval and type usage.
        if (isNull _focusedCtrl) exitWith {false};

        (ctrlType _focusedCtrl) in [2, 4] // CT_EDIT=2, CT_COMBO=4
    };

    while { !isNull _display && { dialog } && { ["ARC_console_refreshLoop", false] call ARC_fnc_uiNsGetBool } } do
    {
        // Prevent repaint from collapsing open dropdowns and interrupting text input.
        // Skip refresh while the user is focused on an Edit or Combo control.
        private _skip = [_display] call _shouldSkipRefreshForFocus;

        if (!_skip) then
        {
            private _refreshEnabled = missionNamespace getVariable ["ARC_clientStateRefreshEnabled", true];
            private _hasPubState = !isNil { missionNamespace getVariable "ARC_pub_state" };
            private _isDirty = ["ARC_console_dirty", false] call ARC_fnc_uiNsGetBool;
            private _now = diag_tickTime;
            private _runFallback = _now >= _nextFallbackAt;

            if (_refreshEnabled || _hasPubState) then
            {
                if (_isDirty || _runFallback) then
                {
                    [_display] call ARC_fnc_uiConsoleRefresh;
                    uiNamespace setVariable ["ARC_console_dirty", false];
                    _nextFallbackAt = _now + _fallbackCadenceSec;
                };
            };
        };

        uiSleep 0.2;
    };
};

true
