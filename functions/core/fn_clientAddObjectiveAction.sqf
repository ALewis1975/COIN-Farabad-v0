/*
    Client: attach an interaction action to an objective object/NPC.

    addAction is local, so the server remoteExecs this to all clients (JIP enabled).

    Params:
        0: OBJECT - objective target
        1: STRING - action text
        2: STRING - objectiveKind

    Returns:
        BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_obj", objNull],
    ["_actionText", ""],
    ["_kind", ""]
];

if (isNull _obj) exitWith {false};
if (_actionText isEqualTo "" || _kind isEqualTo "") exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";

private _nid = netId _obj;
if (_nid isEqualTo "") exitWith {false};

private _key = format ["ARC_objAct_%1", _nid];
if (!isNil { missionNamespace getVariable _key }) exitWith {true};

private _kindU = toUpper ([_kind] call _trimFn);

// IED Phase 1: suspicious-object objectives use a two-step interaction:
//   1) DISCOVER / INSPECT (sets discovered state; reveals the "render safe" action)
//   2) COMPLETE (renders safe / clears; enables TOC closeout flow)
private _store = -1;

if (_kindU in ["IED_DEVICE", "VBIED_VEHICLE"]) then
{
    private _inspectText = "Inspect";
    if (_kindU isEqualTo "IED_DEVICE") then { _inspectText = "Inspect device"; };
    if (_kindU isEqualTo "VBIED_VEHICLE") then { _inspectText = "Inspect vehicle"; };

    // "Scan" is optional. Default is disabled so ACE tools are the primary discovery method.
    private _scanEnabled = missionNamespace getVariable ["ARC_iedScanActionEnabled", false];
    if (!(_scanEnabled isEqualType true) && !(_scanEnabled isEqualType false)) then { _scanEnabled = false; };

    private _idScan = -1;

    private _idInspect = _obj addAction [
        _inspectText,
        {
            params ["_target", "_caller", "_actionId", "_args"];
            _args params ["_kind"]; // objectiveKind
            [_target, _caller, _kind, "DISCOVER"] call ARC_fnc_clientObjectiveInteract;
        },
        [_kind],
        1.6,
        true,
        true,
        "",
        "((alive _target) || {!(_target isKindOf 'AllVehicles')}) && {_this distance _target < 3} && {!(_target getVariable [""ARC_objectiveDiscovered"", false])}",
        3
    ];

    if (_scanEnabled) then
    {
        private _scanText = if (_kindU isEqualTo "VBIED_VEHICLE") then { "Scan vehicle" } else { "Scan for IED" };
        _idScan = _obj addAction [
            _scanText,
            {
                params ["_target", "_caller", "_actionId", "_args"];
                _args params ["_kind"]; // objectiveKind
                [_target, _caller, _kind, "DISCOVER_SCAN"] call ARC_fnc_clientObjectiveInteract;
            },
            [_kind],
            1.7,
            true,
            true,
            "",
            "((alive _target) || {!(_target isKindOf 'AllVehicles')}) && {_this distance _target < 12} && {!(_target getVariable [""ARC_objectiveDiscovered"", false])} && {('MineDetector' in (items _this + assignedItems _this + weapons _this)) || ('ACE_VMH3' in (items _this + assignedItems _this + weapons _this)) || ('ACE_VMM3' in (items _this + assignedItems _this + weapons _this))}",
            3
        ];
    };

    private _idComplete = _obj addAction [
        _actionText,
        {
            params ["_target", "_caller", "_actionId", "_args"];
            _args params ["_kind"]; // objectiveKind
            [_target, _caller, _kind, "COMPLETE"] call ARC_fnc_clientObjectiveInteract;
        },
        [_kind],
        1.5,
        true,
        true,
        "",
        "((alive _target) || {!(_target isKindOf 'AllVehicles')}) && {_this distance _target < 3} && {(_target getVariable [""ARC_objectiveDiscovered"", false])}",
        3
    ];

    // Phase 4: TOC-approved disposition (detonate in place)
    private _idDet = _obj addAction [
        "Detonate in place (TOC approved)",
        {
            params ["_target", "_caller", "_actionId", "_args"];
            _args params ["_kind"];
            ["DET_IN_PLACE"] call ARC_fnc_iedClientExecuteDisposition;
        },
        [_kind],
        1.2,
        true,
        true,
        "",
        "((alive _target) || {!(_target isKindOf 'AllVehicles')}) && {_this distance _target < 4} && {(_target getVariable ['ARC_objectiveDiscovered', false])} && {(['DET_IN_PLACE'] call ARC_fnc_iedClientHasEodApproval)} && {('ToolKit' in (items _this + assignedItems _this)) || ('ACE_DefusalKit' in (items _this + assignedItems _this))}",
        3
    ];

    _store = [_idInspect, _idComplete, _idDet];
    if (_idScan isEqualType 0 && { _idScan >= 0 }) then { _store pushBack _idScan; };
}
else
{
    private _id = _obj addAction [
        _actionText,
        {
            params ["_target", "_caller", "_actionId", "_args"];
            _args params ["_kind"]; // objectiveKind

            [_target, _caller, _kind, "COMPLETE"] call ARC_fnc_clientObjectiveInteract;
        },
        [_kind],
        1.5,
        true,
        true,
        "",
        // Condition (evaluated locally)
        "((alive _target) || {!(_target isKindOf 'AllVehicles')}) && {_this distance _target < 3}",
        3
    ];

    _store = _id;
};

missionNamespace setVariable [_key, _store];
true
