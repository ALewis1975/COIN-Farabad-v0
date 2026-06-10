/*
    ARC_fnc_idleGateActive

    Server-only idle gate for background simulation ticks.

    Returns true when the server should pause idle-gated work (ambient lead
    generation, medical/sustainment decay, ambient spawn ticks) because no
    interfaced human players are connected. Headless clients do not count as
    interfaced players.

    Behaviour:
      - Disabled entirely via ARC_idleGateEnabled = false (always returns false).
      - A grace period (ARC_idleGateGraceS, default 300 s) must elapse with no
        interfaced players before the gate engages. During the grace window,
        gated ticks keep running so proximity-driven despawn/cleanup logic
        (civ caps, sitepop grace, traffic pruning) can wind ambience down first.
      - Result is cached per engine frame (same pattern as ARC_fnc_playerSnapshot)
        so multiple gated ticks in one frame cost a single allPlayers scan.
      - Logs once on each pause/resume transition; never silent on state change.

    State (server-local, non-broadcast):
      ARC_idleGateFrame    — diag_frameNo of the cached result
      ARC_idleGateState    — cached BOOL result
      ARC_idleGateSinceAt  — serverTime when the server first became empty (-1 when occupied)

    Params: none
    Returns: BOOL — true when idle-gated ticks should be skipped
*/

if (!isServer) exitWith { false };
if !(missionNamespace getVariable ["ARC_idleGateEnabled", true]) exitWith { false };

private _frame = diag_frameNo;
private _cachedFrame = missionNamespace getVariable ["ARC_idleGateFrame", -1];
if (_cachedFrame isEqualTo _frame) exitWith {
    missionNamespace getVariable ["ARC_idleGateState", false]
};

private _interfaced = 0;
{
    if (isPlayer _x && { !(_x isKindOf "HeadlessClient_F") }) then {
        _interfaced = _interfaced + 1;
    };
} forEach allPlayers;

private _wasIdle = missionNamespace getVariable ["ARC_idleGateState", false];
if (!(_wasIdle isEqualType true)) then { _wasIdle = false; };

private _idle = false;
if (_interfaced > 0) then {
    if (_wasIdle) then {
        diag_log format ["[ARC][IDLE][INFO] ARC_fnc_idleGateActive: interfaced player connected (n=%1) — resuming idle-gated ticks.", _interfaced];
    };
    missionNamespace setVariable ["ARC_idleGateSinceAt", -1];
} else {
    private _since = missionNamespace getVariable ["ARC_idleGateSinceAt", -1];
    if (!(_since isEqualType 0)) then { _since = -1; };
    if (_since < 0) then {
        _since = serverTime;
        missionNamespace setVariable ["ARC_idleGateSinceAt", _since];
    };

    private _graceS = missionNamespace getVariable ["ARC_idleGateGraceS", 300];
    if (!(_graceS isEqualType 0)) then { _graceS = 300; };
    _graceS = (_graceS max 0) min 3600;

    _idle = (serverTime - _since) >= _graceS;
    if (_idle && { !_wasIdle }) then {
        diag_log format ["[ARC][IDLE][INFO] ARC_fnc_idleGateActive: no interfaced players for %1 s — pausing idle-gated ticks.", _graceS];
    };
};

missionNamespace setVariable ["ARC_idleGateFrame", _frame];
missionNamespace setVariable ["ARC_idleGateState", _idle];

_idle
