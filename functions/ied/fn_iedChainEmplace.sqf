/*
    ARC_fnc_iedChainEmplace

    IED subsystem: spawn secondary chain IED devices linked to a primary device.
    Detonated in sequence after primary detonation.

    Params:
      0: STRING primaryDeviceId (device netId)
      1: NUMBER chainCount (1..3, capped at 3)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_primaryDeviceId", "", [""]],
    ["_chainCount", 1, [0]]
];

if (_primaryDeviceId isEqualTo "") exitWith {false};
_chainCount = (_chainCount max 0) min 3;
if (_chainCount == 0) exitWith {false};

private _primaryObj = objectFromNetId _primaryDeviceId;
if (isNull _primaryObj) exitWith
{
    diag_log format ["[ARC][WARN] ARC_fnc_iedChainEmplace: primary device not found id=%1", _primaryDeviceId];
    false
};

private _primaryPos = getPosATL _primaryObj;
_primaryPos resize 3;

// Read active threat ID for label association
private _threatId = ["activeIedThreatId", ""] call ARC_fnc_stateGet;
if (!(_threatId isEqualType "")) then { _threatId = ""; };
private _label = format ["THREAT:IED:%1", _threatId];

// IED prop class (match fn_iedSpawnTick logic)
private _iedClass = "Land_Bomb_02_F";
if !(isClass (configFile >> "CfgVehicles" >> _iedClass)) then { _iedClass = "Land_Bomb_01_F"; };
if !(isClass (configFile >> "CfgVehicles" >> _iedClass)) then { _iedClass = "Land_BagBunker_Small_F"; };

private _chainNetIds = [];

for "_i" from 1 to _chainCount do
{
    // Pick offset position within 80m via ARC_fnc_iedPickSite (fallback: jitter)
    private _candidatePos = [_primaryPos, 20, 80, 5, 0, 0.4, 0, [], [[_primaryPos, 80]]] call BIS_fnc_findSafePos;
    if (!(_candidatePos isEqualType []) || {(count _candidatePos) < 2}) then
    {
        private _dir = random 360;
        private _dist = 20 + (random 60);
        _candidatePos = [_primaryPos select 0 + _dist * sin _dir, _primaryPos select 1 + _dist * cos _dir, 0];
    };
    _candidatePos resize 3;

    // Spawn chain device object
    private _chainObj = createVehicle [_iedClass, _candidatePos, [], 0, "CAN_COLLIDE"];
    if (isNull _chainObj) then { continue; };

    _chainObj setPos _candidatePos;
    _chainObj setVariable ["ARC_isChainDevice", true, true];
    _chainObj setVariable ["ARC_primaryDeviceId", _primaryDeviceId, true];
    _chainObj setVariable ["ARC_chainIndex", _i, true];
    _chainObj setVariable ["ARC_cleanupLabel", _label, true];

    _chainNetIds pushBack (netId _chainObj);

    diag_log format ["[ARC][INFO] ARC_fnc_iedChainEmplace: chain[%1] netId=%2 pos=%3 label=%4", _i, netId _chainObj, mapGridPosition _candidatePos, _label];
};

// Store chain device netIds on primary object
_primaryObj setVariable ["ARC_chainDeviceNetIds", _chainNetIds, true];

// Register detonation sequence on primary destruction
if ((count _chainNetIds) > 0) then
{
    _primaryObj addEventHandler ["Killed", {
        params ["_vehicle"];
        private _chains = _vehicle getVariable ["ARC_chainDeviceNetIds", []];
        private _delay = 2;
        {
            private _nid = _x;
            private _d = _delay;
            [_nid, _d] spawn {
                params ["_chainNid", "_delayS"];
                sleep _delayS;
                private _chainObj = objectFromNetId _chainNid;
                if (!isNull _chainObj) then
                {
                    private _p = getPosATL _chainObj;
                    _p resize 3; _p set [2, 0];
                    private _boomClass = "Bo_Mk82";
                    createVehicle [_boomClass, _p, [], 0, "CAN_COLLIDE"];
                    deleteVehicle _chainObj;
                    diag_log format ["[ARC][INFO] Chain device detonated netId=%1", _chainNid];
                };
            };
            _delay = _delay + 2 + (floor (random 4));
        } forEach _chains;
    }];
};

diag_log format ["[ARC][INFO] ARC_fnc_iedChainEmplace: primary=%1 chainCount=%2 netIds=%3", _primaryDeviceId, count _chainNetIds, _chainNetIds];

true
