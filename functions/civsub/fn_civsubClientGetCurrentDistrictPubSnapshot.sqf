/*
    ARC_fnc_civsubClientGetCurrentDistrictPubSnapshot

    Convenience helper for client debugging.

    Returns: [districtId, pubSnapshotArray]

    Notes:
      - Uses ARC_fnc_civsubDistrictsFindByPosLocal to determine current district.
      - Reads civsub_v1_district_pub_<DID> which is published by CIVSUB tick/delta.
*/

if (!hasInterface) exitWith {["", []]};
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith {["", []]};

private _did = [getPosATL player] call ARC_fnc_civsubDistrictsFindByPosLocal;
if (_did isEqualTo "") exitWith {["", []]};

private _key = format ["civsub_v1_district_pub_%1", _did];
private _snap = missionNamespace getVariable [_key, []];

[_did, _snap]
