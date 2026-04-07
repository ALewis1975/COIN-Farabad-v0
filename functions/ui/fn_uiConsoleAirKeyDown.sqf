/*
    ARC_fnc_uiConsoleAirKeyDown

    Client: narrow key-down dispatcher for AIR / TOWER hotkeys.
    Registered on the console display only while the AIR tab is active.

    Hotkeys (active only when AIR tab is focused):
      H — Toggle HOLD / RELEASE departures
      R — RELEASE departures (explicit)
      E — APPROVE selected pending clearance (CLEARANCES submode)
      D — DENY selected pending clearance (CLEARANCES submode)
      M — Cycle AIR submode (AIRFIELD_OPS → CLEARANCES → DEBUG)

    All destructive actions require confirmation via
    ARC_console_airConfirmPending + Enter.

    Params:
      0: DISPLAY — the console display
      1: NUMBER  — DIK key code
      2: BOOL    — shift held
      3: BOOL    — ctrl held
      4: BOOL    — alt held

    Returns:
      BOOL — true to consume the key; false to pass through
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]],
    ["_dikCode", -1, [0]],
    ["_shift", false, [true]],
    ["_ctrl", false, [true]],
    ["_alt", false, [true]]
];

if (isNull _display) exitWith {false};

// Only active when AIR tab is focused.
private _tab = uiNamespace getVariable ["ARC_console_activeTab", ""];
if (!(_tab isEqualType "")) then { _tab = ""; };
if !(toUpper _tab isEqualTo "AIR") exitWith {false};

// Never consume modifier combos that might be Arma defaults.
// Shift alone is OK (Shift+H etc. is treated same as H for simplicity).
if (_shift && { _ctrl || _alt }) exitWith {false};
if (_ctrl || _alt) exitWith {false};

// DIK constants (Arma 3 / DirectInput)
// DIK_H = 0x23 (35), DIK_R = 0x13 (19), DIK_E = 0x12 (18),
// DIK_D = 0x20 (32), DIK_M = 0x32 (50), DIK_RETURN = 0x1C (28),
// DIK_NUMPADENTER = 0x9C (156), DIK_ESCAPE = 0x01 (1), DIK_Y = 0x15 (21)
private _DIK_H = 35;
private _DIK_R = 19;
private _DIK_E = 18;
private _DIK_D = 32;
private _DIK_M = 50;
private _DIK_RETURN = 28;
private _DIK_NUMPADENTER = 156;
private _DIK_ESCAPE = 1;
private _DIK_Y = 21;

// ---------------------------------------------------------------------------
// Confirmation flow helpers
// ---------------------------------------------------------------------------
private _pendingAction = uiNamespace getVariable ["ARC_console_airConfirmPending", ""];
if (!(_pendingAction isEqualType "")) then { _pendingAction = ""; };

private _clearConfirm = {
    uiNamespace setVariable ["ARC_console_airConfirmPending", ""];
    uiNamespace setVariable ["ARC_console_airConfirmLabel", ""];
};

// Enter / Y = confirm pending action
if (_pendingAction != "" && { _dikCode in [_DIK_RETURN, _DIK_NUMPADENTER, _DIK_Y] }) exitWith {
    // Execute the confirmed action
    switch (_pendingAction) do
    {
        case "HOLD": {
            [] call ARC_fnc_airbaseClientRequestHoldDepartures;
            ["AIR", "HOLD confirmed — departures held."] call ARC_fnc_clientToast;
        };
        case "RELEASE": {
            [] call ARC_fnc_airbaseClientRequestReleaseDepartures;
            ["AIR", "RELEASE confirmed — departures released."] call ARC_fnc_clientToast;
        };
        case "DENY": {
            private _rid = uiNamespace getVariable ["ARC_console_airConfirmRid", ""];
            if (!(_rid isEqualType "")) then { _rid = ""; };
            if (_rid != "") then {
                [_rid, false, "UI_KEY_DENY_CONFIRMED"] call ARC_fnc_airbaseClientRequestClearanceDecision;
                ["AIR", format ["DENY confirmed: %1", _rid]] call ARC_fnc_clientToast;
            };
            uiNamespace setVariable ["ARC_console_airConfirmRid", ""];
        };
        case "CANCEL_FLIGHT": {
            private _fid = uiNamespace getVariable ["ARC_console_airConfirmFid", ""];
            if (!(_fid isEqualType "")) then { _fid = ""; };
            if (_fid != "") then {
                [_fid] call ARC_fnc_airbaseClientRequestCancelQueuedFlight;
                ["AIR", format ["CANCEL confirmed: %1", _fid]] call ARC_fnc_clientToast;
            };
            uiNamespace setVariable ["ARC_console_airConfirmFid", ""];
        };
    };
    [] call _clearConfirm;
    [_display] call ARC_fnc_uiConsoleRefresh;
    true
};

// Escape = cancel pending confirmation
if (_pendingAction != "" && { _dikCode isEqualTo _DIK_ESCAPE }) exitWith {
    [] call _clearConfirm;
    ["AIR", "Confirmation cancelled."] call ARC_fnc_clientToast;
    [_display] call ARC_fnc_uiConsoleRefresh;
    true
};

// If a confirmation is pending, consume all other keys (don't let them act).
if (_pendingAction != "") exitWith {true};

// ---------------------------------------------------------------------------
// Normal (no pending confirmation) key dispatch
// ---------------------------------------------------------------------------
private _airMode = uiNamespace getVariable ["ARC_console_airMode", "TOWER"];
if (!(_airMode isEqualType "")) then { _airMode = "TOWER"; };
_airMode = toUpper _airMode;

// PILOT mode: no tower hotkeys
if (_airMode isEqualTo "PILOT") exitWith {false};

private _airSubmode = uiNamespace getVariable ["ARC_console_airSubmode", "AIRFIELD_OPS"];
if (!(_airSubmode isEqualType "")) then { _airSubmode = "AIRFIELD_OPS"; };
_airSubmode = toUpper _airSubmode;

// --- H: Toggle HOLD / RELEASE ---
if (_dikCode isEqualTo _DIK_H) exitWith {
    private _canHR = uiNamespace getVariable ["ARC_console_airCanHoldRelease", false];
    if (!(_canHR isEqualType true) && !(_canHR isEqualType false)) then { _canHR = false; };
    if (!_canHR) exitWith {
        ["AIR", "READ-ONLY: no hold/release authority."] call ARC_fnc_clientToast;
        true
    };

    private _holdState = uiNamespace getVariable ["ARC_console_airHoldDepartures", false];
    if (!(_holdState isEqualType true) && !(_holdState isEqualType false)) then { _holdState = false; };

    private _action = if (_holdState) then {"RELEASE"} else {"HOLD"};
    private _label = if (_holdState) then {
        "Press ENTER or Y to confirm RELEASE departures, ESC to cancel."
    } else {
        "Press ENTER or Y to confirm HOLD departures, ESC to cancel."
    };

    uiNamespace setVariable ["ARC_console_airConfirmPending", _action];
    uiNamespace setVariable ["ARC_console_airConfirmLabel", _label];
    ["AIR", _label] call ARC_fnc_clientToast;
    true
};

// --- R: Explicit RELEASE ---
if (_dikCode isEqualTo _DIK_R) exitWith {
    private _canRelease = uiNamespace getVariable ["ARC_console_airCanRelease", false];
    if (!(_canRelease isEqualType true) && !(_canRelease isEqualType false)) then { _canRelease = false; };
    if (!_canRelease) exitWith {
        ["AIR", "READ-ONLY: no release authority."] call ARC_fnc_clientToast;
        true
    };

    uiNamespace setVariable ["ARC_console_airConfirmPending", "RELEASE"];
    uiNamespace setVariable ["ARC_console_airConfirmLabel", "Press ENTER or Y to confirm RELEASE departures, ESC to cancel."];
    ["AIR", "Press ENTER or Y to confirm RELEASE departures, ESC to cancel."] call ARC_fnc_clientToast;
    true
};

// --- E: APPROVE selected clearance request (CLEARANCES submode only) ---
if (_dikCode isEqualTo _DIK_E && { _airSubmode isEqualTo "CLEARANCES" }) exitWith {
    // Non-destructive: approve fires immediately (no confirmation needed)
    [_display] call ARC_fnc_uiConsoleActionAirPrimary;
    true
};

// --- D: DENY selected clearance request (CLEARANCES submode only) ---
if (_dikCode isEqualTo _DIK_D && { _airSubmode isEqualTo "CLEARANCES" }) exitWith {
    // Destructive: DENY requires confirmation
    private _ctrlList = _display displayCtrl 78011;
    private _sel = if (!isNull _ctrlList) then { lbCurSel _ctrlList } else { -1 };
    private _data = if (_sel >= 0 && { !isNull _ctrlList }) then { _ctrlList lbData _sel } else { "" };
    if (!(_data isEqualType "")) then { _data = ""; };
    private _parts = _data splitString "|";
    private _rowType = toUpper (_parts param [0, ""]);

    if !(_rowType isEqualTo "REQ") exitWith {
        ["AIR", "Select a pending clearance request to deny."] call ARC_fnc_clientToast;
        true
    };

    private _rid = _parts param [1, ""];
    if (_rid isEqualTo "" || { _rid isEqualTo "NONE" }) exitWith {
        ["AIR", "Select a valid pending clearance request to deny."] call ARC_fnc_clientToast;
        true
    };

    private _canQM = uiNamespace getVariable ["ARC_console_airCanQueueManage", false];
    if (!(_canQM isEqualType true) && !(_canQM isEqualType false)) then { _canQM = false; };
    if (!_canQM) exitWith {
        ["AIR", "READ-ONLY: no queue authorization for denials."] call ARC_fnc_clientToast;
        true
    };

    uiNamespace setVariable ["ARC_console_airConfirmPending", "DENY"];
    uiNamespace setVariable ["ARC_console_airConfirmRid", _rid];
    uiNamespace setVariable ["ARC_console_airConfirmLabel", format ["Press ENTER or Y to DENY %1, ESC to cancel.", _rid]];
    ["AIR", format ["Press ENTER or Y to DENY %1, ESC to cancel.", _rid]] call ARC_fnc_clientToast;
    true
};

// --- M: Cycle submode ---
if (_dikCode isEqualTo _DIK_M) exitWith {
    [_display] call ARC_fnc_uiConsoleActionAirSecondary;
    true
};

// Key not consumed — pass through to Arma
false
