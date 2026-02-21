/*
    ARC_fnc_vbiedServerOnDestroyed

    Server: handle VBIED vehicle destruction outcomes.

    This function enforces Phase 5 rules:
      - Disposal credit only when TOC approval exists AND VBIED is safe AND vehicle is destroyed at the disposal site.
      - If destroyed without approval or outside the site, record an adverse outcome and keep SITREP gating intact.

    Params:
      0: STRING vbiedVehicleNetId
      1: OBJECT killer (optional)
      2: OBJECT instigator (optional)

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ['_vehNid','',['']],
    ['_killer',objNull,[objNull]],
    ['_instigator',objNull,[objNull]]
];

// sqflint-compat helpers
private _trimFn     = compile "params ['_s']; trim _s";

_vehNid = [_vehNid] call _trimFn;
if (_vehNid isEqualTo '') exitWith {false};

private _curVehNid = ['activeVbiedVehicleNetId',''] call ARC_fnc_stateGet;
if (!(_curVehNid isEqualType '' )) then { _curVehNid = ''; };
if (_curVehNid isEqualTo '' || { !(_curVehNid isEqualTo _vehNid) }) exitWith {false};

// If the VBIED detonated via the detonation pipeline, do not double-handle.
private _det = ['activeVbiedDetonated', false] call ARC_fnc_stateGet;
if (!(_det isEqualType true) && !(_det isEqualType false)) then { _det = false; };
if (_det) exitWith {false};

// Idempotence: if already disposed/destroyed, no-op.
private _disposed = ['activeVbiedDisposed', false] call ARC_fnc_stateGet;
if (!(_disposed isEqualType true) && !(_disposed isEqualType false)) then { _disposed = false; };
if (_disposed) exitWith {true};

private _destroyed = ['activeVbiedDestroyed', false] call ARC_fnc_stateGet;
if (!(_destroyed isEqualType true) && !(_destroyed isEqualType false)) then { _destroyed = false; };
if (_destroyed) exitWith {true};

private _taskId = ['activeTaskId',''] call ARC_fnc_stateGet;
if !(_taskId isEqualType '' && { !(_taskId isEqualTo '') }) exitWith {false};

private _gid = ['activeIncidentAcceptedByGroup',''] call ARC_fnc_stateGet;
if !(_gid isEqualType '' && { !(_gid isEqualTo '') }) then { _gid = ''; };

private _mkr = missionNamespace getVariable ['ARC_eodDisposalMarkerName','mkr_eod_disposal'];
if !(_mkr isEqualType '') then { _mkr = 'mkr_eod_disposal'; };

private _rad = missionNamespace getVariable ['ARC_eodDisposalRadiusM',12];
if !(_rad isEqualType 0) then { _rad = 12; };
_rad = (_rad max 3) min 80;

private _sitePos = getMarkerPos _mkr;
if !(_sitePos isEqualType [] && { (count _sitePos) >= 2 }) then { _sitePos = [0,0,0]; };
_sitePos = +_sitePos; _sitePos resize 3;

private _safe = ['activeVbiedSafe', false] call ARC_fnc_stateGet;
if (!(_safe isEqualType true) && !(_safe isEqualType false)) then { _safe = false; };

// Approval check (published approvals should already be filtered for expiry)
private _hasApproval = false;
private _appr = missionNamespace getVariable ['ARC_pub_eodDispoApprovals', []];
if (_appr isEqualType [] && { !(_gid isEqualTo '') }) then
{
    {
        if !(_x isEqualType [] && { (count _x) >= 6 }) then { continue; };
        if (!((_x select 0) isEqualTo _taskId)) then { continue; };
        if (!((_x select 1) isEqualTo _gid)) then { continue; };
        if ((toUpper ([(_x select 2)] call _trimFn)) != 'TOW_VBIED') then { continue; };
        private _exp = _x select 5;
        if (!(_exp isEqualType 0)) then { _exp = -1; };
        if (_exp >= 0 && { serverTime > _exp }) then { continue; };
        _hasApproval = true;
        break;
    } forEach _appr;
};

// Determine location using last-known vehicle position (fallback to stored objective pos)
private _pos = ['activeObjectivePos', []] call ARC_fnc_stateGet;
if !(_pos isEqualType [] && { (count _pos) >= 2 }) then { _pos = [0,0,0]; };
_pos = +_pos; _pos resize 3;
_pos set [2, 0];

private _atSite = false;
if !(_sitePos isEqualTo [0,0,0]) then
{
    _atSite = ((_pos distance2D _sitePos) <= _rad);
};

private _cause = '';
if (_hasApproval && _safe && _atSite) then
{
    _cause = 'VBIED_DISPOSED_AT_SITE';
    ['activeVbiedDisposed', true] call ARC_fnc_stateSet;
    ['activeVbiedDisposedAt', serverTime] call ARC_fnc_stateSet;

    private _by = 'UNKNOWN';
    private _uid = '';
    private _actor = if (!isNull _instigator) then { _instigator } else { _killer };
    if (!isNull _actor) then { _by = name _actor; _uid = getPlayerUID _actor; };

    ['activeVbiedDisposedBy', _by] call ARC_fnc_stateSet;
    ['activeVbiedDisposedByUID', _uid] call ARC_fnc_stateSet;

    missionNamespace setVariable ['ARC_activeVbiedDisposed', true, true];
    missionNamespace setVariable ['ARC_activeVbiedDisposedAt', serverTime, true];
    missionNamespace setVariable ['ARC_activeVbiedDisposedBy', _by, true];

    private _grid = mapGridPosition _pos;
    ['TECHINT', format ['VBIED disposed at EOD site (%1).', _grid], _pos,
        [
            ['event', _cause],
            ['taskId', _taskId],
            ['grid', _grid],
            ['approved', true],
            ['atDisposalSite', true],
            ['disposedBy', _by],
            ['disposedByUID', _uid]
        ]
    ] call ARC_fnc_intelLog;

    private _thr = [_taskId, 'IED', 'VBIED', [['pos', _pos]]] call ARC_fnc_threatCreateFromTask;
    if (!(_thr isEqualTo '')) then { [_thr, 'NEUTRALIZED', _cause] call ARC_fnc_threatUpdateState; };

    [] call ARC_fnc_threatDebugSnapshot;

    true
}
else
{
    if (!_hasApproval) then { _cause = 'VBIED_DESTROYED_UNAPPROVED'; } else { _cause = 'VBIED_DESTROYED_OUTSIDE_SITE_APPROVED'; };

    ['activeVbiedDestroyed', true] call ARC_fnc_stateSet;
    ['activeVbiedDestroyedAt', serverTime] call ARC_fnc_stateSet;
    ['activeVbiedDestroyedCause', _cause] call ARC_fnc_stateSet;

    missionNamespace setVariable ['ARC_activeVbiedDestroyed', true, true];
    missionNamespace setVariable ['ARC_activeVbiedDestroyedAt', serverTime, true];
    missionNamespace setVariable ['ARC_activeVbiedDestroyedCause', _cause, true];

    private _grid = mapGridPosition _pos;
    ['OPS', format ['VBIED destroyed (%1) at %2.', _cause, _grid], _pos,
        [
            ['event', _cause],
            ['taskId', _taskId],
            ['grid', _grid],
            ['approved', _hasApproval],
            ['atDisposalSite', _atSite],
            ['safe', _safe]
        ]
    ] call ARC_fnc_intelLog;

    private _thr = [_taskId, 'IED', 'VBIED', [['pos', _pos]]] call ARC_fnc_threatCreateFromTask;
    if (!(_thr isEqualTo '')) then { [_thr, 'CLOSED', _cause] call ARC_fnc_threatUpdateState; };

    [] call ARC_fnc_threatDebugSnapshot;

    true
};
