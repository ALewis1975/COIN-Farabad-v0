/*
    ARC_fnc_civsubIdentityGenerateUid

    Generates a stable civ_uid string for touched civilians.

    Params:
      0: districtId (string) e.g. "D01"

    Returns: civ_uid (string) e.g. "CIV:D01:000123"

    Notes:
      - Uses missionNamespace sequence counter to ensure uniqueness per campaign.
      - Sequence counter is persisted via FARABAD_CIVSUB_V1_STATE blob.
*/

if (!isServer) exitWith {""};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {""};

params [
    ["_districtId", "", [""]]
];
if (_districtId isEqualTo "") exitWith {""};

private _seq = missionNamespace getVariable ["civsub_v1_identity_seq", 0];
if !(_seq isEqualType 0) then { _seq = 0; };
_seq = _seq + 1;
missionNamespace setVariable ["civsub_v1_identity_seq", _seq, true];

private _num = str _seq;
while { (count _num) < 6 } do { _num = "0" + _num; };

format ["CIV:%1:%2", _districtId, _num]
