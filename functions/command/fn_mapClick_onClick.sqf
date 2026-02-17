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
private _payloadShape = if (_evt isEqualType []) then {count _evt} else {-1};

if (_debug) then
{
    diag_log format ["[FARABAD][MAPCLICK][CLICK][DEBUG] payloadType=%1 payloadShape=%2 payload=%3", typeName _evt, _payloadShape, _evt];
};

private _a = nil;
private _b = nil;
private _c = nil;
private _d = nil;
if (_evt isEqualType []) then
{
    _evt params ["_a", "_b", "_c", "_d"];
};

private _pos = [];
{
    private _cand = _x;
    if (!(_cand isEqualType [])) then { continue; };

    private _n = count _cand;
    if !(_n in [2, 3]) then { continue; };

    private _nums = true;
    {
        if !(_x isEqualType 0) exitWith { _nums = false; };
    } forEach _cand;

    if (_nums) exitWith { _pos = +_cand; };
} forEach [_b, _a, _c, _d];

if (!(_pos isEqualType []) || {!(count _pos in [2, 3])}) exitWith
{
    uiNamespace setVariable ["ARC_mapClick_lastErr", "invalid_click_payload"];
    diag_log format ["[FARABAD][MAPCLICK][CLICK][ERR] invalid_click_payload payloadType=%1 payloadShape=%2 payload=%3", typeName _evt, _payloadShape, _evt];
    hint "Map click failed: invalid position.";
    ["INVALID_CLICK_PAYLOAD"] call ARC_fnc_mapClick_disarm;
    false
};

uiNamespace setVariable ["ARC_mapClick_lastPos", _pos];
diag_log format ["[FARABAD][MAPCLICK][CLICK] pos=%1", _pos];

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
            hint format ["Submitted intel (%1) at %2.", _cat, mapGridPosition _pos];
        };

        case "LEAD_REQ":
        {
            hint "Lead request submitted to TOC queue.";
        };

        default
        {
            hint "Map click submitted.";
        };
    };

    ["SUBMITTED"] call ARC_fnc_mapClick_disarm;
    true
}
else
{
    hint "Map click submit failed.";
    ["CANCELLED"] call ARC_fnc_mapClick_disarm;
    false
};
