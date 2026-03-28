/*
    ARC_fnc_companyCommandTick

    Server-only command model tick:
      - updates commander intent/posture for Alpha/Bravo nodes
      - enforces role-gated node activity based on leadership/HQ tokens
      - writes decisions to shared tasking state (companyCommandTasking)
*/

if (!isServer) exitWith {false};

private _nodes = ["companyCommandNodes", []] call ARC_fnc_stateGet;
if (!(_nodes isEqualType [])) exitWith {false};
if (_nodes isEqualTo []) exitWith {false};

private _now = serverTime;
private _lastTick = ["companyCommandLastTickAt", -1] call ARC_fnc_stateGet;
if (!(_lastTick isEqualType 0)) then { _lastTick = -1; };

private _interval = missionNamespace getVariable ["ARC_companyCommandTickIntervalSec", 120];
if (!(_interval isEqualType 0)) then { _interval = 120; };
_interval = (_interval max 30) min 600;

if (_lastTick >= 0 && { (_now - _lastTick) < _interval }) exitWith {false};
["companyCommandLastTickAt", _now] call ARC_fnc_stateSet;

private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (!(_accepted isEqualType true) && !(_accepted isEqualType false)) then { _accepted = false; };

private _insPressure = ["insurgentPressure", 0.35] call ARC_fnc_stateGet;
private _infiltration = ["infiltration", 0.35] call ARC_fnc_stateGet;
private _baseFuel = ["baseFuel", 0.60] call ARC_fnc_stateGet;
private _baseAmmo = ["baseAmmo", 0.60] call ARC_fnc_stateGet;
private _baseMed = ["baseMed", 0.60] call ARC_fnc_stateGet;

private _sustainLow = ((_baseFuel min _baseAmmo) min _baseMed) < 0.30;
private _hotFight = ((!(_activeTaskId isEqualTo "")) && { _accepted }) || { (_insPressure > 0.62) || { _infiltration > 0.55 } };

private _hqTokens = missionNamespace getVariable [
    "ARC_consoleHQTokens",
    ["BNCMD", "BN COMMAND", "BNHQ", "BN CO", "BNCO", "BN CDR", "REDFALCON 6", "REDFALCON6", "FALCON 6", "FALCON6"]
];
if (!(_hqTokens isEqualType [])) then { _hqTokens = []; };

private _updated = [];

{
    private _n = +_x;
    if (!(_n isEqualType []) || { (count _n) < 12 }) then { continue; };

    private _nodeId = _n select 0;
    private _cmdToken = _n select 1;

    private _commander = objNull;
    {
        if (!isPlayer _x || { !alive _x }) then { continue; };
        if ([_x, _cmdToken] call ARC_fnc_rolesHasGroupIdToken) exitWith
        {
            _commander = _x;
        };
    } forEach allPlayers;

    // Role-gating: only nodes with valid leadership presence remain task-authoritative.
    private _roleGate = false;
    if (!isNull _commander) then
    {
        _roleGate = ([_commander] call ARC_fnc_rolesIsAuthorized) || { [_commander, _hqTokens] call ARC_fnc_rolesHasGroupIdToken };
    };

    private _intent = "INDEPENDENT_AREA_SECURITY";
    private _posture = "INDEPENDENT_SECURITY";

    if (_hotFight) then
    {
        _intent = "SUPPORT_PLAYERS";
        _posture = "RESERVE_REACTION";
    };

    if (_sustainLow) then
    {
        _intent = "SUSTAINMENT";
        _posture = "RESERVE_REACTION";
    };

    if (!_roleGate) then
    {
        _intent = "INDEPENDENT_AREA_SECURITY";
        _posture = "INDEPENDENT_SECURITY";
    };

    private _changed = (!((toUpper (_n select 6)) isEqualTo _intent)) || { !((toUpper (_n select 7)) isEqualTo _posture) };

    _n set [6, _intent];
    _n set [7, _posture];
    _n set [9, _now];
    _n set [10, if (isNull _commander) then {""} else {name _commander}];
    _n set [11, if (isNull _commander) then {""} else {getPlayerUID _commander}];

    if (_changed && _roleGate) then
    {
        private _issued = [_n, _intent, _posture, [["activeIncident", _activeTaskId], ["roleGated", _roleGate], ["at", _now]]] call ARC_fnc_companyCommandIssueTask;
        _n set [8, _issued];
    };

    if (!_roleGate) then
    {
        _n set [8, ""];
    };

    _updated pushBack _n;
} forEach _nodes;

["companyCommandNodes", _updated] call ARC_fnc_stateSet;
true
