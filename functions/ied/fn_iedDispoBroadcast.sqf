/*
    ARC_fnc_iedDispoBroadcast

    Server: publish EOD disposition approvals (JIP-safe) into missionNamespace.

    Published variables:
      ARC_pub_eodDispoApprovals = [approval,...]

    Approval format:
      [
        0: STRING taskId,
        1: STRING groupId,
        2: STRING requestType (DET_IN_PLACE|RTB_IED|TOW_VBIED),
        3: NUMBER approvedAt,
        4: STRING approvedBy,
        5: NUMBER expiresAt,
        6: STRING note
      ]
*/

if (!isServer) exitWith {false};

private _appr = ["eodDispoApprovals", []] call ARC_fnc_stateGet;
if (!(_appr isEqualType [])) then { _appr = []; };

// Filter expired approvals
private _now = serverTime;
private _out = [];
{
    if (!(_x isEqualType []) || { (count _x) < 6 }) then { continue; };
    private _exp = _x # 5;
    if (!(_exp isEqualType 0)) then { _exp = -1; };
    if (_exp >= 0 && { _now > _exp }) then { continue; };
    _out pushBack _x;
} forEach _appr;

missionNamespace setVariable ["ARC_pub_eodDispoApprovals", _out, true];
missionNamespace setVariable ["ARC_pub_eodDispoApprovalsUpdatedAt", _now, true];

true
