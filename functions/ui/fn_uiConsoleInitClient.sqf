/*
    ARC_fnc_uiConsoleInitClient

    Client: registers the Farabad Console keybind (CBA) and sets up
    lightweight client-side defaults.

    Default keybind: L-CTRL + L-SHIFT + T
    (Players can rebind in Options > Controls > Addon Options > CBA Keybinds.)

    Notes:
      - We do not rely on addAction/ACE interactions to open the console.
      - Tabs/actions inside the console still enforce role + server validation.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// For readable DIK codes (used in CBA keybind defaults)
#include "\a3\ui_f\hpp\defineDIKCodes.inc"

// Avoid double init on JIP or respawn frameworks.
if (missionNamespace getVariable ["ARC_console_keybindInit", false]) exitWith {true};
missionNamespace setVariable ["ARC_console_keybindInit", true];

// Defaults (can be overridden from initServer/initPlayerLocal before this runs)
if (isNil { missionNamespace getVariable "ARC_consoleRequiredItems" }) then
{
    missionNamespace setVariable ["ARC_consoleRequiredItems", ["ItemcTab", "ItemAndroid", "ItemcTabHCam", "ItemMicroDAGR", "ACE_DAGR"]];
};

if (isNil { missionNamespace getVariable "ARC_consoleOmniTokens" }) then
{
    missionNamespace setVariable ["ARC_consoleOmniTokens", ["OMNI"]];
};

// Optional: terminal access for players without a tablet.
// If the player is near one of these terminals (or the mobile ops vehicle), allow console access.
// Eden naming convention: keep tower terminals named `tower_screen_01` and `tower_screen_02`
// so client terminal proximity remains aligned with the active station layout.
if (isNil { missionNamespace getVariable "ARC_consoleTerminalVarNames" }) then
{
    missionNamespace setVariable ["ARC_consoleTerminalVarNames", [
        "arc_intel_bebrief",
        "ARC_toc_intel_1", "ARC_toc_intel_2",
        "ARC_toc_ops_1", "ARC_toc_ops_2", "ARC_toc_ops_3", "ARC_toc_ops_4",
        "ARC_toc_screen_1", "ARC_toc_screen_2", "ARC_toc_screen_3",
        "tower_screen_01", "tower_screen_02"
    ]];
};

if (isNil { missionNamespace getVariable "ARC_consoleTerminalRadiusM" }) then
{
    // Tight on purpose: console access should feel like you are at the station.
    missionNamespace setVariable ["ARC_consoleTerminalRadiusM", 4];
};

if (isNil { missionNamespace getVariable "ARC_consoleTerminalMarkers" }) then
{
    missionNamespace setVariable ["ARC_consoleTerminalMarkers", ["ARC_m_base_toc"]];
};

if (isNil { missionNamespace getVariable "ARC_consoleTerminalMarkerRadiusM" }) then
{
    // Marker fallback should not allow opening from across the TOC.
    missionNamespace setVariable ["ARC_consoleTerminalMarkerRadiusM", 5];
};

if (isNil { missionNamespace getVariable "ARC_consoleMobileTerminalVarNames" }) then
{
    missionNamespace setVariable ["ARC_consoleMobileTerminalVarNames", ["remote_ops_vehicle"]];
};

if (isNil { missionNamespace getVariable "ARC_consoleMobileTerminalRadiusM" }) then
{
    // Mobile ops terminal access should require standing near the vehicle.
    missionNamespace setVariable ["ARC_consoleMobileTerminalRadiusM", 5];
};

[] spawn {
    // Wait until player exists (initPlayerLocal order can vary under heavy modsets)
    waitUntil { !isNull player };

    // Wait for CBA keybinding system (best-effort)
    private _t0 = diag_tickTime;
    waitUntil { !isNil "CBA_fnc_addKeybind" || { (diag_tickTime - _t0) > 15 } };

    if (isNil "CBA_fnc_addKeybind") exitWith
    {
        diag_log "[ARC][CONSOLE] CBA_fnc_addKeybind not found; console keybind not registered.";
    };

    // Register keybind (safe to call multiple times; CBA updates existing entry)
    private _defaultKey = [DIK_T, [true, true, false]]; // Ctrl+Shift+T

    [
        "ARC",
        "ARC_openFarabadConsole",
        ["Open Farabad Console", "Open the COIN console (tablet or terminal access)."],
        { [] call ARC_fnc_uiConsoleOpen; },
        {},
        _defaultKey,
        false,
        0,
        false
    ] call CBA_fnc_addKeybind;

    diag_log "[ARC][CONSOLE] Keybind registered: Open Farabad Console (default Ctrl+Shift+T).";
};

true
