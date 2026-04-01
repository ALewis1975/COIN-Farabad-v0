/*
    ARC_fnc_sitePopApplyAmbiance

    Server: apply LAMBS Danger or vanilla waypoint behavior to a spawned group.

    Behavior modes:
        "garrison" — LAMBS lambs_danger_fnc_garrison (units occupy and hold nearby
                     buildings). Falls back to SAFE/WHITE hold-in-place if LAMBS absent.
        "camp"     — LAMBS lambs_danger_fnc_camp (units loiter near a camp anchor).
                     Falls back to loiter waypoints if LAMBS absent.
        "wander"   — Place loiter waypoints using pre-scanned ARC_worldPatrolRings
                     (tight ring for radius < 150 m, medium for 150-279 m, wide for ≥ 280 m).
                     Falls back to randomised MOVE+CYCLE waypoints if ring data absent.

    All LAMBS calls are guarded with isNil so the system degrades gracefully if
    LAMBS Danger.fsm is not loaded in the current session.

    Params:
        0: GROUP  — the spawned group to configure
        1: STRING — behavior mode: "garrison" | "camp" | "wander"
        2: ARRAY  — site world position [x, y, z] (ATL anchor)
        3: NUMBER — spawn/behavior radius (meters)

    Returns: Nothing
*/

if (!isServer) exitWith {};

params [
    ["_grp",      grpNull, [grpNull]],
    ["_behavior", "wander", [""]],
    ["_sitePos",  [],       [[]]],
    ["_radius",   80,       [0]]
];

if (isNull _grp) exitWith {};
if ((count units _grp) isEqualTo 0) exitWith {};
if (!(_sitePos isEqualType []) || { (count _sitePos) < 2 }) exitWith {};

private _p3 = +_sitePos;
if ((count _p3) < 3) then { _p3 pushBack 0; };

private _behL = toLower _behavior;

switch (_behL) do
{
    // -------------------------------------------------------------------------
    case "garrison":
    // -------------------------------------------------------------------------
    {
        if (isNil "lambs_danger_fnc_garrison") then
        {
            diag_log "[ARC][SITEPOP][WARN] ARC_fnc_sitePopApplyAmbiance: lambs_danger_fnc_garrison not found — garrison group set to SAFE/WHITE hold.";
            _grp setBehaviour "SAFE";
            _grp setCombatMode "WHITE";
            { _x disableAI "PATH"; doStop _x; } forEach (units _grp);
        }
        else
        {
            [_grp, _p3, _radius] spawn lambs_danger_fnc_garrison;
        };
    };

    // -------------------------------------------------------------------------
    case "camp":
    // -------------------------------------------------------------------------
    {
        if (isNil "lambs_danger_fnc_camp") then
        {
            diag_log "[ARC][SITEPOP][WARN] ARC_fnc_sitePopApplyAmbiance: lambs_danger_fnc_camp not found — camp group using loiter waypoints.";
            _grp setBehaviour "SAFE";
            _grp setCombatMode "WHITE";

            private _campR = _radius * 0.5;
            for "_w" from 1 to 3 do
            {
                private _ang    = random 360;
                private _dist   = random _campR;
                private _wpPos  = [(_p3 select 0) + (sin _ang) * _dist, (_p3 select 1) + (cos _ang) * _dist, 0];
                private _wp     = _grp addWaypoint [_wpPos, 0];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                _wp setWaypointBehaviour "SAFE";
                _wp setWaypointCombatMode "WHITE";
            };
            private _cycle = _grp addWaypoint [_p3, 5];
            _cycle setWaypointType "CYCLE";
        }
        else
        {
            [_grp, _p3, _radius] spawn lambs_danger_fnc_camp;
        };
    };

    // "wander" and default
    default
    {
        // Re-declare _hg so sqflint resolves it within this switch code block.
        private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
        _grp setBehaviour "SAFE";
        _grp setCombatMode "WHITE";

        // Choose patrol ring variant by radius
        private _ringVariant = 0; // 0=tight(~80 m), 1=medium(~180 m), 2=wide(~350 m)
        if (_radius >= 150) then { _ringVariant = 1; };
        if (_radius >= 280) then { _ringVariant = 2; };

        // Look up pre-scanned ring for this site via _hg helper (avoids bare HashMap get)
        private _siteId  = _grp getVariable ["ARC_sitePop_siteId", ""];
        private _rings   = missionNamespace getVariable ["ARC_worldPatrolRings", createHashMap];
        private _ringData = [_rings, _siteId, []] call _hg;

        private _ringWps = [];
        if (_ringData isEqualType [] && { (count _ringData) > _ringVariant }) then
        {
            _ringWps = +(_ringData select _ringVariant);
        };

        if ((count _ringWps) > 0) then
        {
            {
                private _wp = _grp addWaypoint [_x, 5];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                _wp setWaypointBehaviour "SAFE";
                _wp setWaypointCombatMode "WHITE";
            } forEach _ringWps;

            private _cycle = _grp addWaypoint [_p3, 5];
            _cycle setWaypointType "CYCLE";
        }
        else
        {
            // Fallback: generate random MOVE+CYCLE waypoints
            for "_w" from 1 to 4 do
            {
                private _ang   = random 360;
                private _dist  = _radius * (0.4 + random 0.5);
                private _wpPos = [(_p3 select 0) + (sin _ang) * _dist, (_p3 select 1) + (cos _ang) * _dist, 0];
                private _wp    = _grp addWaypoint [_wpPos, 5];
                _wp setWaypointType "MOVE";
                _wp setWaypointSpeed "LIMITED";
                _wp setWaypointBehaviour "SAFE";
                _wp setWaypointCombatMode "WHITE";
            };
            private _cycle = _grp addWaypoint [_p3, 5];
            _cycle setWaypointType "CYCLE";
        };
    };
};
