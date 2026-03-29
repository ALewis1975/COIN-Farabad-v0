/*
    ARC_fnc_mapClick_onClick

    Internal onMapSingleClick handler.

    Extracts _pos from _this event payload, then delegates to submit/disarm.
*/

if (!hasInterface) exitWith {false};

private _state = uiNamespace getVariable ["ARC_mapClick_state", "IDLE"];
private _cleanupDone = uiNamespace getVariable ["ARC_mapClick_cleanupDone", false];
if (_cleanupDone || {!(_state isEqualTo "ARMED")}) exitWith {false};

uiNamespace setVariable ["ARC_mapClick_state", "CAPTURED"];
onMapSingleClick "";

private _evt = _this;
private _debug = uiNamespace getVariable ["ARC_mapClick_debug", false];
private _payloadType = typeName _evt;
private _payloadShape = if (_evt isEqualType []) then {count _evt} else {-1};

if (_debug) then
{
    diag_log format ["[FARABAD][MAPCLICK][CLICK][DEBUG] payloadType=%1 payloadShape=%2 payload=%3", _payloadType, _payloadShape, _evt];
};

private _a = nil;
private _b = nil;
private _c = nil;
private _d = nil;
if (_evt isEqualType []) then
{
    _evt params ["_a", "_b", "_c", "_d"];
};

private _isNumericPos =
{
    params ["_cand"];

    if (!(_cand isEqualType [])) exitWith {false};
    private _n = count _cand;
    if !(_n in [2, 3]) exitWith {false};

    private _nums = true;
    {
        if !(_x isEqualType 0) exitWith { _nums = false; };
        if (!(finite _x) || {!(_x isEqualTo _x)}) exitWith { _nums = false; };
    } forEach _cand;

    _nums
};

private _pos = [];
private _shapeSource = "none";
if ([_a] call _isNumericPos) then
{
    _pos = +_a;
    _shapeSource = "deterministic[0]";
}
else
{
    {
        private _cand = _x;
        if ([_cand] call _isNumericPos) exitWith
        {
            _pos = +_cand;
            _shapeSource = _forEachIndex;
        };
    } forEach [_b, _a, _c, _d];

    if (_shapeSource isEqualType 0) then
    {
        _shapeSource = format ["fallback[%1]", _shapeSource];
    };
};

if (!([_pos] call _isNumericPos)) exitWith
{
    uiNamespace setVariable ["ARC_mapClick_lastErr", "invalid_click_payload"];
    diag_log format [
        "[FARABAD][MAPCLICK][CLICK][ERR] invalid_click_payload payloadType=%1 payloadShape=%2 a=%3 b=%4 c=%5 d=%6 payload=%7",
        _payloadType,
        _payloadShape,
        _a,
        _b,
        _c,
        _d,
        _evt
    ];
    ["Map click failed: invalid position.", "WARN", "TOAST"] call ARC_fnc_clientHint;
    ["INVALID_CLICK_PAYLOAD"] call ARC_fnc_mapClick_disarm;
    false
};

uiNamespace setVariable ["ARC_mapClick_lastPos", _pos];
diag_log format ["[FARABAD][MAPCLICK][CLICK] pos=%1 source=%2 payloadType=%3 payloadShape=%4", _pos, _shapeSource, _payloadType, _payloadShape];

private _ok = [_pos] call ARC_fnc_mapClick_submit;
private _ctx = uiNamespace getVariable ["ARC_mapClick_ctx", createHashMap];
private _type = toUpper (_ctx getOrDefault ["type", ""]);

if (_ok) then
{
    switch (_type) do
    {
        case "INTEL_LOG":
        {
            private _cat = _ctx getOrDefault ["category", "SIGHTING"];
            private _safeGridPos = [];
            if (_pos isEqualType []) then
            {
                private _n = count _pos;
                if (_n >= 2) then
                {
                    private _x = _pos # 0;
                    private _y = _pos # 1;
                    private _validX = (_x isEqualType 0) && {finite _x} && {_x isEqualTo _x};
                    private _validY = (_y isEqualType 0) && {finite _y} && {_y isEqualTo _y};

                    if (_validX && {_validY}) then
                    {
                        _safeGridPos = [_x, _y];

                        if (_n >= 3) then
                        {
                            private _z = _pos # 2;
                            private _validZ = (_z isEqualType 0) && {finite _z} && {_z isEqualTo _z};
                            if (_validZ) then
                            {
                                _safeGridPos pushBack _z;
                            };
                        };
                    };
                };
            };

            private _grid = if ((count _safeGridPos) >= 2) then
            {
                mapGridPosition _safeGridPos
            }
            else
            {
                diag_log format ["[FARABAD][MAPCLICK][CLICK][WARN] intel_grid_unknown rawPos=%1", _pos];
                "UNKNOWN"
            };

            [format ["Submitted intel (%1) at %2.", _cat, _grid], "INFO", "TOAST"] call ARC_fnc_clientHint;
        };

        case "LEAD_REQ":
        {
            ["Lead request submitted to TOC queue.", "INFO", "TOAST"] call ARC_fnc_clientHint;
        };

        default
        {
            ["Map click submitted.", "INFO", "TOAST"] call ARC_fnc_clientHint;
        };
    };

    ["SUBMITTED"] call ARC_fnc_mapClick_disarm;
    true
}
else
{
    ["Map click submit failed.", "ERROR", "BOTH"] call ARC_fnc_clientHint;
    ["CANCELLED"] call ARC_fnc_mapClick_disarm;
    false
};
