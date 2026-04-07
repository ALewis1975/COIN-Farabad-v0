/*
    ARC_fnc_uiConsoleAirMapPaint

    Client: draw traffic markers on the AIR CT_MAP control (IDC 78137).
    Reads arrivals/departures from ARC_pub_airbaseUiSnapshot.
    Each tuple has posX (index 7) and posY (index 8).
    Runway marker shown at airbase center.
    Called from ARC_fnc_uiConsoleAirPaint after list build.

    Phase 7: AIR map pane integration.
*/

if (!hasInterface) exitWith {false};

params [
    ["_display", displayNull, [displayNull]],
    ["_centerOnFid", "", [""]]
];
if (isNull _display) exitWith {false};

private _ctrlMap = _display displayCtrl 78137;
if (isNull _ctrlMap) exitWith {false};

// --- Read snapshot ---
private _airSnap = missionNamespace getVariable ["ARC_pub_airbaseUiSnapshot", []];
if (!(_airSnap isEqualType [])) then { _airSnap = []; };

private _getPair = {
    params ["_pairs", "_k", "_def"];
    private _v = _def;
    {
        if (_x isEqualType [] && { (count _x) >= 2 } && { ((_x select 0)) isEqualTo _k }) exitWith {
            _v = _x select 1;
        };
    } forEach _pairs;
    _v
};
if (!(_getPair isEqualType {})) exitWith { false };

private _arrivals = [_airSnap, "arrivals", []] call _getPair;
if (!(_arrivals isEqualType [])) then { _arrivals = []; };
private _departures = [_airSnap, "departures", []] call _getPair;
if (!(_departures isEqualType [])) then { _departures = []; };
private _centerPos = [_airSnap, "airbaseCenterPos", [0,0]] call _getPair;
if (!(_centerPos isEqualType [])) then { _centerPos = [0,0]; };
if ((count _centerPos) < 2) then { _centerPos = [0,0]; };

// --- Clear previous map markers ---
private _prevMarkers = uiNamespace getVariable ["ARC_console_airMapMarkers", []];
if (!(_prevMarkers isEqualType [])) then { _prevMarkers = []; };
{
    if (_x isEqualType "") then { deleteMarkerLocal _x; };
} forEach _prevMarkers;

private _newMarkers = [];

// --- Runway center marker ---
private _rwyMkr = format ["ARC_airmap_rwy_%1", diag_tickTime];
createMarkerLocal [_rwyMkr, [_centerPos select 0, _centerPos select 1]];
_rwyMkr setMarkerTypeLocal "mil_flag";
_rwyMkr setMarkerColorLocal "ColorWhite";
_rwyMkr setMarkerTextLocal "RWY";
_rwyMkr setMarkerSizeLocal [0.7, 0.7];
_newMarkers pushBack _rwyMkr;

// --- Arrival markers (blue) ---
private _arrIdx = 0;
private _centerTarget = [];
{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 9) then { _arrIdx = _arrIdx + 1; continue; };
    private _fid = _x param [0, ""];
    private _callsign = _x param [1, _fid];
    private _phase = _x param [3, ""];
    private _posX = _x param [7, 0];
    private _posY = _x param [8, 0];
    if (!(_posX isEqualType 0)) then { _posX = 0; };
    if (!(_posY isEqualType 0)) then { _posY = 0; };

    private _mkr = format ["ARC_airmap_arr_%1_%2", _arrIdx, diag_tickTime];
    createMarkerLocal [_mkr, [_posX, _posY]];
    _mkr setMarkerTypeLocal "mil_arrow";
    _mkr setMarkerColorLocal "ColorBLUFOR";
    _mkr setMarkerTextLocal format ["%1 %2", _callsign, _phase];
    _mkr setMarkerSizeLocal [0.6, 0.6];
    _newMarkers pushBack _mkr;

    if (_centerOnFid != "" && { _fid isEqualTo _centerOnFid }) then {
        _centerTarget = [_posX, _posY];
    };
    _arrIdx = _arrIdx + 1;
} forEach _arrivals;

// --- Departure markers (red) ---
private _depIdx = 0;
{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < 9) then { _depIdx = _depIdx + 1; continue; };
    private _fid = _x param [0, ""];
    private _callsign = _x param [1, _fid];
    private _state = _x param [3, ""];
    private _posX = _x param [7, 0];
    private _posY = _x param [8, 0];
    if (!(_posX isEqualType 0)) then { _posX = 0; };
    if (!(_posY isEqualType 0)) then { _posY = 0; };

    private _mkr = format ["ARC_airmap_dep_%1_%2", _depIdx, diag_tickTime];
    createMarkerLocal [_mkr, [_posX, _posY]];
    _mkr setMarkerTypeLocal "mil_triangle";
    _mkr setMarkerColorLocal "ColorOPFOR";
    _mkr setMarkerTextLocal format ["%1 %2", _callsign, _state];
    _mkr setMarkerSizeLocal [0.6, 0.6];
    _newMarkers pushBack _mkr;

    if (_centerOnFid != "" && { _fid isEqualTo _centerOnFid }) then {
        _centerTarget = [_posX, _posY];
    };
    _depIdx = _depIdx + 1;
} forEach _departures;

uiNamespace setVariable ["ARC_console_airMapMarkers", _newMarkers];

// --- Center map ---
if ((count _centerTarget) >= 2) then {
    _ctrlMap ctrlMapAnimAdd [0.3, ctrlMapScale _ctrlMap, _centerTarget];
    ctrlMapAnimCommit _ctrlMap;
} else {
    // Default: center on airbase if no specific selection
    private _prevCenter = uiNamespace getVariable ["ARC_console_airMapInitialized", false];
    if (!(_prevCenter isEqualType true) && !(_prevCenter isEqualType false)) then { _prevCenter = false; };
    if (!_prevCenter) then {
        _ctrlMap ctrlMapAnimAdd [0, 0.06, _centerPos];
        ctrlMapAnimCommit _ctrlMap;
        uiNamespace setVariable ["ARC_console_airMapInitialized", true];
    };
};

true
