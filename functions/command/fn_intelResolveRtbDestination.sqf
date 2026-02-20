/*
    ARC_fnc_intelResolveRtbDestination

    Resolve an RTB destination (pos + label) based on the RTB purpose.

    Purposes:
      - REFIT : unit HQ marker (default ARC_m_charlie_2_325AIR)
      - INTEL : TOC S2 / Intel station (object var arc_toc_intel_1) fallback to base center
      - EPW   : EPW processing (preferred sheriff_handling unit, then processing object vars,
                then marker epw_processing). Fallback to holding markers.

    Params:
      0: STRING purpose

    Returns:
      ARRAY [posATL, label, radius]
*/

params [["_purpose", "REFIT"]];
if (!(_purpose isEqualType "")) then { _purpose = "REFIT"; };
_purpose = toUpper (trim _purpose);

private _pos = [0,0,0];
private _label = "Base";
private _radius = 40;

private _fallbackBase = {
    private _m = missionNamespace getVariable ["ARC_mkr_airbaseCenter", "mkr_airbaseCenter"];
    _m = [_m] call ARC_fnc_worldResolveMarker;
    private _p = getMarkerPos _m;
    if ((markerType _m) isEqualTo "") then { _p = [0,0,0]; };
    _p
};

switch (_purpose) do
{
    case "REFIT":
    {
        private _m = "ARC_m_charlie_2_325AIR";
        _m = [_m] call ARC_fnc_worldResolveMarker;
        if (!((markerType _m) isEqualTo "")) then
        {
            _pos = getMarkerPos _m;
            _label = markerText _m;
            if (_label isEqualTo "") then { _label = "C-2-325 AIR HQ"; };
            _radius = 45;
        }
        else
        {
            _pos = call _fallbackBase;
            _label = "Base";
            _radius = 60;
        };
    };

    case "INTEL":
    {
        // Prefer an explicit Intel Debrief station if present.
        // Supported Eden variable names (priority order):
        //   - arc_intel_bebrief (legacy / common typo)
        //   - arc_intel_debrief
        //   - ARC_toc_intel_1 (current)
        //   - ARC_toc_intel_2 (alt)
        //   - arc_toc_intel_1 (legacy)
        private _o = objNull;
        {
            _o = missionNamespace getVariable [_x, objNull];
            if (!isNull _o) exitWith {};
        } forEach [
            "arc_intel_bebrief", "ARC_intel_bebrief",
            "arc_intel_debrief", "ARC_intel_debrief",
            "ARC_toc_intel_1", "ARC_toc_intel_2",
            "arc_toc_intel_1", "arc_toc_intel_2"
        ];

        if (!isNull _o) then
        {
            _pos = getPosATL _o;
            _label = "S2 Intel Debrief";
            _radius = 30;
        }
        else
        {
            _pos = call _fallbackBase;
            _label = "Base";
            _radius = 60;
        };
    };

    case "EPW":
    {
        // Priority order:
        //   1) sheriff_handling unit (preferred interaction anchor)
        //   2) processing building object vars: EPW_Porcessing (typo), EPW_Processing (legacy)
        //   3) marker epw_processing
        // Fallback to holding markers: mkr_SHERIFF_HOLDING, epw_holding

        private _o = missionNamespace getVariable ["sheriff_handling", objNull];
        if (!isNull _o) then
        {
            _pos = getPosATL _o;
            _label = "EPW Processing";
            _radius = 12;
        }
        else
        {
            _o = objNull;
            {
                _o = missionNamespace getVariable [_x, objNull];
                if (!isNull _o) exitWith {};
            } forEach ["EPW_Porcessing", "EPW_Processing", "EPW_Processing_Building"];

            if (!isNull _o) then
            {
                _pos = getPosATL _o;
                _label = "EPW Processing";
                _radius = 20;
            }
            else
            {
                private _m = "epw_processing";
                _m = [_m] call ARC_fnc_worldResolveMarker;
                if (!((markerType _m) isEqualTo "")) then
                {
                    _pos = getMarkerPos _m;
                    _label = markerText _m;
                    if (_label isEqualTo "") then { _label = "EPW Processing"; };
                    _radius = 22;
                }
                else
                {
                    private _mHold = "";
                    {
                        private _cand = [_x] call ARC_fnc_worldResolveMarker;
                        if (!((markerType _cand) isEqualTo "")) exitWith { _mHold = _cand; };
                    } forEach ["epw_holding", "mkr_SHERIFF_HOLDING"];

                    if (_mHold isNotEqualTo "") then
                    {
                        _pos = getMarkerPos _mHold;
                        _label = markerText _mHold;
                        if (_label isEqualTo "") then { _label = "EPW Holding"; };
                        _radius = 35;
                    }
                    else
                    {
                        _pos = call _fallbackBase;
                        _label = "Base";
                        _radius = 60;
                    };
                };
            };
        };
    };

    default
    {
        _pos = call _fallbackBase;
        _label = "Base";
        _radius = 60;
    };
};

[_pos, _label, _radius]
