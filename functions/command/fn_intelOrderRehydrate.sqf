/* Existing startup/join/maintenance hooks retry when owning groups exist. */
if (!isServer) exitWith {0};
params [["_joiner",objNull,[objNull]]];
private _orders = ["tocOrders",[]] call ARC_fnc_stateGet;
if (!(_orders isEqualType [])) exitWith {0};
private _created = 0;
{
    if ([_x,false,_joiner] call ARC_fnc_intelOrderEnsureTask) then {_created = _created + 1;};
} forEach _orders;
_created
