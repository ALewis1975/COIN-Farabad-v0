/*
    ARC_fnc_routeClearanceIsSegmentSuppressed

    Server helper: return true when IED placement is suppressed on the
    segment nearest a given position due to a recent route clearance.

    Params:
      0: ARRAY posATL [x,y,z]

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [["_pos", [], [[]]]];
if (_pos isEqualTo [] || { (count _pos) < 2 }) exitWith {false};

private _now = serverTime;
private _suppressed = missionNamespace getVariable ["routeClear_v0_suppressedSegments", createHashMap];
if (!(_suppressed isEqualType createHashMap)) exitWith {false};
if (_suppressed isEqualTo createHashMap) exitWith {false};

private _segmentRadius = missionNamespace getVariable ["ARC_routeClearSegmentMatchRadiusM", 500];
if (!(_segmentRadius isEqualType 0)) then { _segmentRadius = 500; };
_segmentRadius = (_segmentRadius max 100) min 2000;

private _foundSeg = false;
{
    private _segId      = _x;
    private _clearUntil = _y;
    if (!(_clearUntil isEqualType 0) || { _clearUntil <= _now }) then { continue; };

    // Parse segment centroid from "SEG_<x>_<y>" key
    private _parts = _segId splitString "_";
    if ((count _parts) < 3) then { continue; };
    private _sx = parseNumber (_parts # 1);
    private _sy = parseNumber (_parts # 2);
    if ((_pos distance2D [_sx, _sy]) < _segmentRadius) then { _foundSeg = true; };
} forEach _suppressed;

_foundSeg
