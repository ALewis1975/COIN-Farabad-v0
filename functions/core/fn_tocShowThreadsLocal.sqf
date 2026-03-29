/*
    Client: show intel thread/case summaries.

    Reads missionNamespace:
      - ARC_threadsPublic
      - ARC_threadsPublicUpdatedAt
      - ARC_activeThreadId (optional)

    Thread summary format:
      [id, type, zoneBias, grid, confidence, heat, commanderState, fuSuccess, fuFail, lastTouchedAt, cooldownUntil, lastCommandNodeAt, parentTaskId, districtId]

    Returns:
      BOOL

    Debug-only operator helper: keeps local HINT channel output for quick thread triage.
*/

if (!hasInterface) exitWith {false};

private _threads = missionNamespace getVariable ["ARC_threadsPublic", []];
private _upd = missionNamespace getVariable ["ARC_threadsPublicUpdatedAt", -1];
private _active = missionNamespace getVariable ["ARC_activeThreadId", ""];

if (!(_threads isEqualType [])) then { _threads = []; };

private _ageTxt = if (_upd < 0) then {"(no server broadcast yet)"} else { format ["(updated %1s ago)", round (serverTime - _upd)] };

private _txt = format ["Intel Threads %1\n", _ageTxt];

if (_threads isEqualTo []) exitWith
{
    [(_txt + "(none yet)\n\nThreads appear after follow-up leads are generated."), "INFO", "HINT"] call ARC_fnc_clientHint;
    true
};

private _fmtType = {
    // Accept either a string or a single-element array (older call sites used [_type] call _fmtType).
    private _t = _this;
    if (_t isEqualType []) then
    {
        _t = if ((count _t) > 0) then { _t # 0 } else { "" };
    };
    if !(_t isEqualType "") exitWith { str _t };

    private _tU = toUpper _t;
    switch (_tU) do
    {
        case "IED_CELL": {"IED Cell"};
        case "INSIDER_NETWORK": {"Insider Network"};
        case "SMUGGLING_RING": {"Smuggling Ring"};
        default { _t };
    };
};

{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 12) then { continue; };

    _x params [
        "_id",
        "_type",
        "_zone",
        "_grid",
        ["_conf", 0],
        ["_heat", 0],
        ["_state", ""],
        ["_suc", 0],
        ["_fail", 0],
        ["_touch", -1],
        ["_cd", -1],
        ["_last", -1],
        ["_parent", ""],
        ["_districtId", ""]
    ];

    private _star = if (_active isEqualType "" && { !(_active isEqualTo "") } && { _id isEqualTo _active }) then {"> "} else {"- "};

    private _minsSince = if (_touch > 0) then { floor ((_touch - serverTime) / 60) } else { -1 };
    private _sinceTxt = if (_touch > 0) then { format ["touched %1m ago", floor ((serverTime - _touch) / 60)] } else { "touched ?" };

    private _cdTxt = "";
    if (_cd > serverTime) then
    {
        _cdTxt = format [" | cooldown %1m", floor ((_cd - serverTime) / 60)];
    };

    _txt = _txt + format [
        "%1%2 | %3 | %4 | CONF %5 | HEAT %6 | FU %7/%8 | %9%10%11\n",
        _star,
        _id,
        _type call _fmtType,
        _grid,
        (round (_conf * 100)),
        (round (_heat * 100)),
        _suc,
        _fail,
        toUpper _state,
        _cdTxt,
        if (_districtId isEqualTo "") then { "" } else { format [" | DIST %1", _districtId] }
    ];

} forEach _threads;

_txt = _txt + "\nTip: Command node opportunities surface when confidence is high and heat stays manageable.";

[_txt, "INFO", "HINT"] call ARC_fnc_clientHint;
true
