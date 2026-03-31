/*
    ARC_fnc_civsubContactDialogOpen

    Client-side: Opens the standalone CIVSUB Interact dialog.

    Uses the dedicated ARC_CivsubInteractDialog (IDD 78300) with Actions list,
    Questions list, and Response pane.  Falls back to the Farabad Console INTEL tab
    only when the dialog cannot be created (e.g. another exclusive dialog is blocking).

    Params:
      0: civ unit (object)
*/
if (!hasInterface) exitWith {false};

params [
    ["_civ", objNull, [objNull]]
];
if (isNull _civ) exitWith {false};

// Store interaction target first so the dialog onLoad can read it immediately.
uiNamespace setVariable ["ARC_civsubInteract_target", _civ];

// Clear stale state from any previous session.
uiNamespace setVariable ["ARC_civsubInteract_hasUserOutput", false];
uiNamespace setVariable ["ARC_civsubInteract_actionInProgress", false];
uiNamespace setVariable ["ARC_civsubInteract_ehBound", false];
uiNamespace setVariable ["ARC_civsubInteract_initializing", true];
uiNamespace setVariable ["ARC_civsubInteract_idCardHtml", ""];
uiNamespace setVariable ["ARC_civsubInteract_snapshot", createHashMap];
uiNamespace setVariable ["ARC_civsubInteract_lastResultType", ""];
uiNamespace setVariable ["ARC_civsubInteract_selectedQid", ""];

// Open the standalone interact dialog if not already open (IDD 78300).
// The dialog onLoad sets ARC_civsubInteract_display and calls fn_civsubContactDialogOnLoad,
// which populates controls and requests a snapshot from the server.
private _d = findDisplay 78300;
if (isNull _d) then
{
    createDialog "ARC_CivsubInteractDialog";
    // Verify the dialog opened; fall back to console INTEL tab on failure.
    _d = findDisplay 78300;
    if (isNull _d) then
    {
        diag_log "[CIVSUB][UI] fn_civsubContactDialogOpen: createDialog failed; falling back to console INTEL tab.";
        uiNamespace setVariable ["ARC_console_forceTab", "INTEL"];
        private _console = findDisplay 78000;
        if (isNull _console) then
        {
            private _opened = [] call ARC_fnc_uiConsoleOpen;
            if (!_opened) exitWith
            {
                uiNamespace setVariable ["ARC_civsubInteract_target", objNull];
                uiNamespace setVariable ["ARC_console_forceTab", nil];
                false
            };
        }
        else
        {
            uiNamespace setVariable ["ARC_console_activeTab", "INTEL"];
            [_console] call ARC_fnc_uiConsoleRefresh;
        };
        // Snapshot is requested by fn_civsubContactDialogOnLoad, but since we fell back
        // to the console route (which does not fire onLoad), request it explicitly.
        [_civ, player] remoteExecCall ["ARC_fnc_civsubContactReqSnapshot", 2];
    };
    // Normal path: dialog's onLoad will request the snapshot via fn_civsubContactDialogOnLoad.
}
else
{
    // Dialog already open — re-populate for the new civ target.
    [_d] call ARC_fnc_civsubContactDialogOnLoad;
};

true
