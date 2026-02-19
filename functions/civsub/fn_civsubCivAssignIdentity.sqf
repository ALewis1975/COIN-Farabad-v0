/*
    ARC_fnc_civsubCivAssignIdentity

    Params:
      0: unit (object)
      1: districtId (string)

    Side effects:
      - Assigns a stable civ_uid to the unit WITHOUT touching persistence.
      - Sets unit variables: civ_uid, civsub_districtId
      - Adds ACE interaction actions (client-side) if enabled.
*/

if (!isServer) exitWith {false};

params [
    ["_unit", objNull, [objNull]],
    ["_districtId", "", [""]]
];
if (isNull _unit) exitWith {false};
if (_districtId isEqualTo "") exitWith {false};

private _civUid = _unit getVariable ["civ_uid", ""];
if (_civUid isEqualTo "") then {
    _civUid = [_districtId] call ARC_fnc_civsubIdentityGenerateUid;
};

_unit setVariable ["civ_uid", _civUid, true];
_unit setVariable ["civsub_districtId", _districtId, true];
// Tag this unit as a CIVSUB-managed civilian so global mission event handlers can filter safely.
_unit setVariable ["civsub_v1_isCiv", true, true];

// Phase 7: add ACE interactions client-side (safe no-op if ACE absent)
if (missionNamespace getVariable ["civsub_v1_interactions_enabled", true]) then {
    // Use the unit as the JIP key so joining clients also get the actions.
    // ALiVE-style contact actions (two addActions: Stop + Interact)
    [_unit] remoteExecCall ["ARC_fnc_civsubCivAddContactActions", 0, _unit];

    // Legacy ACE interactions (kept for now; trimmed to SHERIFF-only in Step 5)
    [_unit] remoteExecCall ["ARC_fnc_civsubCivAddAceActions", 0, _unit];

    diag_log format ["[CIVSUB][IDENTITY] Queued client actions for unit netId=%1 district=%2", netId _unit, _districtId];
};

true
