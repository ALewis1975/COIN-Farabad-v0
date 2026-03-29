/*
    ARC_fnc_airbaseTowerAuthorize

    Authorize airbase tower control actions by groupId/roleDescription tokens.

    Params:
      0: OBJECT unit
      1: STRING action token (HOLD|RELEASE|PRIORITIZE|CANCEL|APPROVE|DENY|OVERRIDE|STAFF)

    Returns:
      ARRAY [BOOL authorized, STRING level, STRING reason]
      - level: "CCIC" | "LC" | ""
*/

params [
    ["_unit", objNull, [objNull]],
    ["_action", "", [""]]
];

private _towerAuthDebug = missionNamespace getVariable ["airbase_v1_tower_authDebug", false];
if (!(_towerAuthDebug isEqualType true) && !(_towerAuthDebug isEqualType false)) then { _towerAuthDebug = false; };

private _normalizeAuthText = {
    params [["_text", "", [""]]];

    if (!(_text isEqualType "")) then { _text = ""; };

    private _parts = ((toUpper (trim _text)) splitString (" .:-_/" + toString [9,10,13])) select {
        !(_x isEqualTo "")
    };
    _parts joinString " "
};

private _logAuthDeny = {
    params ["_reason", "_level", "_unitRef", "_actionRef", "_hayRawRef", "_hayNormRef"];

    if (_towerAuthDebug) then {
        diag_log format [
            "[ARC][AIRBASE][AUTH][DENY] unit=%1 uid=%2 action=%3 level=%4 reason=%5 sourceRaw='%6' sourceNorm='%7'",
            name _unitRef,
            getPlayerUID _unitRef,
            _actionRef,
            _level,
            _reason,
            _hayRawRef,
            _hayNormRef
        ];
    };
};

if (isNull _unit) exitWith {
    ["NULL_UNIT", "", _unit, _action, "", ""] call _logAuthDeny;
    [false, "", "NULL_UNIT"]
};

private _actionU = toUpper (trim _action);
if (_actionU isEqualTo "") exitWith {
    ["INVALID_ACTION", "", _unit, _actionU, "", ""] call _logAuthDeny;
    [false, "", "INVALID_ACTION"]
};

private _hay = "";
private _grp = group _unit;
if (!isNull _grp) then { _hay = groupId _grp; };
if (!(_hay isEqualType "")) then { _hay = ""; };
_hay = trim _hay;

private _role = roleDescription _unit;
if (!(_role isEqualType "")) then { _role = ""; };
_role = trim _role;
if (!(_role isEqualTo "")) then {
    if (_hay isEqualTo "") then { _hay = _role; } else { _hay = _hay + " " + _role; };
};

private _hayNorm = [_hay] call _normalizeAuthText;
if (_hayNorm isEqualTo "") exitWith {
    ["NO_ROLE_BINDING", "", _unit, _actionU, _hay, _hayNorm] call _logAuthDeny;
    [false, "", "NO_ROLE_BINDING"]
};

private _ccicTokens = missionNamespace getVariable [
    "airbase_v1_tower_ccicTokens",
    [
        "FARABAD TOWER WSCIC",
        "FARABAD TOWER WS CCIC",
        "FARABAD TOWER WS-CIC",
        "FARABAD TOWER W/S CCIC",
        "FARABAD-TOWER-WS-CCIC",
        "FARABAD TOWER WS.CCIC"
    ]
];
if (!(_ccicTokens isEqualType [])) then { _ccicTokens = ["FARABAD TOWER WS CCIC", "FARABAD TOWER WSCIC"]; };

private _hasCcicToken = false;
{
    private _tok = [_x] call _normalizeAuthText;
    if (_tok isEqualTo "") then { continue; };
    if ((_hayNorm find _tok) >= 0) exitWith { _hasCcicToken = true; };
} forEach _ccicTokens;

if (_hasCcicToken) exitWith {[true, "CCIC", "TOKEN_CCIC"]};

private _allowBnCmd = missionNamespace getVariable ["airbase_v1_tower_allowBnCmd", true];
if (!(_allowBnCmd isEqualType true) && !(_allowBnCmd isEqualType false)) then { _allowBnCmd = false; };
if (_allowBnCmd) then {
    private _bnTokens = missionNamespace getVariable [
        "airbase_v1_tower_bnCommandTokens",
        [
            "BNCMD",
            "BN COMMAND",
            "BNHQ",
            "BN HQ",
            "BN CO",
            "BNCO",
            "BN CDR",
            "BNCDR",
            "BN CMDR",
            "BATTALION CO",
            "BATTALION CDR",
            "REDFALCON 6",
            "REDFALCON6",
            "RED FALCON 6",
            "RED-FALCON-6",
            "FALCON 6",
            "FALCON6",
            "FALCON-6"
        ]
    ];
    if (!(_bnTokens isEqualType [])) then { _bnTokens = ["BNCMD", "BN COMMAND", "BNHQ"]; };

    private _isBnCmd = false;
    {
        private _tok = [_x] call _normalizeAuthText;
        if (_tok isEqualTo "") then { continue; };
        if ((_hayNorm find _tok) >= 0) exitWith { _isBnCmd = true; };
    } forEach _bnTokens;

    if (_isBnCmd) exitWith {[true, "BNCMD", "TOKEN_BN_COMMAND"]};
};

private _lcTokens = missionNamespace getVariable [
    "airbase_v1_tower_lcTokens",
    [
        "FARABAD TOWER LC",
        "FARABAD TOWER WS LC",
        "FARABAD-TOWER-LC",
        "FARABAD TOWER W/S LC"
    ]
];
if (!(_lcTokens isEqualType [])) then { _lcTokens = ["FARABAD TOWER LC", "FARABAD TOWER WS LC"]; };

private _hasLcToken = false;
{
    private _tok = [_x] call _normalizeAuthText;
    if (_tok isEqualTo "") then { continue; };
    if ((_hayNorm find _tok) >= 0) exitWith { _hasLcToken = true; };
} forEach _lcTokens;

if (_hasLcToken) then {
    private _allowed = missionNamespace getVariable ["airbase_v1_tower_lc_allowedActions", ["PRIORITIZE", "CANCEL", "STAFF"]];
    if (!(_allowed isEqualType [])) then { _allowed = ["PRIORITIZE", "CANCEL", "STAFF"]; };

    private _allowedDecision = missionNamespace getVariable ["airbase_v1_tower_lc_allowedDecisionActions", []];
    if (!(_allowedDecision isEqualType [])) then { _allowedDecision = []; };

    {
        _allowed pushBack _x;
    } forEach _allowedDecision;

    private _allowedU = _allowed apply {
        private _v = _x;
        if (!(_v isEqualType "")) then { _v = ""; };
        toUpper (trim _v)
    };

    if (_actionU in _allowedU) exitWith {[true, "LC", "TOKEN_LC"]};
    ["ACTION_NOT_ALLOWED_FOR_LC", "LC", _unit, _actionU, _hay, _hayNorm] call _logAuthDeny;
    [false, "LC", "ACTION_NOT_ALLOWED_FOR_LC"]
} else {
    ["TOKEN_MISSING", "", _unit, _actionU, _hay, _hayNorm] call _logAuthDeny;
    [false, "", "TOKEN_MISSING"]
};
