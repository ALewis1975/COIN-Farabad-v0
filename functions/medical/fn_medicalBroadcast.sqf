/*
    ARC_fnc_medicalBroadcast

    Server-only: single-writer publisher for the replicated `ARC_pub_baseMed`
    key. Both the recovery tick (`ARC_fnc_medicalTick`) and the casualty
    handler (`ARC_fnc_medicalOnCasualty`) route their replication through
    this helper so the State Ownership Ledger (§3.7, S-OWN-2) shows one
    documented writer rather than two.

    Behaviour:
      - Reads the canonical `baseMed` value from `ARC_state` when no override
        is supplied (or when the supplied value is not a number).
      - Clamps to [0, 1] before replicating.
      - Writes `ARC_pub_baseMed` with the replicated flag.

    Params:
      0: (optional) NUMBER — pre-computed baseMed value. When omitted or not
         a number, the canonical `ARC_state` value is used.

    Returns:
      NUMBER — the value that was published.
*/

if (!isServer) exitWith {0};

params [
    ["_value", -1]
];

private _med = _value;
if (!(_med isEqualType 0) || { _med < 0 }) then
{
    _med = ["baseMed", 0.57] call ARC_fnc_stateGet;
    if (!(_med isEqualType 0)) then { _med = 0.57; };
};

_med = (_med max 0) min 1;
missionNamespace setVariable ["ARC_pub_baseMed", _med, true];
_med
