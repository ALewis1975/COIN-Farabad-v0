/*
    ARC_fnc_worldGateBarrierInit

    Server-side: attach barrier open/close logic to named gate objects at
    North Gate and Main Gate. BLUFOR vehicles approaching within the trigger
    radius raise the barrier; unknown or OPFOR triggers a hold and alert.

    Requires Eden-placed barrier objects named:
      ARC_barrier_north   — North Gate barrier
      ARC_barrier_main    — Main Gate barrier
      ARC_barrier_south   — South Gate barrier (optional)

    Guard post objects:
      ARC_guardpost_north, ARC_guardpost_main, ARC_guardpost_south

    Configurable:
      ARC_worldGateEnabled       (BOOL,   default true)
      ARC_worldGateTriggerRadiusM (NUMBER, default 18)
      ARC_worldGateAutoRaiseDelayS (NUMBER, default 5) — seconds before auto-raise
      ARC_worldGateAutoLowerDelayS (NUMBER, default 10) — seconds before auto-lower

    Returns:
      NUMBER — count of gates initialized
*/

if (!isServer) exitWith {0};

if (!missionNamespace getVariable ["ARC_worldGateEnabled", true]) exitWith {0};
if (missionNamespace getVariable ["ARC_worldGateInitDone", false]) exitWith {0};
missionNamespace setVariable ["ARC_worldGateInitDone", true];

private _triggerRadius = missionNamespace getVariable ["ARC_worldGateTriggerRadiusM", 18];
if (!(_triggerRadius isEqualType 0)) then { _triggerRadius = 18; };
_triggerRadius = (_triggerRadius max 6) min 60;

private _raiseDelay = missionNamespace getVariable ["ARC_worldGateAutoRaiseDelayS", 5];
if (!(_raiseDelay isEqualType 0)) then { _raiseDelay = 5; };
_raiseDelay = (_raiseDelay max 0) min 30;

private _lowerDelay = missionNamespace getVariable ["ARC_worldGateAutoLowerDelayS", 10];
if (!(_lowerDelay isEqualType 0)) then { _lowerDelay = 10; };
_lowerDelay = (_lowerDelay max 2) min 60;

// Gate definitions [barrierVarName, guardpostVarName, label]
private _gateDefs = [
    ["ARC_barrier_north", "ARC_guardpost_north", "North Gate"],
    ["ARC_barrier_main",  "ARC_guardpost_main",  "Main Gate"],
    ["ARC_barrier_south", "ARC_guardpost_south", "South Gate"]
];

private _gatesInit = 0;

{
    _x params ["_barrierVar", "_guardVar", "_label"];

    private _barrier  = missionNamespace getVariable [_barrierVar, objNull];
    if (!(_barrier isEqualType objNull)) then { _barrier = objNull; };
    if (isNull _barrier) then { continue; };

    private _guardObj = missionNamespace getVariable [_guardVar, objNull];

    private _triggerPos = getPosATL _barrier;

    // Spawn a per-gate control loop
    [_barrier, _guardObj, _label, _triggerRadius, _raiseDelay, _lowerDelay, _triggerPos] spawn
    {
        params ["_barrier", "_guardObj", "_label", "_triggerRadius", "_raiseDelay", "_lowerDelay", "_gatePos"];

        private _isOpen   = false;
        private _lastOpen = -1;

        diag_log format ["[ARC][WORLD] worldGateBarrierInit: '%1' gate loop started.", _label];

        while { !isNull _barrier } do
        {
            // Detect nearest BLUFOR vehicle within trigger radius
            private _nearVehicles = _gatePos nearEntities [["Car", "Truck", "Tank", "Motorcycle"], _triggerRadius];
            private _hasBlufor = false;
            private _hasOther  = false;

            {
                if (side (group _x) isEqualTo west) then
                {
                    if (_x != (vehicle _x) || { (vehicle _x) != _x }) then { _hasBlufor = true; };
                };
            } forEach _nearVehicles;

            // Open gate for BLUFOR approach
            if (_hasBlufor && { !_isOpen }) then
            {
                sleep _raiseDelay;
                if (!isNull _barrier) then
                {
                    _barrier animate ["Door_1_rot", 1, true];
                    _barrier animate ["Door_2_rot", 1, true];
                    _isOpen = true;
                    _lastOpen = serverTime;
                    diag_log format ["[ARC][WORLD] Gate %1: opened for BLUFOR vehicle.", _label];
                };
            };

            // Auto-close after vehicles have passed (no BLUFOR present + delay elapsed)
            if (!_hasBlufor && { _isOpen } && { _lastOpen > 0 } && { (serverTime - _lastOpen) > _lowerDelay }) then
            {
                if (!isNull _barrier) then
                {
                    _barrier animate ["Door_1_rot", 0, true];
                    _barrier animate ["Door_2_rot", 0, true];
                    _isOpen = false;
                    diag_log format ["[ARC][WORLD] Gate %1: auto-closed (no BLUFOR).", _label];
                };
            };

            sleep 2;
        };
    };

    _gatesInit = _gatesInit + 1;
    diag_log format ["[ARC][WORLD] worldGateBarrierInit: gate '%1' initialized.", _label];
} forEach _gateDefs;

diag_log format ["[ARC][WORLD] worldGateBarrierInit: %1 gates initialized.", _gatesInit];

_gatesInit
