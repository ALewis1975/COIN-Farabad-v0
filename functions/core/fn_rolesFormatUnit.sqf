/*
    Returns a short, log-friendly identifier for a player/unit.

    Format (best effort):
      <groupId> [<roleTag>] (<name>)

    Examples:
      REDFALCON 3-6 [OFFICER] (Sgt. Smith)
      3-1-A [SL] (Jones)
*/

params ["_unit"];
if (isNull _unit) exitWith {"<null>"};

private _name = name _unit;
private _grp = group _unit;
private _gid = if (!isNull _grp) then { groupId _grp } else {""};
private _tag = [_unit] call ARC_fnc_rolesGetTag;

private _out = "";

if (!(_gid isEqualTo "")) then { _out = _gid; } else { _out = "UNASSIGNED"; };
if (!(_tag isEqualTo "")) then { _out = format ["%1 [%2]", _out, _tag]; };
if (!(_name isEqualTo "")) then { _out = format ["%1 (%2)", _out, _name]; };

_out
