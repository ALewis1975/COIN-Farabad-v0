/*
    ARC_fnc_intelInitClient

    Client-side intel layer init.

    Keeps client-side addAction wiring for intel/RTB interactions.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// Prevent double-init per player object.
// NOTE: on respawn Arma creates a new player unit; this allows re-running to reattach actions.
if (player getVariable ["ARC_intelInitClient_done", false]) exitWith {true};
player setVariable ["ARC_intelInitClient_done", true];


// ---------------------------------------------------------------------------
// Intel Debrief station interaction (RTB purpose INTEL)
// ---------------------------------------------------------------------------
// Supports Eden variable names:
//   - arc_intel_bebrief (legacy / common typo)
//   - arc_intel_debrief
//   - ARC_toc_intel_1 (S2 screen)
//   - ARC_toc_intel_2 (S2 screen alt)
//   - arc_toc_intel_1 (legacy)
[] spawn {
    uiSleep 1;

    // Stations can be missing on JIP for a moment. Retry briefly.
    private _names = [
        "arc_intel_bebrief", "arc_intel_debrief",
        "ARC_intel_bebrief", "ARC_intel_debrief",
        "ARC_toc_intel_1", "ARC_toc_intel_2",
        "arc_toc_intel_1", "arc_toc_intel_2"
    ];
    private _stations = [];
    private _foundNames = [];
    for "_i" from 1 to 20 do
    {
        _stations = [];
        _foundNames = [];
        {
            private _o = missionNamespace getVariable [_x, objNull];
            if (!isNull _o) then { _stations pushBackUnique _o; _foundNames pushBackUnique _x; };
        } forEach _names;

        if ((count _stations) > 0) exitWith {};
        uiSleep 1;
    };

    if ((count _stations) isEqualTo 0) exitWith {
        diag_log "[ARC][INTEL] No Intel debrief station objects found on client. Fallback self-action will still be available near destination.";
    };

    diag_log format ["[ARC][INTEL] Debrief station resolve: foundNames=%1 countStations=%2", _foundNames, count _stations];

    {
        private _station = _x;
        private _nid = netId _station;
        private _key = if (_nid isEqualTo "") then { "ARC_debriefAct_station" } else { format ["ARC_debriefAct_%1", _nid] };

        // Idempotent: if we already added the action, ensure it still exists (actions can be cleared).
        private _old = missionNamespace getVariable [_key, -1];
        if (_old isEqualType 0 && { _old >= 0 }) then
        {
            if (_old in (actionIDs _station)) then
            {
                continue;
            }
            else
            {
                _station removeAction _old;
            };
        };

        private _aid = _station addAction [
            "Intel Debrief (Complete RTB - INTEL)",
            {
                params ["_target", "_caller", "_actionId", "_args"]; 
                [_target, _caller] call ARC_fnc_intelClientDebriefIntel;
            },
            [],
            1.5,
            true,
            true,
            "",
            // RTB(INTEL) is group-scoped; allow any group member to submit the debrief.
            "[_this] call ARC_fnc_intelClientHasAcceptedRtbIntel",
            6
        ];

        missionNamespace setVariable [_key, _aid];
        diag_log format ["[ARC][INTEL] Added debrief action to station type=%1 netId=%2 pos=%3", typeOf _station, netId _station, getPosATL _station];
    } forEach _stations;
};


// ---------------------------------------------------------------------------
// Intel fallback self-action (prevents RTB(INTEL) deadlocks)
// ---------------------------------------------------------------------------
// Adds a player-scoped action that appears only when:
//   - the player's group has an accepted RTB(INTEL)
//   - the player is near the RTB destination
// This prevents deadlocks if the station object variable is missing on clients.
[] spawn {
    uiSleep 1;

    private _key = "ARC_intelAct_self";
    private _old = missionNamespace getVariable [_key, -1];
    if (_old isEqualType 0 && { _old >= 0 }) then
    {
        if (_old in (actionIDs player)) exitWith {};
        player removeAction _old;
    };

    private _aid = player addAction [
        "Intel Debrief (Complete RTB - INTEL) [Fallback]",
        {
            params ["_target", "_caller", "_actionId", "_args"]; 
            [objNull, _caller] call ARC_fnc_intelClientDebriefIntel;
        },
        [],
        1.2,
        false,
        true,
        "",
        "alive _this && {[_this] call ARC_fnc_intelClientCanDebriefIntelHere}",
        3
    ];

    missionNamespace setVariable [_key, _aid];
    diag_log "[ARC][INTEL] Added fallback self-action for Intel debrief.";
};


// ---------------------------------------------------------------------------
// EPW processing interaction (RTB purpose EPW)
// ---------------------------------------------------------------------------
// Supported Eden variable names:
//   - sheriff_handling (preferred)
//   - EPW_Porcessing (current Eden var typo)
//   - EPW_Processing (legacy)
//   - EPW_Processing_Building (fallback)
[] spawn {
    uiSleep 1;

    private _names = ["sheriff_handling", "EPW_Porcessing", "EPW_Processing", "EPW_Processing_Building"];
    private _stations = [];

    // Stations can be missing on JIP for a moment. Retry briefly.
    for "_i" from 1 to 20 do
    {
        _stations = [];
        {
            private _o = missionNamespace getVariable [_x, objNull];
            if (!isNull _o) then { _stations pushBackUnique _o; };
        } forEach _names;

        if ((count _stations) > 0) exitWith {};
        uiSleep 1;
    };

    if ((count _stations) isEqualTo 0) exitWith {
        diag_log "[ARC][EPW] No EPW processing station objects found on client. Fallback self-action will still be available near destination.";
    };

    {
        private _station = _x;
        private _nid = netId _station;
        private _key = if (_nid isEqualTo "") then { "ARC_epwAct_station" } else { format ["ARC_epwAct_%1", _nid] };

        // Idempotent: if we already added the action, ensure it still exists.
        private _old = missionNamespace getVariable [_key, -1];
        if (_old isEqualType 0 && { _old >= 0 }) then
        {
            if (_old in (actionIDs _station)) then
            {
                continue;
            }
            else
            {
                _station removeAction _old;
            };
        };

        private _aid = _station addAction [
            "Process EPW (Complete RTB - EPW)",
            {
                params ["_target", "_caller", "_actionId", "_args"]; 
                [_target, _caller] call ARC_fnc_intelClientProcessEpw;
            },
            [],
            1.4,
            true,
            true,
            "",
            // Slightly larger radius than debrief; players may park a vehicle inside the building.
            "(_this distance _target < 6) && {(damage _target) < 0.95} && {[_this] call ARC_fnc_intelClientHasAcceptedRtbEpw}",
            6
        ];

        diag_log format ["[ARC][EPW] Added processing action to station %1 (%2)", _station, netId _station];
        missionNamespace setVariable [_key, _aid];
    } forEach _stations;
};


// ---------------------------------------------------------------------------
// EPW fallback self-action
// ---------------------------------------------------------------------------
// Adds a player-scoped action that appears only when:
//   - the player's group has an accepted RTB(EPW)
//   - the player is near the RTB destination
// This prevents deadlocks if the station object variable is missing on clients.
[] spawn {
    uiSleep 1;

    private _key = "ARC_epwAct_self";
    private _old = missionNamespace getVariable [_key, -1];
    if (_old isEqualType 0 && { _old >= 0 }) then
    {
        if (_old in (actionIDs player)) exitWith {};
        player removeAction _old;
    };

    private _aid = player addAction [
        "Process EPW (Complete RTB - EPW) [Fallback]",
        {
            params ["_target", "_caller", "_actionId", "_args"]; 
            [objNull, _caller] call ARC_fnc_intelClientProcessEpw;
        },
        [],
        1.2,
        false,
        true,
        "",
        "alive _this && {[_this] call ARC_fnc_intelClientCanProcessEpwHere}",
        3
    ];

    missionNamespace setVariable [_key, _aid];
    diag_log "[ARC][EPW] Added fallback self-action for EPW processing.";
};


// ---------------------------------------------------------------------------
// ACE3: add matching self-interact actions (solves cases where players don't use the vanilla action menu)
// ---------------------------------------------------------------------------
[] spawn {
    uiSleep 2;

    // Only run if ACE interact menu is present
    if (isNil "ace_interact_menu_fnc_createAction" || { isNil "ace_interact_menu_fnc_addActionToObject" }) exitWith {};

    if (player getVariable ["ARC_aceRtbActionsAdded", false]) exitWith {};
    player setVariable ["ARC_aceRtbActionsAdded", true];

    // Intel Debrief (RTB INTEL)
    private _aIntel = [
        "ARC_RTB_INTEL_DEBRIEF",
        "ARC: Intel Debrief (RTB)",
        "",
        {
            params ["_target", "_player", "_params"];
            [objNull, _player] call ARC_fnc_intelClientDebriefIntel;
        },
        {
            params ["_target", "_player", "_params"];
            alive _player && { [_player] call ARC_fnc_intelClientCanDebriefIntelHere }
        }
    ] call ace_interact_menu_fnc_createAction;
    [player, 1, ["ACE_SelfActions"], _aIntel] call ace_interact_menu_fnc_addActionToObject;

    // Process EPW (RTB EPW)
    private _aEpw = [
        "ARC_RTB_EPW_PROCESS",
        "ARC: Process EPW (RTB)",
        "",
        {
            params ["_target", "_player", "_params"];
            [objNull, _player] call ARC_fnc_intelClientProcessEpw;
        },
        {
            params ["_target", "_player", "_params"];
            alive _player && { [_player] call ARC_fnc_intelClientCanProcessEpwHere }
        }
    ] call ace_interact_menu_fnc_createAction;
    [player, 1, ["ACE_SelfActions"], _aEpw] call ace_interact_menu_fnc_addActionToObject;

    diag_log "[ARC][ACE] Added RTB Intel/EPW ACE self-interact actions.";
};


true
