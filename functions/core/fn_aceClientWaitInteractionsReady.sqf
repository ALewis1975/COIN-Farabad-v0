/*
    ARC_fnc_aceClientWaitInteractionsReady

    Client scheduled helper: waits until CBA settings have initialized and
    ACE interact menu registration functions are available.

    Returns:
        BOOL
*/

if (!hasInterface) exitWith {false};

private _timeoutS = missionNamespace getVariable ["ARC_aceInteractionReadyTimeoutS", 45];
if (!(_timeoutS isEqualType 0)) then { _timeoutS = 45; };
_timeoutS = (_timeoutS max 5) min 120;

private _registerCbaSettingsHandler = {
    if (!(uiNamespace getVariable ["ARC_cbaSettingsInitializedHandlerAdded", false]) && { !isNil "CBA_fnc_addEventHandler" }) then
    {
        uiNamespace setVariable ["ARC_cbaSettingsInitializedHandlerAdded", true];
        ["CBA_settingsInitialized", {
            uiNamespace setVariable ["ARC_cbaSettingsInitializedObserved", true];
            missionNamespace setVariable ["ARC_cbaSettingsInitializedObservedClient", true];
            diag_log "[ARC][ACE][INFO] CBA_settingsInitialized observed; ACE interaction registration unlocked.";
        }] call CBA_fnc_addEventHandler;
    };
};

[] call _registerCbaSettingsHandler;

private _startedAt = diag_tickTime;
private _ready = false;

waitUntil {
    [] call _registerCbaSettingsHandler;

    private _cbaObserved = uiNamespace getVariable ["ARC_cbaSettingsInitializedObserved", false];
    if (!_cbaObserved) then
    {
        private _cbaReadyRaw = missionNamespace getVariable ["cba_settings_ready", false];
        if ((_cbaReadyRaw isEqualType true) && { _cbaReadyRaw }) then
        {
            _cbaObserved = true;
            uiNamespace setVariable ["ARC_cbaSettingsInitializedObserved", true];
            missionNamespace setVariable ["ARC_cbaSettingsInitializedObservedClient", true];
        };
    };

    private _hasAceMain = isClass (configFile >> "CfgPatches" >> "ace_main");
    private _hasAceInteract = isClass (configFile >> "CfgPatches" >> "ace_interact_menu");
    private _hasCreate = !isNil "ace_interact_menu_fnc_createAction";
    private _hasAttach = !isNil "ace_interact_menu_fnc_addActionToObject";

    _ready = _cbaObserved && { _hasAceMain } && { _hasAceInteract } && { _hasCreate } && { _hasAttach };
    _ready || { (diag_tickTime - _startedAt) >= _timeoutS }
};

uiNamespace setVariable ["ARC_aceInteractionsReady", _ready];
missionNamespace setVariable ["ARC_aceInteractionsReadyClient", _ready];

_ready
