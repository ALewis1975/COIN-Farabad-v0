/*
    ARC_fnc_companyCommandVirtualOpsTick

    Server-only scheduler for TF Red Falcon virtual operations (Alpha/Bravo + attached enablers).

    Responsibilities:
      - Periodically (cadence-based) refresh one virtual operation per company node.
      - Reuse world/zone context and thread/tasking signals to bias operation selection.
      - Deconflict against active player-owned tasks to avoid virtual task stacking.
      - Emit lifecycle events into intel logs and replicated state.

    Virtual op record format (companyVirtualOps):
      [
        opId, createdAt, updatedAt, status,
        nodeId, callsign,
        opType, summary,
        zoneId, anchorPosATL,
        priority,
        supportTaskId,
        deconflictionTag,
        metaPairs
      ]
*/

if (!isServer) exitWith {false};

private _nodes = ["companyCommandNodes", []] call ARC_fnc_stateGet;
if (!(_nodes isEqualType []) || { _nodes isEqualTo [] }) exitWith {false};

private _now = serverTime;
private _lastTick = ["companyVirtualOpsLastTickAt", -1] call ARC_fnc_stateGet;
if (!(_lastTick isEqualType 0)) then { _lastTick = -1; };

private _interval = missionNamespace getVariable ["ARC_companyVirtualOpsTickIntervalSec", 150];
if (!(_interval isEqualType 0)) then { _interval = 150; };
_interval = (_interval max 45) min 900;

if (_lastTick >= 0 && { (_now - _lastTick) < _interval }) exitWith {false};
["companyVirtualOpsLastTickAt", _now] call ARC_fnc_stateSet;

private _ops = ["companyVirtualOps", []] call ARC_fnc_stateGet;
if (!(_ops isEqualType [])) then { _ops = []; };

private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
private _activeAccepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (!(_activeAccepted isEqualType true) && !(_activeAccepted isEqualType false)) then { _activeAccepted = false; };
private _playerTaskActive = (_activeTaskId isNotEqualTo "") && { _activeAccepted };

private _activePos = ["activeExecPos", []] call ARC_fnc_stateGet;
if (!(_activePos isEqualType [])) then { _activePos = []; };
if ((count _activePos) < 2) then
{
    _activePos = ["activeIncidentPos", []] call ARC_fnc_stateGet;
    if (!(_activePos isEqualType [])) then { _activePos = []; };
};
if ((count _activePos) < 2) then { _activePos = [0,0,0]; };
if ((count _activePos) < 3) then { _activePos resize 3; };

private _activeZone = ["activeIncidentCivsubDistrictId", ""] call ARC_fnc_stateGet;
if (!(_activeZone isEqualType "")) then { _activeZone = ""; };
if (_activeZone isEqualTo "") then
{
    _activeZone = ["activeIncidentZone", ""] call ARC_fnc_stateGet;
    if (!(_activeZone isEqualType "")) then { _activeZone = ""; };
};
if (_activeZone isEqualTo "") then { _activeZone = [_activePos] call ARC_fnc_worldGetZoneForPos; };

private _baseWeights = createHashMapFromArray [
    ["PRESENCE_PATROL", 0.90],
    ["MSR_SECURITY", 0.75],
    ["QRF_STANDBY", 0.70],
    ["PLAYER_SUPPORT", 0.65],
    ["INDEPENDENT_SHAPING", 0.60]
];

private _pickWeightedType = {
    params ["_weights"]; 

    private _pairs = [];
    private _sum = 0;
    {
        private _k = _x;
        private _w = _weights getOrDefault [_k, 0];
        if (_w > 0) then
        {
            _sum = _sum + _w;
            _pairs pushBack [_k, _sum];
        };
    } forEach ["PRESENCE_PATROL", "MSR_SECURITY", "QRF_STANDBY", "PLAYER_SUPPORT", "INDEPENDENT_SHAPING"];

    if (_sum <= 0 || { _pairs isEqualTo [] }) exitWith {"PRESENCE_PATROL"};

    private _roll = random _sum;
    private _pick = "PRESENCE_PATROL";
    {
        if (_roll <= (_x # 1)) exitWith { _pick = _x # 0; };
    } forEach _pairs;

    _pick
};

private _updatedOps = +_ops;
private _changed = false;

{
    private _n = +_x;
    if (!(_n isEqualType []) || { (count _n) < 8 }) then { continue; };

    private _nodeId = _n # 0;
    private _callsign = _n # 1;
    private _nodePos = _n # 4;
    if (!(_nodePos isEqualType [])) then { _nodePos = [0,0,0]; };
    if ((count _nodePos) < 3) then { _nodePos resize 3; };

    private _nodeZone = _n # 5;
    if (!(_nodeZone isEqualType "")) then { _nodeZone = ""; };
    if (_nodeZone isEqualTo "") then { _nodeZone = [_nodePos] call ARC_fnc_worldGetZoneForPos; };

    private _nodeDistrictId = "";
    if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
    {
        _nodeDistrictId = [_nodePos] call ARC_fnc_civsubDistrictsFindByPos;
        if (!(_nodeDistrictId isEqualType "")) then { _nodeDistrictId = ""; };
    };

    private _districtRisk = 0.35;
    if (missionNamespace getVariable ["civsub_v1_enabled", false] && { _nodeDistrictId isNotEqualTo "" }) then
    {
        private _d = [_nodeDistrictId] call ARC_fnc_civsubDistrictsGetById;
        if (_d isEqualType createHashMap && { (count _d) > 0 }) then
        {
            private _fear = _d getOrDefault ["fear_idx", 50];
            private _rEff = _d getOrDefault ["R_EFF_U", 50];
            private _gEff = _d getOrDefault ["G_EFF_U", 50];
            _districtRisk = (((_fear / 100) * 0.55) + ((_rEff / 100) * 0.45) - ((_gEff / 100) * 0.25)) max 0 min 1;
        };
    };

    private _threadPressure = 0;
    private _threads = ["threads", []] call ARC_fnc_stateGet;
    if (_threads isEqualType []) then
    {
        {
            private _thr = [_x] call ARC_fnc_threadNormalizeRecord;
            if (_thr isEqualTo []) then { continue; };
            private _did = _thr # 14;
            if (_did isNotEqualTo _nodeDistrictId) then { continue; };
            private _state = toUpper (_thr # 6);
            if (_state isEqualTo "DORMANT") then { continue; };
            _threadPressure = _threadPressure + (((_thr # 4) max 0 min 1) * 0.5 + ((_thr # 5) max 0 min 1) * 0.5);
        } forEach _threads;
    };
    _threadPressure = (_threadPressure min 1);

    private _weights = +_baseWeights;
    if (_playerTaskActive) then
    {
        _weights set ["PLAYER_SUPPORT", (_weights get "PLAYER_SUPPORT") + 1.10];
        _weights set ["QRF_STANDBY", (_weights get "QRF_STANDBY") + 0.35];
        _weights set ["INDEPENDENT_SHAPING", (_weights get "INDEPENDENT_SHAPING") max 0.25];
    }
    else
    {
        _weights set ["INDEPENDENT_SHAPING", (_weights get "INDEPENDENT_SHAPING") + (_districtRisk * 1.25) + (_threadPressure * 0.65)];
        _weights set ["PRESENCE_PATROL", (_weights get "PRESENCE_PATROL") + (_districtRisk * 0.45)];
        _weights set ["MSR_SECURITY", (_weights get "MSR_SECURITY") + (_threadPressure * 0.35)];
    };

    private _deconflict = "NONE";
    if (_playerTaskActive) then
    {
        if (_nodeZone isEqualTo _activeZone) then { _deconflict = "ACTIVE_ZONE"; };
        if ((_nodePos distance2D _activePos) < 900) then { _deconflict = "AO_PROXIMITY"; };
    };

    private _opType = [_weights] call _pickWeightedType;

    if (_deconflict isNotEqualTo "NONE") then
    {
        if (_opType in ["PLAYER_SUPPORT", "MSR_SECURITY"] && { _playerTaskActive }) then
        {
            _opType = "QRF_STANDBY";
        };
        if (_opType isEqualTo "PRESENCE_PATROL" && { _deconflict isEqualTo "AO_PROXIMITY" }) then
        {
            _opType = "QRF_STANDBY";
        };
    };

    private _opSummary = switch (_opType) do
    {
        case "PLAYER_SUPPORT": { format ["%1 staging enablers to support active player objective in %2.", _callsign, _activeZone] };
        case "MSR_SECURITY": { format ["%1 securing key MSRs and checkpoints around %2.", _callsign, _nodeZone] };
        case "QRF_STANDBY": { format ["%1 holding QRF standby with attached enablers at %2.", _callsign, _nodeZone] };
        case "INDEPENDENT_SHAPING": { format ["%1 conducting independent shaping activity in %2.", _callsign, _nodeZone] };
        default { format ["%1 running presence patrols in %2.", _callsign, _nodeZone] };
    };

    private _priority = ((_weights getOrDefault [_opType, 0.5]) + (_districtRisk * 0.45) + (_threadPressure * 0.35)) min 3;

    private _existingIdx = _updatedOps findIf {
        (_x isEqualType []) &&
        { (count _x) >= 14 } &&
        { ((_x # 4) isEqualTo _nodeId) } &&
        { toUpper (_x # 3) in ["PLANNED", "ACTIVE"] }
    };

    private _meta = [
        ["districtRisk", _districtRisk],
        ["threadPressure", _threadPressure],
        ["playerTaskActive", _playerTaskActive],
        ["activeTaskId", _activeTaskId],
        ["deconfliction", _deconflict],
        ["anchorZone", _nodeZone],
        ["activeZone", _activeZone]
    ];

    if (_existingIdx >= 0) then
    {
        private _cur = +(_updatedOps # _existingIdx);
        private _oldType = _cur # 6;
        _cur set [2, _now];
        _cur set [3, "ACTIVE"];
        _cur set [6, _opType];
        _cur set [7, _opSummary];
        _cur set [8, _nodeZone];
        _cur set [9, _nodePos];
        _cur set [10, _priority];
        _cur set [11, if (_playerTaskActive && { _opType isEqualTo "PLAYER_SUPPORT" }) then { _activeTaskId } else { "" }];
        _cur set [12, _deconflict];
        _cur set [13, _meta];
        _updatedOps set [_existingIdx, _cur];

        if (toUpper _oldType isNotEqualTo _opType) then
        {
            _changed = true;
            ["OPS", format ["VOP UPDATE: %1 shifted to %2 (%3).", _callsign, _opType, _deconflict], _nodePos,
                [["event", "COMPANY_VOP_UPDATED"], ["nodeId", _nodeId], ["opType", _opType], ["deconfliction", _deconflict]]
            ] call ARC_fnc_intelLog;
        };
    }
    else
    {
        private _counter = ["companyVirtualOpsCounter", 0] call ARC_fnc_stateGet;
        if (!(_counter isEqualType 0) || { _counter < 0 }) then { _counter = 0; };
        _counter = _counter + 1;
        ["companyVirtualOpsCounter", _counter] call ARC_fnc_stateSet;

        private _opId = format ["ARC_vop_%1", _counter];
        _updatedOps pushBack [
            _opId,
            _now,
            _now,
            "ACTIVE",
            _nodeId,
            _callsign,
            _opType,
            _opSummary,
            _nodeZone,
            _nodePos,
            _priority,
            if (_playerTaskActive && { _opType isEqualTo "PLAYER_SUPPORT" }) then { _activeTaskId } else { "" },
            _deconflict,
            _meta
        ];

        _changed = true;
        ["OPS", format ["VOP START: %1 %2 (%3).", _callsign, _opType, _nodeZone], _nodePos,
            [["event", "COMPANY_VOP_STARTED"], ["nodeId", _nodeId], ["opType", _opType], ["deconfliction", _deconflict]]
        ] call ARC_fnc_intelLog;
    };

} forEach _nodes;

private _cap = missionNamespace getVariable ["ARC_companyVirtualOpsCap", 30];
if (!(_cap isEqualType 0)) then { _cap = 30; };
_cap = (_cap max 8) min 120;
while { (count _updatedOps) > _cap } do { _updatedOps deleteAt 0; };

if (_changed || { !(_updatedOps isEqualTo _ops) }) then
{
    ["companyVirtualOps", _updatedOps] call ARC_fnc_stateSet;
    ["companyVirtualOpsLastRollupAt", _now] call ARC_fnc_stateSet;
};

true
