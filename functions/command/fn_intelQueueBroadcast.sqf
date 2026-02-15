/*
    ARC_fnc_intelQueueBroadcast

    Server: publish a JIP-safe snapshot of the TOC request queue for clients.

    We broadcast both:
      - PENDING items (for immediate TOC action)
      - A short queue tail (for visibility/audit in the diary)

    Published vars:
      ARC_pub_queue           = [PENDING queueItem,...]   (compat)
      ARC_pub_queuePending    = [PENDING queueItem,...]
      ARC_pub_queueTail       = [queueItem,...]           (last N, includes decisions)
      ARC_pub_queueUpdatedAt  = serverTime

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _q = ["tocQueue", []] call ARC_fnc_stateGet;
if (!(_q isEqualType [])) then { _q = []; };

private _pending = [];
{
    if (_x isEqualType [] && { (count _x) >= 12 }) then
    {
        // [id, createdAt, status, kind, from, fromGroup, fromUID, pos, summary, details, payload, meta, decision]
        private _st = _x # 2;
        if (_st isEqualType "" && { toUpper _st isEqualTo "PENDING" }) then
        {
            _pending pushBack _x;
        };
    };
} forEach _q;

// Tail (includes APPROVED/REJECTED for visibility)
private _tailN = missionNamespace getVariable ["ARC_tocQueueTailBroadcast", 12];
if (!(_tailN isEqualType 0)) then { _tailN = 12; };
_tailN = (_tailN max 5) min 50;

private _tail = +_q;
private _ct = count _q;
if (_ct > _tailN) then
{
    _tail = _q select [_ct - _tailN, _tailN];
};

// Compat + explicit vars
missionNamespace setVariable ["ARC_pub_queue", _pending, true];
missionNamespace setVariable ["ARC_pub_queuePending", _pending, true];
missionNamespace setVariable ["ARC_pub_queueTail", _tail, true];
missionNamespace setVariable ["ARC_pub_queueUpdatedAt", serverTime, true];

true
