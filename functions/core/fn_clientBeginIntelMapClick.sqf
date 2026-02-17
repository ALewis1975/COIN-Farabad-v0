/*
    Client helper: open map and capture a single click to log an intel point.

    Params:
        0: STRING - category (e.g., "SIGHTING", "HUMINT")
*/

if (!hasInterface) exitWith {false};

params ["_category"];
if (_category isEqualTo "") then { _category = "SIGHTING"; };

// Prompt for human-readable text first (prevents generic "reported HUMINT" entries)
private _p = [_category, "", ""] call ARC_fnc_clientIntelPrompt;
_p params ["_ok", "_sum", "_det"];
if (!_ok) exitWith { hint "Intel report canceled."; false };

if (_sum isEqualTo "") then
{
    _sum = "No details provided.";
};

missionNamespace setVariable ["ARC_pendingIntelCategory", toUpper _category];
missionNamespace setVariable ["ARC_pendingIntelSummary", _sum];
missionNamespace setVariable ["ARC_pendingIntelDetails", _det];

// If the Farabad Console is open, close it so map clicks can register, then re-open once the map closes.
private _reopenConsole = false;
private _reopenTab = "INTEL";
private _consoleDisp = uiNamespace getVariable ["ARC_console_display", displayNull];
if (isNull _consoleDisp) then { _consoleDisp = findDisplay 78000; };
if (!isNull _consoleDisp) then
{
    _reopenConsole = true;
    _reopenTab = uiNamespace getVariable ["ARC_console_activeTab", "INTEL"];
    uiNamespace setVariable ["ARC_console_reopenAfterMap", true];
    uiNamespace setVariable ["ARC_console_reopenTab", _reopenTab];
    closeDialog 0;
};

if (_reopenConsole) then
{
    [] spawn
    {
        // Wait for map open, then wait for map close (Esc or click flow).
        waitUntil { uiSleep 0.05; visibleMap };
        waitUntil { uiSleep 0.05; !visibleMap };
        uiSleep 0.05;

        if (uiNamespace getVariable ["ARC_console_reopenAfterMap", false]) then
        {
            private _tab = uiNamespace getVariable ["ARC_console_reopenTab", "INTEL"];
            uiNamespace setVariable ["ARC_console_reopenAfterMap", false];
            // Re-open on the same tab without calling the listbox handler directly.
            uiNamespace setVariable ["ARC_console_forceTab", _tab];
            [] call ARC_fnc_uiConsoleOpen;
        };
    };
};

openMap true;
waitUntil { uiSleep 0.05; visibleMap };
hint format ["Intel Logging: %1\nClick a position on the map to submit.", toUpper _category];

onMapSingleClick
{
    // Derive click position from handler args (onMapSingleClick with CODE uses _this).
    private _args = _this;
    private _pos = [];
    if (_args isEqualType [] && { (count _args) >= 2 }) then { _pos = _args # 1; };
    if (!(_pos isEqualType []) || { (count _pos) < 2 }) exitWith
    {
        // Cleanup and abort (prevents persistent handler).
        onMapSingleClick "";
        openMap false;
        missionNamespace setVariable ["ARC_pendingIntelCategory", nil];
        missionNamespace setVariable ["ARC_pendingIntelSummary", nil];
        missionNamespace setVariable ["ARC_pendingIntelDetails", nil];
        hint "Intel Logging failed: invalid map click position.";
        false
    };
    private _cat = missionNamespace getVariable ["ARC_pendingIntelCategory", "SIGHTING"];
    missionNamespace setVariable ["ARC_pendingIntelCategory", nil];

    private _sum = missionNamespace getVariable ["ARC_pendingIntelSummary", "No details provided."];
    private _det = missionNamespace getVariable ["ARC_pendingIntelDetails", ""];
    missionNamespace setVariable ["ARC_pendingIntelSummary", nil];
    missionNamespace setVariable ["ARC_pendingIntelDetails", nil];

    // Cleanup first (prevents double-submits)
    onMapSingleClick "";

    private _reporter = name player;

    [player, _reporter, _cat, _pos, _sum, _det] remoteExec ["ARC_fnc_tocRequestLogIntel", 2];

    openMap false;

    hint format ["Submitted intel (%1) at %2.", _cat, mapGridPosition _pos];
    true
};

true