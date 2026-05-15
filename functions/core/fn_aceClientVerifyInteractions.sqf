/*
    ARC_fnc_aceClientVerifyInteractions

    Client: verify ACE interaction framework availability and emit RPT
    breadcrumbs for mission interaction readiness.

    Returns:
        BOOL
*/

if (!hasInterface) exitWith {false};

if (uiNamespace getVariable ["ARC_aceInteractionVerifyRunning", false]) exitWith {true};
uiNamespace setVariable ["ARC_aceInteractionVerifyRunning", true];

[] spawn {
    private _timeoutS = missionNamespace getVariable ["ARC_aceInteractionReadyTimeoutS", 45];
    if (!(_timeoutS isEqualType 0)) then { _timeoutS = 45; };
    _timeoutS = (_timeoutS max 5) min 120;

    private _required = missionNamespace getVariable ["ARC_aceInteractionsRequired", true];
    if (!(_required isEqualType true) && !(_required isEqualType false)) then { _required = true; };

    private _startedAt = diag_tickTime;
    private _ready = [] call ARC_fnc_aceClientWaitInteractionsReady;
    uiNamespace setVariable ["ARC_aceInteractionVerifyRunning", false];

    if (_ready) then
    {
        diag_log format [
            "[ARC][ACE][INFO] ACE interaction framework ready after %1s; cbaSettings=%2 vanillaAddActions=%3 tocAce=%4 rtbAce=%5 civsubAce=%6",
            round (diag_tickTime - _startedAt),
            uiNamespace getVariable ["ARC_cbaSettingsInitializedObserved", false],
            missionNamespace getVariable ["ARC_vanillaAddActionsEnabled", false],
            missionNamespace getVariable ["ARC_tocAceInteractionsEnabled", true],
            missionNamespace getVariable ["ARC_rtbAceInteractionsEnabled", true],
            missionNamespace getVariable ["ARC_civsubAceInteractionsEnabled", true]
        ];
    }
    else
    {
        diag_log format [
            "[ARC][ACE][WARN] ACE interaction framework not ready after %1s required=%2 cbaSettings=%3 ace_main=%4 ace_interact_menu=%5 createAction=%6 addActionToObject=%7",
            _timeoutS,
            _required,
            uiNamespace getVariable ["ARC_cbaSettingsInitializedObserved", false],
            isClass (configFile >> "CfgPatches" >> "ace_main"),
            isClass (configFile >> "CfgPatches" >> "ace_interact_menu"),
            !isNil "ace_interact_menu_fnc_createAction",
            !isNil "ace_interact_menu_fnc_addActionToObject"
        ];
    };
};

true
