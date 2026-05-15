/*
    ARC_fnc_recruitClientInit

    Client: discover configured Huron cargo recruitment containers and attach
    local addActions.

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

if (!(missionNamespace getVariable ["ARC_recruitContainerEnabled", true])) exitWith {false};

private _classes = missionNamespace getVariable ["ARC_recruitContainerClasses", ["B_Slingload_01_Cargo_F"]];
if (!(_classes isEqualType [])) then { _classes = ["B_Slingload_01_Cargo_F"]; };

private _positions = missionNamespace getVariable ["ARC_recruitContainerPositions", []];
if (!(_positions isEqualType [])) then { _positions = []; };

private _radius = missionNamespace getVariable ["ARC_recruitContainerPositionRadiusM", 18];
if (!(_radius isEqualType 0)) then { _radius = 18; };
_radius = (_radius max 2) min 50;

private _containers = [];
{
    private _class = _x;
    if (!(_class isEqualType "")) then { continue; };
    {
        private _container = _x;
        if (isNull _container) then { continue; };

        private _allowed = (count _positions) isEqualTo 0;
        if (!_allowed) then
        {
            {
                if (_x isEqualType [] && { (count _x) >= 2 }) then
                {
                    private _p = +_x;
                    _p resize 3;
                    if ((_container distance2D _p) <= _radius) exitWith { _allowed = true; };
                };
            } forEach _positions;
        };

        if (_allowed) then { _containers pushBackUnique _container; };
    } forEach (allMissionObjects _class);
} forEach _classes;

{
    [_x] call ARC_fnc_recruitClientAddActions;
} forEach _containers;

true
