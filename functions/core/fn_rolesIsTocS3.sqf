/*
    ARC_fnc_rolesIsTocS3

    Returns TRUE if the unit is assigned to the TOC S3 layer.

    Detection:
      - groupId contains "REDFALCON S3" / "REDFALCON TOC" (or "FALCON S3" / "FALCON TOC" as a generic fallback)

    Params:
      0: OBJECT unit

    Returns:
      BOOL
*/

params [ ["_unit", objNull, [objNull]] ];
if (isNull _unit) exitWith {false};

[_unit, ["REDFALCON S3", "FALCON S3", "REDFALCON TOC", "FALCON TOC"]] call ARC_fnc_rolesHasGroupIdToken
