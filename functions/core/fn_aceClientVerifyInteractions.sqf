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
    private _ready = false;

    waitUntil {
        private _hasAceMain = isClass (configFile >> "CfgPatches" >> "ace_main");
        private _hasAceInteract = isClass (configFile >> "CfgPatches" >> "ace_interact_menu");
        private _hasCreate = !isNil "ace_interact_menu_fnc_createAction";
        private _hasAttach = !isNil "ace_interact_menu_fnc_addActionToObject";

        _ready = _hasAceMain && { _hasAceInteract } && { _hasCreate } && { _hasAttach };
        _ready || { (diag_tickTime - _startedAt) >= _timeoutS }
    };

    uiNamespace setVariable ["ARC_aceInteractionsReady", _ready];
    missionNamespace setVariable ["ARC_aceInteractionsReadyClient", _ready];
    uiNamespace setVariable ["ARC_aceInteractionVerifyRunning", false];

    if (_ready) then
    {
        diag_log format [
            "[ARC][ACE][INFO] ACE interaction framework ready after %1s; vanillaAddActions=%2 tocAce=%3 rtbAce=%4 civsubAce=%5",
            round (diag_tickTime - _startedAt),
            missionNamespace getVariable ["ARC_vanillaAddActionsEnabled", false],
            missionNamespace getVariable ["ARC_tocAceInteractionsEnabled", true],
            missionNamespace getVariable ["ARC_rtbAceInteractionsEnabled", true],
            missionNamespace getVariable ["ARC_civsubAceInteractionsEnabled", true]
        ];
    }
    else
    {
        diag_log format [
            "[ARC][ACE][WARN] ACE interaction framework not ready after %1s required=%2 ace_main=%3 ace_interact_menu=%4 createAction=%5 addActionToObject=%6",
            _timeoutS,
            _required,
            isClass (configFile >> "CfgPatches" >> "ace_main"),
            isClass (configFile >> "CfgPatches" >> "ace_interact_menu"),
            !isNil "ace_interact_menu_fnc_createAction",
            !isNil "ace_interact_menu_fnc_addActionToObject"
        ];
    };
};

true
