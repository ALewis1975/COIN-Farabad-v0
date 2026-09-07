/* Explicit whole inbox for current clients/JIP, including restored records. */
if (!isServer) exitWith {false};
params [["_force", false, [true]]];
private _ids = (["casreq_v1_open_index", []] call ARC_fnc_stateGet) + (["casreq_v1_closed_index", []] call ARC_fnc_stateGet);
private _signature = [missionNamespace getVariable ["ARC_casreq_rev", 0], _ids];
if (!_force && {_signature isEqualTo (localNamespace getVariable ["ARC_casreq_inboxSignature", []])}) exitWith {true};
private _rows = [];
{private _r = [_x] call ARC_fnc_casreqSnapshotGet; if !(_r isEqualTo []) then {_rows pushBack _r}} forEach _ids;
private _inbox = [["version", 1], ["rev", missionNamespace getVariable ["ARC_casreq_rev", 0]], ["updated_at", serverTime], ["open_count", count (["casreq_v1_open_index", []] call ARC_fnc_stateGet)], ["records", _rows]];
missionNamespace setVariable ["ARC_pub_casreqInbox", _inbox, true];
localNamespace setVariable ["ARC_casreq_inboxSignature", _signature];
true
