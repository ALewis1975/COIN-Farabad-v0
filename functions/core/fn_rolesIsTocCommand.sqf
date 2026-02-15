/*
    ARC_fnc_rolesIsTocCommand

    Returns TRUE if the unit is in a TOC command authority slot.

    Detection:
      - groupId contains "REDFALCON 6" (BN CDR)
      - groupId contains "REDFALCON 5" (BN XO)
      - groupId contains "FALCON 6" (BDE CDR, if used)
      - groupId contains "FALCON 5" (BDE XO, if used)

    Notes:
      - For testing and TOC redundancy, BN XO is treated as command authority.

    Params:
      0: OBJECT unit

    Returns:
      BOOL
*/

params [ ["_unit", objNull, [objNull]] ];
if (isNull _unit) exitWith {false};

[_unit, ["REDFALCON 6", "REDFALCON 5", "FALCON 6", "FALCON 5"]] call ARC_fnc_rolesHasGroupIdToken
