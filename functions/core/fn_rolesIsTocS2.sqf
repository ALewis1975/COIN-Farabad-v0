/*
    ARC_fnc_rolesIsTocS2

    Returns TRUE if the unit is assigned to the TOC S2 layer.

    Detection:
      - groupId contains "REDFALCON S2" (or "FALCON S2" as a generic fallback)

    Params:
      0: OBJECT unit

    Returns:
      BOOL
*/

params [ ["_unit", objNull, [objNull]] ];
if (isNull _unit) exitWith {false};

[_unit, ["REDFALCON S2", "FALCON S2"]] call ARC_fnc_rolesHasGroupIdToken
