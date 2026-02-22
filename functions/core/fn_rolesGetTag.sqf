/*
    Returns a standardized leadership tag used in logs / audit trails.

    IMPORTANT:
      - Authorization is handled by ARC_fnc_rolesIsAuthorized.
      - This tag is *display only*.

    Current tagging method (requested): RHSUSAF classnames.

    Tags:
      OFFICER  - classname ends with "_officer" (e.g., rhsusf_army_ocp_officer)
      SL       - classname ends with "_squadleader" (e.g., rhsusf_army_ocp_squadleader)
*/

params [["_unit", objNull, [objNull]]];
if (isNull _unit) exitWith {""};

private _cls = toLower (typeOf _unit);
private _tag = "";

// Keep tags RHSUSAF-scoped to avoid false positives from other mods.
if ((_cls find "rhsusf_") isNotEqualTo 0) exitWith {""};

private _len = count _cls;
private _sufOfficer = "_officer";
private _sufSL = "_squadleader";

if ((count _sufOfficer) <= _len && { (_cls select [_len - (count _sufOfficer), (count _sufOfficer)]) isEqualTo _sufOfficer }) exitWith {"OFFICER"};
if ((count _sufSL) <= _len && { (_cls select [_len - (count _sufSL), (count _sufSL)]) isEqualTo _sufSL }) exitWith {"SL"};

""
