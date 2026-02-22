/*
    ARC_fnc_companyCommandInit

    Server-only initialization for company command model nodes.

    Creates two leadership nodes in shared ARC state:
      - ALPHA commander (REDFALCON 2)
      - BRAVO commander (REDFALCON 3)

    Node format (companyCommandNodes):
      [
        nodeId, callsignToken, leadershipLabel,
        hqMarker, hqPosATL, hqZone,
        intent, posture,
        activeTaskId,
        lastDecisionAt,
        activeCommanderName,
        activeCommanderUID
      ]
*/

if (!isServer) exitWith {false};

private _resolveAnchor = {
    params ["_markerCandidates", "_fallbackMarker", "_fallbackPos"];

    if (!(_markerCandidates isEqualType [])) then { _markerCandidates = []; };

    private _resolved = "";
    {
        if !(_x isEqualType "") then { continue; };
        private _m = [_x] call ARC_fnc_worldResolveMarker;
        if (_m isEqualType "" && { _m isNotEqualTo "" } && { _m in allMapMarkers }) exitWith { _resolved = _m; };
    } forEach _markerCandidates;

    if (_resolved isEqualTo "") then
    {
        private _fb = [_fallbackMarker] call ARC_fnc_worldResolveMarker;
        if (_fb isEqualType "" && { _fb isNotEqualTo "" } && { _fb in allMapMarkers }) then
        {
            _resolved = _fb;
        };
    };

    private _pos = +_fallbackPos;
    if (!(_pos isEqualType [])) then { _pos = [0,0,0]; };
    if ((count _pos) < 3) then { _pos resize 3; };

    if (_resolved isNotEqualTo "") then
    {
        _pos = markerPos _resolved;
        if ((count _pos) < 3) then { _pos resize 3; };
    };

    private _zone = [_pos] call ARC_fnc_worldGetZoneForPos;
    [_resolved, _pos, _zone]
};

private _airbaseMarker = ["mkr_airbaseCenter"] call ARC_fnc_worldResolveMarker;
private _airbasePos = if (_airbaseMarker isNotEqualTo "" && { _airbaseMarker in allMapMarkers }) then { markerPos _airbaseMarker } else { [0,0,0] };
if ((count _airbasePos) < 3) then { _airbasePos resize 3; };

private _alphaCandidates = missionNamespace getVariable [
    "ARC_companyCommandAlphaHqMarkerCandidates",
    ["hq_2_325_a", "hq_a_2_325_air", "HQ_A_2_325", "ARC_hq_A_2325", "mkr_airbaseCenter"]
];
private _bravoCandidates = missionNamespace getVariable [
    "ARC_companyCommandBravoHqMarkerCandidates",
    ["hq_2_325_b", "hq_b_2_325_air", "HQ_B_2_325", "ARC_hq_B_2325", "mkr_airbaseCenter"]
];

private _alphaAnchor = [_alphaCandidates, "mkr_airbaseCenter", _airbasePos] call _resolveAnchor;
private _bravoAnchor = [_bravoCandidates, "mkr_airbaseCenter", _airbasePos] call _resolveAnchor;

private _alphaNode = [
    "COMPANY_ALPHA",
    "REDFALCON 2",
    "Alpha Commander",
    _alphaAnchor # 0,
    _alphaAnchor # 1,
    _alphaAnchor # 2,
    "SUPPORT_PLAYERS",
    "RESERVE_REACTION",
    "",
    -1,
    "",
    ""
];

private _bravoNode = [
    "COMPANY_BRAVO",
    "REDFALCON 3",
    "Bravo Commander",
    _bravoAnchor # 0,
    _bravoAnchor # 1,
    _bravoAnchor # 2,
    "AREA_SECURITY",
    "INDEPENDENT_SECURITY",
    "",
    -1,
    "",
    ""
];

["companyCommandNodes", [_alphaNode, _bravoNode]] call ARC_fnc_stateSet;

if !(["companyCommandTasking", []] call ARC_fnc_stateGet isEqualType []) then
{
    ["companyCommandTasking", []] call ARC_fnc_stateSet;
};

if !(["companyCommandCounter", 0] call ARC_fnc_stateGet isEqualType 0) then
{
    ["companyCommandCounter", 0] call ARC_fnc_stateSet;
};

if !(["companyCommandLastTickAt", -1] call ARC_fnc_stateGet isEqualType 0) then
{
    ["companyCommandLastTickAt", -1] call ARC_fnc_stateSet;
};

["OPS", format ["Company command nodes initialized: ALPHA=%1 BRAVO=%2", _alphaAnchor # 0, _bravoAnchor # 0], [0,0,0],
    [["event", "COMPANY_COMMAND_INIT"], ["alphaZone", _alphaAnchor # 2], ["bravoZone", _bravoAnchor # 2]]
] call ARC_fnc_intelLog;

true
