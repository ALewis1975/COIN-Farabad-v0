/*
    ARC_fnc_casreqSnapshotGet

    Returns a full CASREQ snapshot contract for one CASREQ record.
*/

if (!isServer) exitWith {[]};

params [
    ["_casreqId", "", [""]]
];

private _records = ["casreq_v1_records", createHashMap] call ARC_fnc_stateGet;
if !(_records isEqualType createHashMap) exitWith { [] };

private _snapshot = _records getOrDefault [_casreqId, []];
if !(_snapshot isEqualType []) then { _snapshot = []; };

private _requiredKeys = [
    "casreq_id",
    "district_id",
    "state",
    "requester",
    "area",
    "messages",
    "created_at",
    "updated_at"
];

{
    private _k = _x;
    private _idx = _snapshot findIf { _x isEqualType [] && { (count _x) >= 2 } && { ((_x select 0) isEqualTo _k) } };
    if (_idx < 0) then {
        private _def = switch (_k) do {
            case "casreq_id": { _casreqId };
            case "messages": { [] };
            case "area": { [["target_pos", [0,0,0]], ["target_marker", ""]] };
            case "created_at": { serverTime };
            case "updated_at": { serverTime };
            default { "" };
        };
        _snapshot pushBack [_k, _def];
    };
} forEach _requiredKeys;

_snapshot
