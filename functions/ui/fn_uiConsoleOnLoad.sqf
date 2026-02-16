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

// Operations tab access: field leadership + TOC staff
private _canOps = _isOmni || _isCmd || _isTocS3 || _isAuth;

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

uiNamespace setVariable ["ARC_console_tabIds", _tabIds];

// ---------------------------------------------------------------------------
// Select default tab (supports "forced tab" open requests from station addActions)
// ---------------------------------------------------------------------------
private _forceTab = uiNamespace getVariable ["ARC_console_forceTab", ""];
if (!(_forceTab isEqualType "")) then { _forceTab = ""; };
_forceTab = toUpper (trim _forceTab);

// Clear after consumption to avoid "sticky" tab forcing
uiNamespace setVariable ["ARC_console_forceTab", nil];

private _sel = 0;
if (_forceTab isNotEqualTo "") then
{
    private _i = _tabIds find _forceTab;
    if (_i >= 0) then { _sel = _i; };
};

if ((count _tabIds) > 0) then
{
    uiNamespace setVariable ["ARC_console_activeTab", _tabIds # _sel];
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
    _ctrlMain ctrlSetStructuredText parseText "<t size='1.05'>Loading...</t>";
};

// Initial paint
[_display] call ARC_fnc_uiConsoleRefresh;

// Refresh loop (rev-driven with polling fallback)
// Phase 2: stabilize UI repaint ordering by keying refresh off a monotonic server-published rev.
// The legacy periodic paint remains as a safety fallback.
uiNamespace setVariable ["ARC_console_refreshLoop", true];

// Lifecycle guard: ensure we never attach multiple refresh loops per dialog session.
private _attached = uiNamespace getVariable ["ARC_consoleHandlersAttached", false];
if (!(_attached isEqualType true)) then { _attached = false; };

if (!_attached) then
{
    uiNamespace setVariable ["ARC_consoleHandlersAttached", true];

    // Rev tracking (per-dialog session)
    uiNamespace setVariable ["ARC_consoleVM_lastRev", -1];
    uiNamespace setVariable ["ARC_consoleVM_pendingRev", -1];

    // Fallback cadence (seconds)
    uiNamespace setVariable ["ARC_consoleVM_fallbackIntervalS", 7];

    uiNamespace setVariable ["ARC_consoleVM_lastPaintAt", diag_tickTime];
    uiNamespace setVariable ["ARC_consoleVM_lastFallbackLogAt", -1000];
    uiNamespace setVariable ["ARC_consoleVM_lastIgnoreLogAt", -1000];

    diag_log format ["[FARABAD][v0][CONSOLE_VM][ATTACH][%1] handlers attached", diag_tickTime];

    // Spawn a single refresh loop and retain a handle for unload diagnostics.
    private _h = [_display] spawn
    {
        params ["_display"];

        while { !isNull _display && { dialog } && { uiNamespace getVariable ["ARC_console_refreshLoop", false] } } do
        {
            private _now = diag_tickTime;

            // Prevent the periodic paint from collapsing open dropdowns and interrupting text input.
            // Skip refresh while the user is focused on an Edit or Combo control.
            private _skip = false;
            private _fc = focusedCtrl _display;
            if (!isNull _fc) then
            {
                private _ct = ctrlType _fc;
                if (_ct in [2, 4]) then { _skip = true; }; // CT_EDIT=2, CT_COMBO=4
            };

            // Read published console meta rev (server-published). Payload is an array of [key,value] pairs.
            private _meta = missionNamespace getVariable ["ARC_consoleVM_meta", []];
            private _rev = -1;

            if (_meta isEqualType []) then
            {
                {
                    if (_x isEqualType [] && { (count _x) >= 2 } && { (toLower (_x # 0)) isEqualTo "rev" }) exitWith
                    {
                        _rev = _x # 1;
                    };
                } forEach _meta;
            };

            private _lastRev = uiNamespace getVariable ["ARC_consoleVM_lastRev", -1];
            if (!(_lastRev isEqualType 0)) then { _lastRev = -1; };

            private _pending = uiNamespace getVariable ["ARC_consoleVM_pendingRev", -1];
            if (!(_pending isEqualType 0)) then { _pending = -1; };

            // If the user is typing, capture the newest rev but don't repaint yet.
            if (_skip) then
            {
                if (_rev isEqualType 0 && { _rev > _pending }) then
                {
                    uiNamespace setVariable ["ARC_consoleVM_pendingRev", _rev];
                };
            }
            else
            {
                // Repaint on rev change (or pending rev).
                private _targetRev = _rev;
                if (_pending isEqualType 0 && { _pending > _targetRev }) then { _targetRev = _pending; };

                if (_targetRev isEqualType 0) then
                {
                    if (_targetRev > _lastRev) then
                    {
                        uiNamespace setVariable ["ARC_consoleVM_lastRev", _targetRev];
                        uiNamespace setVariable ["ARC_consoleVM_pendingRev", -1];

                        [_display] call ARC_fnc_uiConsoleRefresh;
                        uiNamespace setVariable ["ARC_consoleVM_lastPaintAt", _now];
                    }
                    else
                    {
                        // Ignore out-of-order meta revs (debug log throttled).
                        if (_targetRev >= 0 && { _targetRev < _lastRev }) then
                        {
                            private _lastLog = uiNamespace getVariable ["ARC_consoleVM_lastIgnoreLogAt", -1000];
                            if (!(_lastLog isEqualType 0)) then { _lastLog = -1000; };
                            if ((_now - _lastLog) > 2) then
                            {
                                uiNamespace setVariable ["ARC_consoleVM_lastIgnoreLogAt", _now];
                                diag_log format ["[FARABAD][v0][CONSOLE_VM][IGNORE][%1] rev=%2 lastRev=%3", _now, _targetRev, _lastRev];
                            };
                        };
                    };
                };

                // Safety fallback: repaint every N seconds even if rev meta isn't arriving.
                private _fb = uiNamespace getVariable ["ARC_consoleVM_fallbackIntervalS", 7];
                if (!(_fb isEqualType 0)) then { _fb = 7; };

                private _lp = uiNamespace getVariable ["ARC_consoleVM_lastPaintAt", _now];
                if (!(_lp isEqualType 0)) then { _lp = _now; };

                if ((_now - _lp) > _fb) then
                {
                    [_display] call ARC_fnc_uiConsoleRefresh;
                    uiNamespace setVariable ["ARC_consoleVM_lastPaintAt", _now];

                    // Throttle fallback logs.
                    private _lastFbLog = uiNamespace getVariable ["ARC_consoleVM_lastFallbackLogAt", -1000];
                    if (!(_lastFbLog isEqualType 0)) then { _lastFbLog = -1000; };
                    if ((_now - _lastFbLog) > _fb) then
                    {
                        uiNamespace setVariable ["ARC_consoleVM_lastFallbackLogAt", _now];
                        diag_log format ["[FARABAD][v0][CONSOLE_VM][FALLBACK][%1] lastRev=%2", _now, (uiNamespace getVariable ['ARC_consoleVM_lastRev', -1])];
                    };
                };
            };

            uiSleep 0.25;
        };
    };

    uiNamespace setVariable ["ARC_console_refreshHandle", _h];
};

true
