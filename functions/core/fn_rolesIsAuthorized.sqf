/*
    Returns true if the unit is authorized to accept tasks / send SITREPs.

    IMPORTANT:
      - We now authorize by *classnames*, not Eden roles / roleDescription tokens.

    Default rule (requested): RHSUSAF leadership classes
      - Classname prefix: rhsusf_
      - Classname suffixes: _officer, _squadleader

    Examples (RHSUSAF):
      rhsusf_army_ocp_officer
      rhsusf_army_ucp_officer
      rhsusf_army_ocp_squadleader
      rhsusf_army_ucp_squadleader
      rhsusf_army_ocp_arb_squadleader
      rhsusf_army_ucp_arb_squadleader

    Optional overrides (missionNamespace):
      ARC_authorizedRoleClassnames      : ARRAY of exact classnames (strings)
      ARC_authorizedRoleClassPrefixes   : ARRAY of prefixes (default ["rhsusf_"])
      ARC_authorizedRoleClassSuffixes   : ARRAY of suffixes (default ["_officer","_squadleader"])
*/

params ["_unit"];
if (isNull _unit) exitWith {false};

private _cls = toLower (typeOf _unit);

// 1) Exact allow-list (optional)
private _exact = missionNamespace getVariable ["ARC_authorizedRoleClassnames", []];
if (!(_exact isEqualType [])) then { _exact = []; };
_exact = _exact apply { toLower _x };
if (_cls in _exact) exitWith {true};

// 2) Prefix + suffix rules (default RHSUSAF)
private _prefixes = missionNamespace getVariable ["ARC_authorizedRoleClassPrefixes", ["rhsusf_"]];
if (!(_prefixes isEqualType [])) then { _prefixes = ["rhsusf_"]; };
_prefixes = _prefixes apply { toLower _x };

private _suffixes = missionNamespace getVariable ["ARC_authorizedRoleClassSuffixes", ["_officer", "_squadleader"]];
if (!(_suffixes isEqualType [])) then { _suffixes = ["_officer", "_squadleader"]; };
_suffixes = _suffixes apply { toLower _x };

private _prefOk = false;
{
    private _p = _x;
    if (_p isEqualTo "") then { continue; };
    if ((_cls find _p) isEqualTo 0) exitWith { _prefOk = true; };
} forEach _prefixes;
if (!_prefOk) exitWith {false};

private _lenCls = count _cls;
private _ok = false;
{
    private _s = _x;
    private _lenS = count _s;
    if (_lenS <= 0) then { continue; };
    if (_lenS <= _lenCls) then
    {
        if ((_cls select [_lenCls - _lenS, _lenS]) isEqualTo _s) exitWith { _ok = true; };
    };
} forEach _suffixes;

_ok
