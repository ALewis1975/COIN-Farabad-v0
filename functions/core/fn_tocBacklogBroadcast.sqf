/*
    ARC_fnc_tocBacklogBroadcast

    Server: publish a compact, JIP-safe snapshot of the TOC Queue (backlog) so
    that both field consoles (OPS lead panel) and TOC consoles can show, at a
    glance, that a lead has been generated and is sitting in the TOC Queue for
    follow-up.

    The backlog itself (server state "tocBacklog") is authoritative; this only
    publishes a trimmed read model for the UI.

    Published vars:
      ARC_pub_tocBacklog          = [[leadId, priority, leadType, leadName, zone, enqueuedAt], ...]
      ARC_pub_tocBacklogUpdatedAt = serverTime

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

private _trimFn = compile "params ['_s']; trim _s";

private _back = ["tocBacklog", []] call ARC_fnc_stateGet;
if (!(_back isEqualType [])) then { _back = []; };

private _out = [];
{
    // Backlog record shape:
    // [leadId, priority, enqueuedAt, sourceQueueId, by, note, leadType, leadName, zone, tag]
    if (_x isEqualType [] && { (count _x) >= 3 }) then
    {
        private _e = _x;

        private _lid = _e select 0;
        if (!(_lid isEqualType "")) then { _lid = ""; };
        _lid = [_lid] call _trimFn;

        if (!(_lid isEqualTo "")) then
        {
            private _pri = _e select 1;
            if (!(_pri isEqualType 0)) then { _pri = 3; };
            _pri = round _pri;
            _pri = (_pri max 1) min 5;

            private _at = _e select 2;
            if (!(_at isEqualType 0)) then { _at = 0; };

            private _lt = if ((count _e) >= 7 && { (_e select 6) isEqualType "" }) then { toUpper ([_e select 6] call _trimFn) } else { "" };
            private _ln = if ((count _e) >= 8 && { (_e select 7) isEqualType "" }) then { [_e select 7] call _trimFn } else { "" };
            private _zn = if ((count _e) >= 9 && { (_e select 8) isEqualType "" }) then { [_e select 8] call _trimFn } else { "" };

            _out pushBack [_lid, _pri, _lt, _ln, _zn, _at];
        };
    };
} forEach _back;

missionNamespace setVariable ["ARC_pub_tocBacklog", _out, true];
missionNamespace setVariable ["ARC_pub_tocBacklogUpdatedAt", serverTime, true];

true
