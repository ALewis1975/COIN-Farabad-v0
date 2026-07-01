/*
    ARC_fnc_airbaseTowerAuthorize

    Authorize airbase tower control actions by groupId/roleDescription tokens.

    Params:
      0: OBJECT unit
      1: STRING action token (HOLD|RELEASE|PRIORITIZE|CANCEL|APPROVE|DENY|OVERRIDE|STAFF)

    Returns:
      ARRAY [BOOL authorized, STRING level, STRING reason]
      - level: "OMNI" | "CCIC" | "BNCMD" | "LC" | ""
*/

params [
    ["_unit", objNull, [objNull]],
    ["_action", "", [""]]
];

private _towerAuthDebug = missionNamespace getVariable ["airbase_v1_tower_authDebug", false];
if (!(_towerAuthDebug isEqualType true) && !(_towerAuthDebug isEqualType false)) then { _towerAuthDebug = false; };
private _towerAuthAuditEnabled = missionNamespace getVariable ["airbase_v1_tower_authAuditEnabled", false];
if (!(_towerAuthAuditEnabled isEqualType true) && !(_towerAuthAuditEnabled isEqualType false)) then { _towerAuthAuditEnabled = false; };

private _trimFn = compile "params ['_s']; trim _s";

private _normalizeAuthText = {
    params [["_text", "", [""]]];

    if (!(_text isEqualType "")) then { _text = ""; };

    // Keep this normalizer aligned with the token audit. Pipe/parentheses are common
    // in roleDescription strings such as "2-325 AIR | REDFALCON 6 Commanding Officer"
    // and "FARABAD TOWER (LC)"; treat them as separators so token matching is stable.
    private _parts = ((toUpper ([_text] call _trimFn)) splitString (" .:-_/|()[]{}" + toString [9,10,13])) select {
        !(_x isEqualTo "")
    };
    _parts joinString " "
};

private _groupRaw = "";
private _roleRaw = "";
private _hay = "";
private _unitName = "<null>";
private _unitUid = "";

if (!isNull _unit) then {
    _unitName = name _unit;
    _unitUid = getPlayerUID _unit;
    private _grp = group _unit;
    if (!isNull _grp) then { _groupRaw = groupId _grp; };
    if (!(_groupRaw isEqualType "")) then { _groupRaw = ""; };
    _groupRaw = [_groupRaw] call _trimFn;

    _roleRaw = roleDescription _unit;
    if (!(_roleRaw isEqualType "")) then { _roleRaw = ""; };
    _roleRaw = [_roleRaw] call _trimFn;

    _hay = _groupRaw;
    if (!(_roleRaw isEqualTo "")) then {
        if (_hay isEqualTo "") then { _hay = _roleRaw; } else { _hay = _hay + " " + _roleRaw; };
    };
};

private _hayNorm = [_hay] call _normalizeAuthText;
private _hayNormPadded = " " + _hayNorm + " ";
private _actionU = toUpper ([_action] call _trimFn);

private _recordAuth = {
    params [
        ["_authorized", false, [false]],
        ["_level", "", [""]],
        ["_reason", "", [""]],
        ["_matchedToken", "", [""]]
    ];

    if (_towerAuthDebug) then {
        private _tag = if (_authorized) then { "ALLOW" } else { "DENY" };
        diag_log format [
            "[ARC][AIRBASE][AUTH][%1] unit=%2 uid=%3 action=%4 level=%5 reason=%6 matchedToken='%7' groupRaw='%8' roleRaw='%9' sourceNorm='%10'",
            _tag,
            _unitName,
            _unitUid,
            _actionU,
            _level,
            _reason,
            _matchedToken,
            _groupRaw,
            _roleRaw,
            _hayNorm
        ];
    };

    if (_towerAuthDebug || { _towerAuthAuditEnabled }) then {
        private _tail = missionNamespace getVariable ["airbase_v1_tower_authAuditTail", []];
        if (!(_tail isEqualType [])) then { _tail = []; };
        _tail pushBack [serverTime, _authorized, _level, _reason, _matchedToken, _actionU, _unitName, _unitUid, _groupRaw, _roleRaw, _hayNorm];
        private _cap = missionNamespace getVariable ["airbase_v1_tower_authAuditCap", 40];
        if (!(_cap isEqualType 0)) then { _cap = 40; };
        _cap = (_cap max 5) min 200;
        if ((count _tail) > _cap) then { _tail = _tail select [((count _tail) - _cap) max 0, _cap]; };
        missionNamespace setVariable ["airbase_v1_tower_authAuditTail", _tail, false];
    };
};

private _mergeTokens = {
    params ["_configured", "_fallback", "_extras"];

    private _out = [];
    if (_configured isEqualType [] && { (count _configured) > 0 }) then {
        _out = +_configured;
    } else {
        if (_fallback isEqualType []) then { _out = +_fallback; };
    };

    if (!(_extras isEqualType [])) then { _extras = []; };
    {
        if (_x isEqualType "" && { !(_x isEqualTo "") }) then { _out pushBackUnique _x; };
    } forEach _extras;

    _out
};

private _findToken = {
    params [
        ["_tokens", [], [[]]],
        ["_strictWord", false, [false]]
    ];

    private _matched = "";
    {
        private _tokRaw = _x;
        private _tok = [_tokRaw] call _normalizeAuthText;
        if (_tok isEqualTo "") then { continue; };

        private _ok = if (_strictWord) then {
            (_hayNormPadded find (" " + _tok + " ")) >= 0
        } else {
            (_hayNorm find _tok) >= 0
        };

        if (_ok) exitWith { _matched = _tokRaw; };
    } forEach _tokens;

    _matched
};

if (isNull _unit) exitWith {
    [false, "", "NULL_UNIT", ""] call _recordAuth;
    [false, "", "NULL_UNIT"]
};

if (_actionU isEqualTo "") exitWith {
    [false, "", "INVALID_ACTION", ""] call _recordAuth;
    [false, "", "INVALID_ACTION"]
};

if (_hayNorm isEqualTo "") exitWith {
    [false, "", "NO_ROLE_BINDING", ""] call _recordAuth;
    [false, "", "NO_ROLE_BINDING"]
};

private _omniTokensConfigured = missionNamespace getVariable ["ARC_consoleOmniTokens", ["OMNI"]];
private _omniTokens = [_omniTokensConfigured, ["OMNI"], []] call _mergeTokens;
private _omniMatched = [_omniTokens, true] call _findToken;
if (!(_omniMatched isEqualTo "")) exitWith {
    [true, "OMNI", "TOKEN_OMNI", _omniMatched] call _recordAuth;
    [true, "OMNI", "TOKEN_OMNI"]
};

private _ccicFallback = [
    "FARABAD TOWER WSCIC",
    "FARABAD TOWER WS CCIC",
    "FARABAD TOWER WS-CIC",
    "FARABAD TOWER W/S CCIC",
    "FARABAD-TOWER-WS-CCIC",
    "FARABAD TOWER WS.CCIC"
];
private _ccicExtras = [
    // ORBAT: 332 EOSS / FARABAD TOWER — Watch Supervisor / CIC.
    "332 EOSS FARABAD TOWER WATCH SUPERVISOR",
    "332 EOSS FARABAD TOWER CIC",
    "332 EOSS FARABAD TOWER CONTROLLER IN CHARGE",
    "FARABAD TOWER WATCH SUPERVISOR",
    "FARABAD TOWER WATCH SUPERVISOR CONTROLLER IN CHARGE",
    "FARABAD TOWER CONTROLLER IN CHARGE",
    "FARABAD TOWER CIC",
    "FARABAD TOWER WS CIC",
    "FARABAD TOWER WS WIC"
];
private _ccicConfigured = missionNamespace getVariable ["airbase_v1_tower_ccicTokens", _ccicFallback];
private _ccicTokens = [_ccicConfigured, _ccicFallback, _ccicExtras] call _mergeTokens;
private _ccicMatched = [_ccicTokens, false] call _findToken;
if (!(_ccicMatched isEqualTo "")) exitWith {
    [true, "CCIC", "TOKEN_CCIC", _ccicMatched] call _recordAuth;
    [true, "CCIC", "TOKEN_CCIC"]
};

private _allowBnCmd = missionNamespace getVariable ["airbase_v1_tower_allowBnCmd", true];
if (!(_allowBnCmd isEqualType true) && !(_allowBnCmd isEqualType false)) then { _allowBnCmd = false; };
if (_allowBnCmd) then {
    private _bnFallback = [
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
    ];
    private _bnExtras = [
        // ORBAT: TF REDFALCON / 2-325 AIR HQ and BCT FALCON HQ. Keep these
        // command-specific; do not add company roots such as REDFALCON 3.
        "TF REDFALCON 6",
        "TF REDFALCON CDR",
        "TF REDFALCON COMMANDER",
        "2-325 AIR REDFALCON 6",
        "2 325 AIR REDFALCON 6",
        "2-325 AIR REDFALCON 6 COMMANDING OFFICER",
        "REDFALCON 6 COMMANDING OFFICER",
        "REDFALCON 6 TF CDR",
        "REDFALCON 6 TF COMMANDER",
        "FALCON 6 BCT CDR",
        "FALCON 6 BCT COMMANDER"
    ];
    private _bnConfigured = missionNamespace getVariable ["airbase_v1_tower_bnCommandTokens", _bnFallback];
    private _bnTokens = [_bnConfigured, _bnFallback, _bnExtras] call _mergeTokens;

    private _bnMatched = [_bnTokens, false] call _findToken;
    if (!(_bnMatched isEqualTo "")) exitWith {
        [true, "BNCMD", "TOKEN_BN_COMMAND", _bnMatched] call _recordAuth;
        [true, "BNCMD", "TOKEN_BN_COMMAND"]
    };
};

private _lcFallback = [
    "FARABAD TOWER LC",
    "FARABAD TOWER WS LC",
    "FARABAD-TOWER-LC",
    "FARABAD TOWER W/S LC"
];
private _lcExtras = [
    // ORBAT: FARABAD TOWER Local Controller and FARABAD GROUND Ground Controller.
    "332 EOSS FARABAD TOWER LOCAL CONTROLLER",
    "332 EOSS FARABAD TOWER LEAD CONTROLLER",
    "FARABAD TOWER LOCAL CONTROLLER",
    "FARABAD TOWER LOCAL CONTROL",
    "FARABAD TOWER LEAD CONTROLLER",
    "332 EOSS FARABAD GROUND GROUND CONTROLLER",
    "FARABAD GROUND GROUND CONTROLLER",
    "FARABAD GROUND CONTROLLER"
];
private _lcConfigured = missionNamespace getVariable ["airbase_v1_tower_lcTokens", _lcFallback];
private _lcTokens = [_lcConfigured, _lcFallback, _lcExtras] call _mergeTokens;
private _lcMatched = [_lcTokens, false] call _findToken;

if (!(_lcMatched isEqualTo "")) then {
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
        toUpper ([_v] call _trimFn)
    };

    if (_actionU in _allowedU) exitWith {
        [true, "LC", "TOKEN_LC", _lcMatched] call _recordAuth;
        [true, "LC", "TOKEN_LC"]
    };

    [false, "LC", "ACTION_NOT_ALLOWED_FOR_LC", _lcMatched] call _recordAuth;
    [false, "LC", "ACTION_NOT_ALLOWED_FOR_LC"]
} else {
    [false, "", "TOKEN_MISSING", ""] call _recordAuth;
    [false, "", "TOKEN_MISSING"]
};