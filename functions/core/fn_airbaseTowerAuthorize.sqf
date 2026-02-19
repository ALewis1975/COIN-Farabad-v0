/*
    ARC_fnc_airbaseTowerAuthorize

    Authorize airbase tower control actions by groupId/roleDescription tokens.

    Params:
      0: OBJECT unit
      1: STRING action token (HOLD|RELEASE|PRIORITIZE|CANCEL|APPROVE|DENY|OVERRIDE)

    Returns:
      ARRAY [BOOL authorized, STRING level, STRING reason]
      - level: "CCIC" | "LC" | ""
*/

params [
    ["_unit", objNull, [objNull]],
    ["_action", "", [""]]
];

if (isNull _unit) exitWith {[false, "", "NULL_UNIT"]};

private _actionU = toUpper (trim _action);
if (_actionU isEqualTo "") exitWith {[false, "", "INVALID_ACTION"]};

private _hay = "";
private _grp = group _unit;
if (!isNull _grp) then { _hay = groupId _grp; };
if (!(_hay isEqualType "")) then { _hay = ""; };
_hay = trim _hay;

private _role = roleDescription _unit;
if (!(_role isEqualType "")) then { _role = ""; };
_role = trim _role;
if (_role isNotEqualTo "") then {
    if (_hay isEqualTo "") then { _hay = _role; } else { _hay = _hay + " " + _role; };
};

if (_hay isEqualTo "") exitWith {[false, "", "NO_ROLE_BINDING"]};

private _hayU = toUpper _hay;

if ((_hayU find "FARABAD_TOWER_WS_CCIC") >= 0) exitWith {[true, "CCIC", "TOKEN_CCIC"]};

private _allowBnCmd = missionNamespace getVariable ["airbase_v1_tower_allowBnCmd", true];
if (!(_allowBnCmd isEqualType true) && !(_allowBnCmd isEqualType false)) then { _allowBnCmd = true; };
if (_allowBnCmd) then {
    private _bnTokens = missionNamespace getVariable [
        "airbase_v1_tower_bnCommandTokens",
        ["BNCMD", "BN COMMAND", "BNHQ", "BN CO", "BNCO", "BN CDR", "REDFALCON 6", "REDFALCON6", "FALCON 6", "FALCON6"]
    ];
    if (!(_bnTokens isEqualType [])) then { _bnTokens = ["BNCMD", "BN COMMAND", "BNHQ"]; };

    private _isBnCmd = false;
    {
        if (_x isEqualType "" && {!(_x isEqualTo "")} && {(_hayU find (toUpper _x)) >= 0}) exitWith { _isBnCmd = true; };
    } forEach _bnTokens;

    if (_isBnCmd) exitWith {[true, "CCIC", "TOKEN_BN_COMMAND"]};
};

if ((_hayU find "FARABAD_TOWER_LC") >= 0) then {
    private _allowed = missionNamespace getVariable ["airbase_v1_tower_lc_allowedActions", ["PRIORITIZE", "CANCEL"]];
    if (!(_allowed isEqualType [])) then { _allowed = ["PRIORITIZE", "CANCEL"]; };

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
    [false, "LC", "ACTION_NOT_ALLOWED_FOR_LC"]
} else {
    [false, "", "TOKEN_MISSING"]
};
