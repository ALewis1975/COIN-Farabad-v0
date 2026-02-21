/*
    ARC_fnc_iedClientEnableEvidenceLogistics

    Client: enable ACE drag/carry + ACE cargo load for an IED evidence object.

    Params:
      0: STRING evidenceNetId
      1: NUMBER cargoSize (optional, default 1)
      2: BOOL enableCarry (optional, default true)
      3: BOOL enableDrag (optional, default true)

    Returns:
      BOOL

    Notes:
      - Safe no-op if ACE is not present.
      - Intended to be called via remoteExec with JIP enabled.
*/

if (!hasInterface) exitWith {false};

params [
    ["_nid", "", [""]],
    ["_cargoSize", 1, [0]],
    ["_enableCarry", true, [true,false]],
    ["_enableDrag", true, [true,false]]
];

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

_nid = [_nid] call _trimFn;
if (_nid isEqualTo "") exitWith {false};

// ACE presence checks (avoid hard dependency)
if !(isClass (configFile >> "CfgPatches" >> "ace_main")) exitWith {false};
if (isNil "ace_cargo_fnc_setSize") exitWith {false};
if (isNil "ace_dragging_fnc_setCarryable") exitWith {false};
if (isNil "ace_dragging_fnc_setDraggable") exitWith {false};

private _obj = objectFromNetId _nid;
if (isNull _obj) exitWith {false};

if (_obj getVariable ["ARC_eodEvidenceAceEnabled", false]) exitWith {true};

// Cargo sizing (ACE cargo)
if (!(_cargoSize isEqualType 0) || { _cargoSize < 0 }) then { _cargoSize = 1; };
_cargoSize = (_cargoSize max 0) min 10;
[_obj, _cargoSize] call ace_cargo_fnc_setSize;

// Drag/carry enablement
if (_enableCarry) then
{
    // params: [object, enabled, carryPosition, direction, ignoreWeight, ...]
    [_obj, true, [0, 1.0, 1.0], 0, false, false] call ace_dragging_fnc_setCarryable;
};

if (_enableDrag) then
{
    [_obj, true, [0, 1.5, 0.0], 0, false, false] call ace_dragging_fnc_setDraggable;
};

_obj setVariable ["ARC_eodEvidenceAceEnabled", true, true];
true
