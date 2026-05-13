/*
    Server: merge all convoy vehicle crews into the lead vehicle's group.

    Extracted from fn_execTickConvoy.sqf; ensures every convoy vehicle's AI crew
    belongs to the lead group so routing and link-up waypoints are deterministic.
    Empty transient groups are cleaned up as a side-effect.

    Params:
        0: ARRAY  - array of convoy vehicles
        1: OBJECT - lead vehicle

    Returns:
        GROUP - the lead group (grpNull on failure)
*/

if (!isServer) exitWith { grpNull };

params [
    ["_vehArr",  [], [[]]],
    ["_leadVeh", objNull, [objNull]]
];

if (!(_vehArr isEqualType []) || { (count _vehArr) == 0 } || { isNull _leadVeh }) exitWith { grpNull };

// Ensure lead has crew and an accessible commander unit.
if (isNull (driver _leadVeh)) then { createVehicleCrew _leadVeh; };
private _ld = driver _leadVeh;
if (isNull _ld) then { _ld = effectiveCommander _leadVeh; };
if (isNull _ld) exitWith { grpNull };

private _gLead = group _ld;
if (isNull _gLead) exitWith { grpNull };

{
    private _veh = _x;
    if (!isNull _veh && { alive _veh }) then
    {
        if (isNull (driver _veh)) then { createVehicleCrew _veh; };
        private _d = driver _veh;
        if (isNull _d) then { _d = effectiveCommander _veh; };

        if (!isNull _d) then
        {
            private _g = group _d;
            if (!(_g isEqualTo _gLead)) then
            {
                private _crew = crew _veh;
                private _crewAI = _crew select { !isPlayer _x };
                if ((count _crewAI) > 0) then { _crewAI joinSilent _gLead; };

                // Clean up empty transient groups to reduce clutter.
                if (!isNull _g && { !(_g isEqualTo _gLead) } && { (count units _g) == 0 }) then
                {
                    deleteGroup _g;
                };
            };
        };
    };
} forEach _vehArr;

_gLead
