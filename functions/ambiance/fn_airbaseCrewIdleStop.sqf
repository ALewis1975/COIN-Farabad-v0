/*
    AIRBASESUB: Stop ambient animations on crew units.

    Params:
      0: ARRAY<OBJECT> - units

    Returns:
      BOOL
*/

params [ ["_units", [], [[], objNull]] ];

if (!(_units isEqualType [])) then { _units = [_units]; };

{
    if (isNull _x) then { continue; };
    if (!isNil "BIS_fnc_ambientAnim__terminate") then { [_x] call BIS_fnc_ambientAnim__terminate; };
} forEach _units;

true
