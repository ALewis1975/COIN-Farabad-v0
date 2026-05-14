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

// Phase 7 tuple minimum length including posX/posY at indices 7-8.
private _IDX_POS_X = 7;
private _IDX_POS_Y = 8;
private _TUPLE_MIN_POS_LEN = 9;

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
private _LABEL_LEN_SELECTED_CALLSIGN = 12;
private _LABEL_LEN_SELECTED_FID = 8;
private _LABEL_LEN_UNSELECTED_CALLSIGN = 6;
private _MARKER_SIZE_RUNWAY = [0.55, 0.55];
private _MARKER_SIZE_SELECTED = [0.52, 0.52];
private _MARKER_SIZE_DEFAULT = [0.38, 0.38];
private _shortText = {
    params ["_s", "_maxLen"];
    if (!(_s isEqualType "")) exitWith { "" };
    private _txt = _s;
    if (_txt isEqualTo "") exitWith { "" };
    if ((count _txt) > _maxLen) then {
        _txt = (_txt select [0, _maxLen]) + "...";
    };
    _txt
};
private _markerLabel = {
    params ["_fid", "_callsign", "_isSelected"];
    if (_isSelected) exitWith {
        if (_callsign isEqualType "" && { !(_callsign isEqualTo "") } && { ((toUpper _callsign) find "FLT-") != 0 }) then {
            [_callsign, _LABEL_LEN_SELECTED_CALLSIGN] call _shortText
        } else {
            [_fid, _LABEL_LEN_SELECTED_FID] call _shortText
        };
    };
    if (_callsign isEqualType "" && { !(_callsign isEqualTo "") } && { ((toUpper _callsign) find "FLT-") != 0 }) exitWith {
        [_callsign, _LABEL_LEN_UNSELECTED_CALLSIGN] call _shortText
    };
    ""
};

// --- Runway center marker ---
private _rwyMkr = format ["ARC_airmap_rwy_%1", diag_tickTime];
createMarkerLocal [_rwyMkr, _centerPos];
_rwyMkr setMarkerTypeLocal "mil_flag";
_rwyMkr setMarkerColorLocal "ColorWhite";
_rwyMkr setMarkerTextLocal "RWY";
_rwyMkr setMarkerSizeLocal _MARKER_SIZE_RUNWAY;
_newMarkers pushBack _rwyMkr;

// --- Arrival markers (blue) ---
private _arrIdx = 0;
private _centerTarget = [];
{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < _TUPLE_MIN_POS_LEN) then { _arrIdx = _arrIdx + 1; continue; };
    private _fid = _x param [0, ""];
    private _callsign = _x param [1, _fid];
    private _posX = _x param [_IDX_POS_X, 0];
    private _posY = _x param [_IDX_POS_Y, 0];
    if (!(_posX isEqualType 0)) then { _posX = 0; };
    if (!(_posY isEqualType 0)) then { _posY = 0; };

    private _isSelected = (_centerOnFid != "" && { _fid isEqualTo _centerOnFid });
    private _label = [_fid, _callsign, _isSelected] call _markerLabel;

    private _mkr = format ["ARC_airmap_arr_%1_%2", _arrIdx, diag_tickTime];
    createMarkerLocal [_mkr, [_posX, _posY]];
    _mkr setMarkerTypeLocal "mil_arrow";
    _mkr setMarkerColorLocal (if (_isSelected) then {"ColorYellow"} else {"ColorBLUFOR"});
    _mkr setMarkerTextLocal _label;
    _mkr setMarkerSizeLocal (if (_isSelected) then {_MARKER_SIZE_SELECTED} else {_MARKER_SIZE_DEFAULT});
    _newMarkers pushBack _mkr;

    if (_isSelected) then {
        _centerTarget = [_posX, _posY];
    };
    _arrIdx = _arrIdx + 1;
} forEach _arrivals;

// --- Departure markers (red) ---
private _depIdx = 0;
{
    if !(_x isEqualType []) then { continue; };
    if ((count _x) < _TUPLE_MIN_POS_LEN) then { _depIdx = _depIdx + 1; continue; };
    private _fid = _x param [0, ""];
    private _callsign = _x param [1, _fid];
    private _posX = _x param [_IDX_POS_X, 0];
    private _posY = _x param [_IDX_POS_Y, 0];
    if (!(_posX isEqualType 0)) then { _posX = 0; };
    if (!(_posY isEqualType 0)) then { _posY = 0; };

    private _isSelected = (_centerOnFid != "" && { _fid isEqualTo _centerOnFid });
    private _label = [_fid, _callsign, _isSelected] call _markerLabel;

    private _mkr = format ["ARC_airmap_dep_%1_%2", _depIdx, diag_tickTime];
    createMarkerLocal [_mkr, [_posX, _posY]];
    _mkr setMarkerTypeLocal "mil_triangle";
    _mkr setMarkerColorLocal (if (_isSelected) then {"ColorYellow"} else {"ColorOPFOR"});
    _mkr setMarkerTextLocal _label;
    _mkr setMarkerSizeLocal (if (_isSelected) then {_MARKER_SIZE_SELECTED} else {_MARKER_SIZE_DEFAULT});
    _newMarkers pushBack _mkr;

    if (_isSelected) then {
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
