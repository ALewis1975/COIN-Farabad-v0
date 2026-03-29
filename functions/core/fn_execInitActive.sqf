/*
    Server: initialize the execution package for the currently active incident.

    The execution package defines:
      - the completion criteria ("end state")
      - failure conditions (timeouts, late response, objective killed)
      - optional spawned objective objects/NPCs that players interact with on-site

    This function is safe to call repeatedly; it will only rebuild the package
    when the active task changes or if required objective objects are missing.

    Returns:
        BOOL
*/

if (!isServer) exitWith {false};

private _taskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
if (_taskId isEqualTo "") exitWith {false};

private _execTaskId = ["activeExecTaskId", ""] call ARC_fnc_stateGet;
private _execKind   = ["activeExecKind", ""] call ARC_fnc_stateGet;

// Resolve stable incident position (marker or direct pos)
private _marker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
private _type   = ["activeIncidentType", ""] call ARC_fnc_stateGet;
private _disp   = ["activeIncidentDisplayName", ""] call ARC_fnc_stateGet;
private _posATL = ["activeIncidentPos", []] call ARC_fnc_stateGet;

// Lead tag is only populated when the active incident originated from a Lead.
// Some execution branches (e.g., CHECKPOINT VOI) rely on it, so guard it here.
private _leadTag = ["activeLeadTag", ""] call ARC_fnc_stateGet;
if (!(_leadTag isEqualType "")) then { _leadTag = ""; };
private _leadTagU = toUpper _leadTag;

private _pos = [];
private _m = "";

if (!(_marker isEqualTo "")) then
{
    _m = [_marker] call ARC_fnc_worldResolveMarker;
    if (_m in allMapMarkers) then
    {
        _pos = getMarkerPos _m;
    };
};

if (_pos isEqualTo [] && { _posATL isEqualType [] && { (count _posATL) >= 2 } }) then
{
    _pos = +_posATL;
    _pos resize 3;
};

if (_pos isEqualTo []) exitWith {false};

private _typeU = toUpper _type;

// RECON tasks: some are area recon, some are route recon.
// We treat any RECON display name containing "route" as a route recon task.
private _isRouteRecon = false;
if (_typeU isEqualTo "RECON") then
{
    private _d = toLower _disp;
    _isRouteRecon = ((_d find "route") >= 0);
};


// IED tasks: some are package IEDs, some are VBIED / suspicious vehicle reports.
private _isVbied = false;
if (_typeU isEqualTo "IED") then
{
    private _d2 = toLower _disp;
    _isVbied = ((_d2 find "vbied") >= 0)
        || { (_d2 find "vehicle bomb") >= 0 }
        || { (_d2 find "car bomb") >= 0 }
        || { (_d2 find "vehicle") >= 0 && { (_d2 find "suspicious") >= 0 } }
        || { (_d2 find "vehicle") >= 0 && { (_d2 find "bomb") >= 0 } };
};

// RAID tasks: some should scaffold a cache search instead of a single intel prop.
private _isCacheRaid = false;
if (_typeU isEqualTo "RAID") then
{
    private _d3 = toLower _disp;
    // Expand beyond the literal word "cache" so seizure / smuggling raids still spawn physical props.
    // Keep this conservative to avoid false positives.
    private _cacheKeys = [
        "cache",
        "stockpile",
        "stash",
        "contraband",
        "smuggl",      // smuggling
        "seiz",        // seizure / seized
        "weapons",
        "weapon",
        "ammo",
        "munitions",
        "explosives"
    ];

    { if ((_d3 find _x) >= 0) exitWith { _isCacheRaid = true; }; } forEach _cacheKeys;
};

// Feature toggles (initServer overrides)
private _vbiedEnabled = missionNamespace getVariable ["ARC_vbiedScaffoldEnabled", true];
if (!(_vbiedEnabled isEqualType true) && !(_vbiedEnabled isEqualType false)) then { _vbiedEnabled = true; };

private _cacheEnabled = missionNamespace getVariable ["ARC_cacheScaffoldEnabled", true];
if (!(_cacheEnabled isEqualType true) && !(_cacheEnabled isEqualType false)) then { _cacheEnabled = true; };


// Assignment/acceptance workflow
// Tasks may exist in a CREATED (unaccepted) state before TOC acceptance.
private _accepted = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
if (!(_accepted isEqualType true)) then { _accepted = false; };
private _startedAt = ["activeExecStartedAt", -1] call ARC_fnc_stateGet;
if (!(_startedAt isEqualType 0)) then { _startedAt = -1; };

// Zone (used for timing + plausibility tuning)
private _zone = [_pos] call ARC_fnc_worldGetZoneForPos;

// If we already have a package for this task, only ensure objective objects exist.
private _needsBuild = !(_execTaskId isEqualTo _taskId && { !(_execKind isEqualTo "") });

// If TOC just accepted the incident, force a rebuild so we can start timers and spawn assets.
if (_accepted && { _startedAt < 0 }) then
{
    _needsBuild = true;
};

// Helper: spawn objective object or NPC and attach objective action
private _spawnObjective = {
    params [
        ["_kind", ""],
        ["_class", ""],
        ["_center", [0,0,0]],
        ["_radius", 250],
        ["_actionText", ""],
        ["_failOnKilled", false]
    ];

    if (_kind isEqualTo "" || _class isEqualTo "") exitWith {[]};
// Pick a sensible position near the center.
//
// Rule: IED_DEVICE and VBIED_VEHICLE must spawn on roads (outside buildings).
// We enforce that here by using the dedicated site pickers.
// Other objective kinds may spawn indoors when appropriate.
private _p = [];
private _kindU = toUpper (trim _kind);

switch (_kindU) do
{
    case "IED_DEVICE":
    {
        _p = [_center, _radius] call ARC_fnc_iedPickSite;
    };

    case "VBIED_VEHICLE":
    {
        _p = [_center, _radius, _class] call ARC_fnc_vbiedPickSite;
    };

    default
    {
        private _wantsIndoor = (_kindU in ["RAID_INTEL","CACHE_SEARCH","CIV_MEET","CMDNODE_RAID"]);
        if (_wantsIndoor) then
        {
            // Liaison tasks should spawn *in* the named objective building (Mosque/Hotel/etc.).
            // Prefer the nearest enterable building candidate rather than a random one.
            private _preferNearest = (_kindU isEqualTo "CIV_MEET");
            _p = [_center, _radius, [], _preferNearest] call ARC_fnc_worldPickEnterablePosNear;
        }
        else
        {
            // Default: keep the objective at/near the incident center (already selected by incident logic).
            _p = +_center;
            _p resize 3;
        };
    };
};

if (_p isEqualTo []) then { _p = +_center; _p resize 3; };
    private _obj = objNull;

    if (isClass (configFile >> "CfgVehicles" >> _class)) then
    {
        // NPC
        if (_kind isEqualTo "CIV_MEET") then
        {
            private _grp = createGroup [civilian, true];
            // Prefer 3CB Takistani Civilians (liaison) pool when available.
            private _liaPool = missionNamespace getVariable ["ARC_liaisonClassPool", []];
            if (!(_liaPool isEqualType [])) then { _liaPool = []; };
            if ((count _liaPool) > 0) then { _class = selectRandom _liaPool; };

            _obj = _grp createUnit [_class, _p, [], 0, "NONE"];
            _obj setVariable ["ARC_objectiveKind", _kind, true];
            _obj disableAI "MOVE";
            _obj disableAI "AUTOTARGET";
            _obj disableAI "TARGET";
            _obj setBehaviour "CARELESS";
            _obj setCombatMode "BLUE";
            _obj setCaptive true;
            // Protect liaison until players arrive (prevents random early failures).
            _obj allowDamage (!_failOnKilled);
        }
        else
        {
            // Physical object
            _obj = createVehicle [_class, _p, [], 0, "CAN_COLLIDE"];
            // Place at the chosen ATL position; do NOT snap upward (avoids rooftop placement).
            private _pFix = +_p; _pFix resize 3;
            private _pz = _pFix select 2; if (!(_pz isEqualType 0)) then { _pz = 0; };
            if (_pz < -2) then { _pz = 0; };
            _obj setPosATL [_pFix select 0, _pFix select 1, _pz + 0.05];
            _obj setVectorUp [0,0,1];            _obj setVariable ["ARC_objectiveKind", _kind, true];
            // If this objective failing on death, keep it safe until players are on-site.
            _obj allowDamage (!_failOnKilled);


	            // IED props: by default keep the prop visible and simple (this objective is a marker object; the trigger handles detonation).
	            // If you ever need to freeze physics/interaction, enable this server toggle.
	            if (_kind isEqualTo "IED_DEVICE" && { _failOnKilled }) then
	            {
	                private _disableSim = missionNamespace getVariable ["ARC_iedObjectiveDisableSim", false];
	                if (_disableSim isEqualType true && { _disableSim }) then
	                {
	                    _obj enableSimulationGlobal false;
	                };
	            };


// VBIED vehicles: keep them inert until players arrive.
if (_kind isEqualTo "VBIED_VEHICLE") then
{
    _obj setDir (random 360);
    _obj setFuel 0;
    _obj engineOn false;
    _obj lock 0; // unlocked so it can be moved/towed
};
        };
    };

    if (isNull _obj) exitWith {[]};

    // Failure if the objective is destroyed/killed
    if (_failOnKilled) then
    {
        _obj addEventHandler ["Killed", {
            params ["_killed", "_killer", "_instigator", "_useEffects"];

            // TOC controls closure; recommend failure.
            // Special case: if this was an IED objective that detonated while no friendly element
            // was on-scene, queue a follow-on response request for TOC (prevents immediate re-tasking).
            private _pos = getPosATL _killed;
            if (!(_pos isEqualType []) || { (count _pos) < 2 }) then
            {
                _pos = ["activeExecPos", []] call ARC_fnc_stateGet;
            };
            if (!(_pos isEqualType []) || { (count _pos) < 2 }) then
            {
                _pos = [0,0,0];
            };
            _pos = +_pos;
            _pos resize 3;
            if (!((_pos select 2) isEqualType 0)) then { _pos set [2, 0]; };

            private _kind = _killed getVariable ["ARC_objectiveKind", ""];
            if (!(_kind isEqualType "")) then { _kind = ""; };

            // If this was an IED/VBIED objective, treat as a detonation signal.
            private _typeU = toUpper (["activeIncidentType", ""] call ARC_fnc_stateGet);
            private _kU = toUpper _kind;
            if (_typeU isEqualTo "IED" && { _kU in ["IED_DEVICE", "VBIED_VEHICLE"] }) exitWith
            {
                [_pos, _kU, "OBJECTIVE_KILLED"] call ARC_fnc_iedHandleDetonation;
            };

            // Generic: TOC controls closure; recommend failure.
            private _msg = format ["Objective asset '%1' was killed. Recommend closing this incident as FAILED.", _kind];
            ["FAILED", "OBJECTIVE_KILLED", _msg, _pos] call ARC_fnc_incidentMarkReadyToClose;
        }];

        // Redundant detonation detector: explosions can occur without the objective being killed.
        // We keep this handler narrow to IED/VBIED objective kinds to avoid false positives.
        if (_kind in ["IED_DEVICE", "VBIED_VEHICLE"]) then
        {
            _obj addEventHandler ["Explosion", {
                if (!isServer) exitWith {};

                private _o = _this param [0, objNull, [objNull]];
                if (isNull _o) exitWith {};

                // Heuristic gate: ignore tiny nearby explosions that do not meaningfully affect the device.
                private _evtDmg = _this param [1, 0, [0]];
                private _dmgNow = damage _o;
                if ((_evtDmg < 0.15) && { _dmgNow < 0.35 }) exitWith {};

                private _pos = getPosATL _o;
                private _ok = toUpper (_o getVariable ["ARC_objectiveKind", ""]);
                [_pos, _ok, "OBJECTIVE_EXPLOSION"] call ARC_fnc_iedHandleDetonation;
            }];
        };
    };

    // Make sure clients can interact (addAction is local)
    [_obj, _actionText, _kind] remoteExec ["ARC_fnc_clientAddObjectiveAction", 0, true];

    [_obj, _p]
};


// Helper: spawn a multi-container cache objective (no exact marker)
private _spawnCacheObjective = {
    params [
        ["_taskId", ""],
        ["_center", [0,0,0]],
        ["_radius", 420],
        ["_actionText", "Search cache container"]
    ];

    if (_taskId isEqualTo "") exitWith { [] };

    private _count = missionNamespace getVariable ["ARC_cacheContainerCount", 4];
    if (!(_count isEqualType 0) || { _count <= 0 }) then { _count = 4; };
    _count = (_count max 2) min 8;

    private _pool = missionNamespace getVariable ["ARC_cacheContainerClassPool", ["Box_NATO_Ammo_F", "Land_PlasticCase_01_small_F"]];
    if (!(_pool isEqualType [])) then { _pool = ["Box_NATO_Ammo_F", "Land_PlasticCase_01_small_F"]; };

    private _valid = _pool select { _x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) } };
    if ((count _valid) <= 0) then { _valid = ["Box_NATO_Ammo_F", "Land_PlasticCase_01_small_F"]; };

    private _base = [_center, _radius, []] call ARC_fnc_worldPickEnterablePosNear;
    if (_base isEqualTo []) then { _base = +_center; _base resize 3; };

    private _trueIdx = floor (random _count);

    private _nids = [];
    private _trueNid = "";
    private _objs = [];

    for "_i" from 0 to (_count - 1) do
    {
        private _p = [_base, 25, []] call ARC_fnc_worldPickEnterablePosNear;
        if (_p isEqualTo []) then
        {
            _p = _base getPos [6 + random 10, random 360];
            _p resize 3;
        };

        private _cls = selectRandom _valid;
        private _o = createVehicle [_cls, _p, [], 0, "CAN_COLLIDE"];
        // Place at the chosen interior ATL position (already filtered to avoid rooftops).
        private _pz = _p select 2; if (!(_pz isEqualType 0)) then { _pz = 0; };
        _o setPosATL [_p select 0, _p select 1, _pz + 0.05];
        _o setVectorUp [0,0,1];
        _o setVariable ["ARC_objectiveKind", "CACHE_SEARCH", true];
        _o setVariable ["ARC_cacheIsTrue", (_i isEqualTo _trueIdx), true];

        // Interaction (JIP-safe)
        [_o, _actionText, "CACHE_SEARCH"] remoteExec ["ARC_fnc_clientAddObjectiveAction", 0, true];

        private _nid = netId _o;
        if (!(_nid isEqualTo "")) then
        {
            _nids pushBack _nid;
            if (_i isEqualTo _trueIdx) then { _trueNid = _nid; };
        };

        _objs pushBack _o;
    };

    if ((count _nids) <= 0) exitWith { [] };

    [_base, _nids, _trueNid]
};

// (Re)build execution package when needed
if (_needsBuild) then
{
    private _createdAt = ["activeIncidentCreatedAt", serverTime] call ARC_fnc_stateGet;
    if (!(_createdAt isEqualType 0)) then { _createdAt = serverTime; };

	// Timers should start on acceptance, not on assignment.
	private _startAt = -1;
	if (_accepted) then
	{
		private _aAt = ["activeIncidentAcceptedAt", -1] call ARC_fnc_stateGet;
		if (!(_aAt isEqualType 0) || { _aAt < 0 }) then { _aAt = _createdAt; };
		_startAt = _aAt;
	};

    // Defaults
    private _kind = "HOLD";
    private _radius = 120;
    private _holdReq = 0;
    private _arrivalReq = 0;
    private _deadlineSec = 1800;

    private _objKind = "";
    private _objClass = "";
    private _objRadius = 300;
    private _objAction = "";
    private _failOnKilled = false;

    switch (_typeU) do
    {
        case "CHECKPOINT":
        {
            _kind = "HOLD";
            _radius = 90;
            _holdReq = 10 * 60;
            _deadlineSec = 15 * 60;
        };

        case "PATROL":
        {
            _kind = "HOLD";
            _radius = 150;
            _holdReq = 5 * 60;
            _deadlineSec = 30 * 60;
        };

        case "RECON":
        {
            if (_isRouteRecon) then
            {
                // Route recon: start/end point guidance + movement completion (no hold timer).
                _kind = "ROUTE_RECON";
                _radius = 180;
                _holdReq = 0;
                _deadlineSec = 30 * 60;
            }
            else
            {
                _kind = "HOLD";
                _radius = missionNamespace getVariable ["ARC_reconObservationRadiusM", 500];
                if (!(_radius isEqualType 0) || { _radius <= 0 }) then { _radius = 500; };
                _radius = (_radius max 150) min 1200;
                _holdReq = 4 * 60;
                _deadlineSec = 30 * 60;
            };
        };

        case "DEFEND":
        {
            _kind = "HOLD";
            _radius = 110;
            _holdReq = 10 * 60;
            _deadlineSec = 20 * 60;
        };

        case "QRF":
        {
            _kind = "ARRIVE_HOLD";
            _radius = 140;
            _arrivalReq = 5 * 60;
            _holdReq = 3 * 60;
            _deadlineSec = 15 * 60;
        };

	case "CMDNODE_INTERCEPT":
	{
		// Time-sensitive intercept: get to the site quickly and hold.
		_kind = "ARRIVE_HOLD";
		_radius = 160;
		_arrivalReq = 4 * 60;
		_holdReq = 3 * 60;
		_deadlineSec = 12 * 60;
	};

        case "LOGISTICS":
        {
            // Convoy mission: convoy must reach destination AO.
            _kind = "CONVOY";
            _radius = 150;
            _deadlineSec = 30 * 60;
        };

        case "ESCORT":
        {
            // Convoy mission: escort a friendly convoy to the destination AO.
            _kind = "CONVOY";
            _radius = 150;
            _deadlineSec = 30 * 60;
        };


case "RAID":
{
    _kind = "INTERACT";
    _radius = 120;
    _deadlineSec = 25 * 60;

    // Cache raids: multiple possible containers (objects-first scaffold)
    if (_isCacheRaid && { _cacheEnabled }) then
    {
        _objKind = "CACHE_SEARCH";
        _objClass = ""; // not used
        _objRadius = 380;
        _objAction = "Search cache container";
        _failOnKilled = false;
    }
	    else
	    {
	        _objKind = "RAID_INTEL";
	        // Intel props: prefer the mission-level pool (gives variety when mods add props), fall back to safe vanilla.
	        private _pool = missionNamespace getVariable ["ARC_intelPropClassPool", ["Land_File1_F", "Land_File2_F", "Land_Laptop_F", "Land_Map_F"]];
	        if (!(_pool isEqualType [])) then { _pool = []; };
	        private _valid = _pool select { _x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) } };
	        if ((count _valid) <= 0) then { _valid = ["Land_File1_F"] select { isClass (configFile >> "CfgVehicles" >> _x) }; };
	        if ((count _valid) <= 0) then { _valid = ["Land_File1_F"]; };
	        _objClass = selectRandom _valid;
	        _objRadius = missionNamespace getVariable ["ARC_intelPropSpawnRadiusM", 10];
	        if (!(_objRadius isEqualType 0)) then { _objRadius = 10; };
	        _objAction = "Exploit / collect intel";
	    };
};

	case "CMDNODE_RAID":
	{
		_kind = "INTERACT";
		_radius = 140;
		_deadlineSec = 30 * 60;

			_objKind = "RAID_INTEL";
			private _pool = missionNamespace getVariable ["ARC_intelPropClassPool", ["Land_File1_F", "Land_File2_F", "Land_Laptop_F", "Land_Map_F"]];
			if (!(_pool isEqualType [])) then { _pool = []; };
			private _valid = _pool select { _x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) } };
			if ((count _valid) <= 0) then { _valid = ["Land_File1_F"] select { isClass (configFile >> "CfgVehicles" >> _x) }; };
			if ((count _valid) <= 0) then { _valid = ["Land_File1_F"]; };
			_objClass = selectRandom _valid;
		_objRadius = missionNamespace getVariable ["ARC_intelPropSpawnRadiusM", 10];
		if (!(_objRadius isEqualType 0)) then { _objRadius = 10; };
		_objAction = "Exploit command node";
	};


case "IED":
{
    _kind = "INTERACT";
    _radius = 120;
    _deadlineSec = 20 * 60;

    // VBIED variants: swap prop objective to a vehicle placeholder
    if (_isVbied && { _vbiedEnabled }) then
    {
        _objKind = "VBIED_VEHICLE";

        private _pool = missionNamespace getVariable ["ARC_vbiedVehicleClassPool", []];
        if (!(_pool isEqualType [])) then { _pool = []; };

        private _valid = _pool select { _x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) } };
        if ((count _valid) <= 0) then { _valid = ["C_Offroad_01_F"]; };

        _objClass = selectRandom _valid;

	        // Phase 3 (VBIED v1): pick a vehicle-safe parked site near the incident center.
	        private _srV = 300;
	        private _pickedV = [_pos, _srV, _objClass] call ARC_fnc_vbiedPickSite;
	        if (_pickedV isEqualType [] && { (count _pickedV) >= 2 }) then
	        {
	            _pos = +_pickedV; _pos resize 3;
	        };

        _objRadius = 300;
        _objAction = "Inspect / render safe";
        _failOnKilled = true;
    }
    else
    {
        _objKind = "IED_DEVICE";

        // Phase 1: pick a roadside device site near the incident center.
        private _siteSel = missionNamespace getVariable ["ARC_iedPhase1_siteSelectionEnabled", true];
        if (!(_siteSel isEqualType true) && !(_siteSel isEqualType false)) then { _siteSel = true; };
        if (_siteSel) then
        {
            private _sr = missionNamespace getVariable ["ARC_iedSiteSearchRadiusM", 350];
            if (!(_sr isEqualType 0) || { _sr <= 0 }) then { _sr = 350; };
            private _picked = [_pos, _sr] call ARC_fnc_iedPickSite;
            if (_picked isEqualType [] && { (count _picked) >= 2 }) then
            {
                _pos = +_picked; _pos resize 3;
            };
        };

	        // IED Phase 1: spawn a *visible* prop objective.
	        // NOTE: Arma "IED*" classes (IEDUrbanSmall_F, etc.) are mine/explosive entities and often have no visible model.
	        // The actual detonation logic is handled by our trigger + ARC_fnc_iedServerDetonate.
	        private _pool = missionNamespace getVariable ["ARC_iedObjectClassPool", []];
	        if (!(_pool isEqualType [])) then { _pool = []; };

	        private _valid = _pool select { _x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) } };
	        if ((count _valid) <= 0) then
	        {
	            // Visible vanilla fallbacks.
	            _valid = [
	                "Land_Suitcase_F",
	                "Land_PlasticCase_01_small_F",
	                "Land_MetalCase_01_small_F",
	                "Land_File1_F",
	                "Land_File2_F",
	                "Land_Laptop_F",
	                "Land_Map_F",
	                "Land_GarbageBags_F",
	                "Land_CanisterFuel_F"
	            ];
	            _valid = _valid select { isClass (configFile >> "CfgVehicles" >> _x) };
	        };
	        if ((count _valid) <= 0) then { _valid = ["Land_Suitcase_F"]; };

	        _objClass = selectRandom _valid;
        _objRadius = 250;
        _objAction = "Clear / render safe";
        _failOnKilled = true;
    };
};

        case "CIVIL":
        {
            _kind = "INTERACT";
            _radius = 120;
            _deadlineSec = 25 * 60;

            _objKind = "CIV_MEET";
            _objClass = "C_man_1";
            _objRadius = 250;
            _objAction = "Conduct meeting";
            _failOnKilled = true;
        };

	case "CMDNODE_MEET":
	{
		_kind = "INTERACT";
		_radius = 140;
		_deadlineSec = 30 * 60;

		_objKind = "CIV_MEET";
		_objClass = "C_man_1";
		_objRadius = 350;
		_objAction = "Debrief source";
		_failOnKilled = true;
	};

        default
        {
            // Fallback: short presence check
            _kind = "HOLD";
            _radius = 140;
            _holdReq = 4 * 60;
            _deadlineSec = 25 * 60;
        };
    };

    // CHECKPOINT leads can represent a "Vehicle of Interest" stop. In that case, scaffold a vehicle
    // object to inspect inside the lead search area (object-first; no hostile AI).
    if (_typeU isEqualTo "CHECKPOINT") then
    {
        private _ld = toLower _disp;
        private _isVoi = (_leadTagU isEqualTo "SUS_VEHICLE")
            || { (_ld find "vehicle of interest") >= 0 }
            || { (_ld find "voi") >= 0 };

        if (_isVoi) then
        {
            // Reuse the VBIED vehicle scaffold (inspect action + success flow), but with a VOI-oriented pool.
            _objKind = "VBIED_VEHICLE";

	            private _pool = missionNamespace getVariable ["ARC_voiVehicleClassPool", []];
	            if (!(_pool isEqualType [])) then { _pool = []; };
	            // If no dedicated VOI pool is provided, reuse the VBIED suspicious vehicle pool.
	            if ((count _pool) <= 0) then
	            {
	                _pool = missionNamespace getVariable ["ARC_vbiedVehicleClassPool", []];
	                if (!(_pool isEqualType [])) then { _pool = []; };
	            };

            private _valid = _pool select { _x isEqualType "" && { isClass (configFile >> "CfgVehicles" >> _x) } };
            if ((count _valid) <= 0) then
            {
                // Plausible default civilian traffic.
                _valid = ["C_Offroad_01_F", "C_SUV_01_F", "C_Hatchback_01_F"]; 
            };

            _objClass = selectRandom _valid;
            _objRadius = 300;
            _objAction = "Inspect / clear vehicle of interest";
            _failOnKilled = false;
        };
    };

    // --- SITREP proximity tuning (client-side gating) ----------------------
    // Client checks ARC_sitrepProximityM when deciding whether SITREP actions
    // should be shown (distance to incident pos + optional anchor list).
    //
    // Defaults below are conservative and are meant to be tuned per map.
    private _sitrepProx = missionNamespace getVariable ["ARC_sitrepProximityM_default", 350];
    if (!(_sitrepProx isEqualType 0)) then { _sitrepProx = 350; };

    switch (_typeU) do
    {
        case "RECON":              { _sitrepProx = 650; };
        case "PATROL":             { _sitrepProx = 500; };
        case "CHECKPOINT":         { _sitrepProx = 300; };
        case "DEFEND":             { _sitrepProx = 250; };
        case "QRF":                { _sitrepProx = 300; };
        case "LOGISTICS":          { _sitrepProx = 500; };
        case "ESCORT":             { _sitrepProx = 550; };
        case "RAID":               { _sitrepProx = 200; };
        case "IED":                { _sitrepProx = 175; };
        case "CIVIL":              { _sitrepProx = 225; };
        case "CMDNODE_RAID":       { _sitrepProx = 200; };
        case "CMDNODE_MEET":       { _sitrepProx = 225; };
        case "CMDNODE_INTERCEPT":  { _sitrepProx = 300; };
        default {};
    };

    // Mission-level override per incident type, e.g. ARC_sitrepProximityM_RECON = 800
    private _overrideKey = format ["ARC_sitrepProximityM_%1", _typeU];
    private _ov = missionNamespace getVariable [_overrideKey, -1];
    if (_ov isEqualType 0 && { _ov > 0 }) then { _sitrepProx = _ov; };

    _sitrepProx = (_sitrepProx max 75) min 2000;
    ["activeSitrepProximityM", _sitrepProx] call ARC_fnc_stateSet;
    missionNamespace setVariable ["ARC_sitrepProximityM", _sitrepProx, true];

    // --- Optional per-type tuning overrides --------------------------------
    // These let mission makers tune timings/radii without editing this file.
    // Values are in meters (radius) and seconds (hold/deadline).
    // Examples:
    //   ARC_execRadiusM_PATROL = 200;
    //   ARC_execHoldReqSec_PATROL = 900;
    //   ARC_objRadiusM_RAID = 200;
    //   ARC_execDeadlineSec_RECON = 3600;

    private _ovR = missionNamespace getVariable [format ["ARC_execRadiusM_%1", _typeU], -1];
    if (_ovR isEqualType 0 && { _ovR > 0 }) then { _radius = _ovR; };

    private _ovH = missionNamespace getVariable [format ["ARC_execHoldReqSec_%1", _typeU], -1];
    if (_ovH isEqualType 0 && { _ovH >= 0 }) then { _holdReq = _ovH; };

    private _ovD = missionNamespace getVariable [format ["ARC_execDeadlineSec_%1", _typeU], -1];
    if (_ovD isEqualType 0 && { _ovD > 0 }) then { _deadlineSec = _ovD; };

    private _ovObjR = missionNamespace getVariable [format ["ARC_objRadiusM_%1", _typeU], -1];
    if (_ovObjR isEqualType 0 && { _ovObjR > 0 }) then { _objRadius = _ovObjR; };

    // --- Dynamic timing (travel + execution window) -------------------------
    // The idea:
    //   - Catalog incidents assume players stage from JBF (Airbase)
    //   - Lead-driven incidents assume players are already near the last AO
    //     (so we key travel time off the last closed incident position)
    //
    // This keeps tasks fair across the map without making close-in incidents
    // absurdly generous.

    // Determine staging position
    private _basePos = missionNamespace getVariable ["ARC_basePos", []];
    if (!(_basePos isEqualType []) || { (count _basePos) < 2 }) then { _basePos = []; };

    if (_basePos isEqualTo []) then
    {
        // Prefer an explicit respawn marker if one exists.
        if ("respawn_west" in allMapMarkers) then
        {
            _basePos = getMarkerPos "respawn_west";
        }
        else
        {
            // Fall back to our world zone center.
            if ("ARC_zone_Airbase" in allMapMarkers) then
            {
                _basePos = getMarkerPos "ARC_zone_Airbase";
            }
            else
            {
                // Last resort: the Farabad zone center from data\farabad_world_zones.sqf
                _basePos = [6117.955, 2280.710, 0];
            };
        };

        _basePos resize 3;
        missionNamespace setVariable ["ARC_basePos", _basePos];
    };

    private _stagingPos = +_basePos;
    private _stagingLabel = "JBF";

    private _leadId = ["activeLeadId", ""] call ARC_fnc_stateGet;
    if (!(_leadId isEqualTo "")) then
    {
        private _hist = ["incidentHistory", []] call ARC_fnc_stateGet;
        if (_hist isEqualType [] && { (count _hist) > 0 }) then
        {
            private _last = _hist select ((count _hist) - 1);
            // Expected format includes position at index 7.
            if (_last isEqualType [] && { (count _last) >= 8 }) then
            {
                private _lastPos = _last select 7;
                if (_lastPos isEqualType [] && { (count _lastPos) >= 2 }) then
                {
                    _stagingPos = +_lastPos;
                    _stagingPos resize 3;
                    _stagingLabel = "Last AO";
                };
            };
        };
    };

    // Convoys (LOGISTICS/ESCORT) always stage from the airbase, even when lead-driven.
    // Using "Last AO" as a convoy origin can create unrealistic timing and routing.
    if (_typeU in ["LOGISTICS", "ESCORT"]) then
    {
        _stagingPos = +_basePos;
        _stagingPos resize 3;
        _stagingLabel = "JBF Convoy Staging";
    };

    // Speed model (kph). Convoys are slower by design.
    private _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_default", 45];

    switch (_typeU) do
    {
        case "QRF":       { _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_qrf", 65]; };
	case "CMDNODE_INTERCEPT": { _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_qrf", 65]; };
        case "DEFEND":    { _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_defend", 55]; };
        case "PATROL":    { _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_patrol", 45]; };
        case "RECON":     { _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_recon", 45]; };
        case "CHECKPOINT":{ _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_checkpoint", 40]; };
        case "RAID":      { _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_raid", 45]; };
	case "CMDNODE_RAID": { _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_raid", 45]; };
        case "IED":       { _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_ied", 45]; };
        case "CIVIL":     { _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_civil", 40]; };
	case "CMDNODE_MEET": { _speedKph = missionNamespace getVariable ["ARC_timing_speedKph_civil", 40]; };
        case "LOGISTICS": { _speedKph = missionNamespace getVariable ["ARC_convoySpeedKph_logistics", missionNamespace getVariable ["ARC_convoySpeedKph", 25]]; };
        case "ESCORT":    { _speedKph = missionNamespace getVariable ["ARC_convoySpeedKph_escort", missionNamespace getVariable ["ARC_convoySpeedKph", 25]]; };
        default {};
    };

    // Secure zones have deliberate speed constraints (gates, traffic control, density).
    if (_zone in ["Airbase", "GreenZone"]) then
    {
        _speedKph = _speedKph min (missionNamespace getVariable ["ARC_timing_speedKph_secure", 30]);
    };

    // Convoys have an independent hard speed cap (AI driving stability).
    if (_typeU in ["LOGISTICS", "ESCORT"]) then
    {
        private _kMax = missionNamespace getVariable ["ARC_convoySpeedKphMax", 45];
        if (!(_kMax isEqualType 0)) then { _kMax = 45; };
        _kMax = (_kMax max 10) min 120;
        _speedKph = _speedKph min _kMax;
    };

    _speedKph = (_speedKph max 10) min 120;

    private _distM = _stagingPos distance2D _pos;
    private _travelSec = (_distM * 3.6) / _speedKph;

    // Prep time budget (seconds)
    private _prepSec = missionNamespace getVariable ["ARC_timing_prep_default", 180];
    switch (_typeU) do
    {
        case "QRF":        { _prepSec = missionNamespace getVariable ["ARC_timing_prep_qrf", 75]; };
	case "CMDNODE_INTERCEPT": { _prepSec = missionNamespace getVariable ["ARC_timing_prep_qrf", 90]; };
        case "DEFEND":     { _prepSec = missionNamespace getVariable ["ARC_timing_prep_defend", 150]; };
        case "CHECKPOINT": { _prepSec = missionNamespace getVariable ["ARC_timing_prep_checkpoint", 240]; };
        case "PATROL":     { _prepSec = missionNamespace getVariable ["ARC_timing_prep_patrol", 210]; };
        case "RECON":      { _prepSec = missionNamespace getVariable ["ARC_timing_prep_recon", 210]; };
        case "RAID":       { _prepSec = missionNamespace getVariable ["ARC_timing_prep_raid", 240]; };
	case "CMDNODE_RAID": { _prepSec = missionNamespace getVariable ["ARC_timing_prep_raid", 240]; };
        case "IED":        { _prepSec = missionNamespace getVariable ["ARC_timing_prep_ied", 210]; };
        case "CIVIL":      { _prepSec = missionNamespace getVariable ["ARC_timing_prep_civil", 240]; };
	case "CMDNODE_MEET": { _prepSec = missionNamespace getVariable ["ARC_timing_prep_civil", 240]; };
        case "LOGISTICS":  { _prepSec = missionNamespace getVariable ["ARC_timing_prep_logistics", 300]; };
        case "ESCORT":     { _prepSec = missionNamespace getVariable ["ARC_timing_prep_escort", 300]; };
        default {};
    };

    _prepSec = (_prepSec max 30) min 900;

    // Execution budget beyond travel (seconds).
    // HOLD/ARRIVE_HOLD already have hold requirements; INTERACT tasks need a search/interaction window.
    private _execBudgetSec = 0;
    if (_kind in ["HOLD", "ARRIVE_HOLD"]) then
    {
        _execBudgetSec = _holdReq;
    }
    else
    {
        _execBudgetSec = switch (_typeU) do
        {
            case "RAID":      { 15 * 60 };
			case "CMDNODE_RAID": { 18 * 60 };
            case "IED":       { 12 * 60 };
            case "CIVIL":     { 10 * 60 };
			case "CMDNODE_MEET": { 12 * 60 };
            case "LOGISTICS": { 12 * 60 };
            case "ESCORT":    { 12 * 60 };
            default             { 10 * 60 };
        };
    };

    // Slack scales a bit with mission length but is bounded.
    private _slackSec = 180 + (0.12 * (_travelSec + _execBudgetSec));
    _slackSec = (_slackSec max 180) min 900;

    private _dynDeadlineSec = _prepSec + _travelSec + _execBudgetSec + _slackSec;

    // Clamp per type so tasks stay playable.
    private _minDeadlineSec = switch (_typeU) do
    {
        case "QRF":        { 15 * 60 };
		case "CMDNODE_INTERCEPT": { 15 * 60 };
        case "CHECKPOINT": { 20 * 60 };
        case "DEFEND":     { 20 * 60 };
        case "PATROL":     { 25 * 60 };
        case "RECON":      { 25 * 60 };
        case "RAID":       { 25 * 60 };
		case "CMDNODE_RAID": { 25 * 60 };
        case "IED":        { 20 * 60 };
        case "CIVIL":      { 25 * 60 };
		case "CMDNODE_MEET": { 25 * 60 };
        case "LOGISTICS":  { 30 * 60 };
        case "ESCORT":     { 30 * 60 };
        default              { 20 * 60 };
    };

    private _maxDeadlineSec = switch (_typeU) do
    {
        case "QRF":        { 45 * 60 };
		case "CMDNODE_INTERCEPT": { 45 * 60 };
        case "CHECKPOINT": { 60 * 60 };
        case "DEFEND":     { 60 * 60 };
        case "PATROL":     { 60 * 60 };
        case "RECON":      { 60 * 60 };
        case "RAID":       { 60 * 60 };
		case "CMDNODE_RAID": { 60 * 60 };
        case "IED":        { 50 * 60 };
        case "CIVIL":      { 60 * 60 };
		case "CMDNODE_MEET": { 60 * 60 };
        case "LOGISTICS":  { 75 * 60 };
        case "ESCORT":     { 75 * 60 };
        default              { 60 * 60 };
    };

    _deadlineSec = ((_dynDeadlineSec max _minDeadlineSec) min _maxDeadlineSec);

    // Arrival requirement (ARRIVE_HOLD only): scale with travel.
    if (_kind isEqualTo "ARRIVE_HOLD") then
    {
        private _arrSlack = missionNamespace getVariable ["ARC_timing_arrivalSlack", 120];
        private _arr = _prepSec + _travelSec + _arrSlack;
        private _arrMax = (_deadlineSec - (_holdReq max 0) - 60) max 300;
        _arrivalReq = (_arr max 300) min _arrMax;
    };

    // Persist travel model for UI/task text.
    ["activeExecStagingLabel", _stagingLabel] call ARC_fnc_stateSet;
    ["activeExecStagingPos", _stagingPos] call ARC_fnc_stateSet;
    ["activeExecZone", _zone] call ARC_fnc_stateSet;
    ["activeExecTravelDistM", _distM] call ARC_fnc_stateSet;
    ["activeExecTravelSec", _travelSec] call ARC_fnc_stateSet;
    ["activeExecPrepSec", _prepSec] call ARC_fnc_stateSet;
    ["activeExecSpeedKph", _speedKph] call ARC_fnc_stateSet;
    ["activeExecSlackSec", _slackSec] call ARC_fnc_stateSet;

    // Persist execution package
    ["activeExecTaskId", _taskId] call ARC_fnc_stateSet;
    ["activeExecKind", _kind] call ARC_fnc_stateSet;
    ["activeExecPos", _pos] call ARC_fnc_stateSet;
    ["activeExecRadius", _radius] call ARC_fnc_stateSet;
	["activeExecStartedAt", _startAt] call ARC_fnc_stateSet;
	["activeExecDeadlineAt", if (_startAt < 0) then { -1 } else { _startAt + _deadlineSec }] call ARC_fnc_stateSet;
    ["activeExecArrivalReq", _arrivalReq] call ARC_fnc_stateSet;
    ["activeExecArrived", false] call ARC_fnc_stateSet;
    ["activeExecHoldReq", _holdReq] call ARC_fnc_stateSet;
    ["activeExecHoldAccum", 0] call ARC_fnc_stateSet;
    ["activeExecLastProg", -1] call ARC_fnc_stateSet;
    ["activeExecLastProgressAt", -1] call ARC_fnc_stateSet;

    // Activation: treated like a server-side trigger.
    // Timers/progress begin when friendly players first enter the AO radius.
    ["activeExecActivated", false] call ARC_fnc_stateSet;
    ["activeExecActivatedAt", -1] call ARC_fnc_stateSet;

    // Clear objective fields before we potentially spawn
    ["activeObjectiveKind", ""] call ARC_fnc_stateSet;
    ["activeObjectiveClass", ""] call ARC_fnc_stateSet;
    ["activeObjectivePos", []] call ARC_fnc_stateSet;
    ["activeObjectiveNetId", ""] call ARC_fnc_stateSet;
    ["activeObjectiveArmed", true] call ARC_fnc_stateSet;

    // Cache objective bookkeeping (multi-container)
    ["activeCacheContainerNetIds", []] call ARC_fnc_stateSet;
    ["activeCacheTrueNetId", ""] call ARC_fnc_stateSet;

    // Clear convoy fields before we potentially spawn
    ["activeConvoyNetIds", []] call ARC_fnc_stateSet;
    ["activeConvoyStartPos", []] call ARC_fnc_stateSet;
    ["activeConvoySpawnPos", []] call ARC_fnc_stateSet;
    ["activeConvoyStartMarker", ""] call ARC_fnc_stateSet;
    ["activeConvoyLinkupMarker", ""] call ARC_fnc_stateSet;
    ["activeConvoyLinkupPos", []] call ARC_fnc_stateSet;
    ["activeConvoyLinkupReached", false] call ARC_fnc_stateSet;
    ["activeConvoyLinkupTaskId", ""] call ARC_fnc_stateSet;
    ["activeConvoyLinkupTaskDone", false] call ARC_fnc_stateSet;
    ["activeConvoyDestWpPos", []] call ARC_fnc_stateSet;
    ["activeConvoySpeedKph", -1] call ARC_fnc_stateSet;
    ["activeConvoyStartedAt", -1] call ARC_fnc_stateSet;
    ["activeConvoyArrivedAt", -1] call ARC_fnc_stateSet;
    ["activeConvoyLastProg", -1] call ARC_fnc_stateSet;
    ["activeConvoyDetectedAt", -1] call ARC_fnc_stateSet;
    ["activeConvoyDepartAt", -1] call ARC_fnc_stateSet;
    ["activeConvoyLastMoveAt", -1] call ARC_fnc_stateSet;
    ["activeConvoyLastMovePos", []] call ARC_fnc_stateSet;
    ["activeConvoyLastRecoveryAt", -1] call ARC_fnc_stateSet;
    ["activeConvoyBypassUntil", -1] call ARC_fnc_stateSet;
    ["activeConvoyIngressPos", []] call ARC_fnc_stateSet;
    ["activeConvoyRolePlan", []] call ARC_fnc_stateSet;

    // Clear route recon fields (RECON route variant)
    ["activeReconRouteEnabled", false] call ARC_fnc_stateSet;
    ["activeReconRouteStartPos", []] call ARC_fnc_stateSet;
    ["activeReconRouteEndPos", []] call ARC_fnc_stateSet;
    ["activeReconRouteStartTaskId", ""] call ARC_fnc_stateSet;
    ["activeReconRouteEndTaskId", ""] call ARC_fnc_stateSet;
    ["activeReconRouteStartReached", false] call ARC_fnc_stateSet;
    ["activeReconRouteEndReached", false] call ARC_fnc_stateSet;
    ["activeReconRouteStartRadius", 60] call ARC_fnc_stateSet;
    ["activeReconRouteEndRadius", 60] call ARC_fnc_stateSet;

	// Defer spawning any physical assets until TOC acceptance.
	if (!_accepted) exitWith
	{
		[] call ARC_fnc_taskUpdateActiveDescription;
		[] call ARC_fnc_publicBroadcastState;
		true
	};
    // Route recon: compute start/end points and create child tasks on acceptance.
    if (_kind isEqualTo "ROUTE_RECON") then
    {
        private _startOff = missionNamespace getVariable ["ARC_routeReconStartOffsetM", 450];
        if (!(_startOff isEqualType 0)) then { _startOff = 450; };
        _startOff = (_startOff max 150) min 2500;

        private _endOff = missionNamespace getVariable ["ARC_routeReconEndOffsetM", 650];
        if (!(_endOff isEqualType 0)) then { _endOff = 650; };
        _endOff = (_endOff max 200) min 3500;

	        // Clamp the segment distance between the start/end points.
	        // Defaults: 1 km to 4 km (tune via initServer overrides).
	        private _minLen = missionNamespace getVariable ["ARC_routeReconMinLengthM", 1000];
	        if (!(_minLen isEqualType 0)) then { _minLen = 1000; };
	        _minLen = (_minLen max 250) min 8000;

	        private _maxLen = missionNamespace getVariable ["ARC_routeReconMaxLengthM", 4000];
	        if (!(_maxLen isEqualType 0)) then { _maxLen = 4000; };
	        _maxLen = (_maxLen max _minLen) min 12000;

	        // Normalize offsets so the snapped start/end stay within the min/max segment length.
	        // Preserve the user's relative intent (start vs end bias) while bounding the total.
	        private _sumOff = _startOff + _endOff;
	        if (!(_sumOff isEqualType 0) || { _sumOff <= 1 }) then { _sumOff = _minLen; };

	        private _ratio = _startOff / _sumOff;
	        _ratio = (_ratio max 0.2) min 0.8;

	        private _desiredLen = (_sumOff max _minLen) min _maxLen;
	        _startOff = _desiredLen * _ratio;
	        _endOff = _desiredLen - _startOff;
	        _startOff = (_startOff max 200) min (_desiredLen - 200);
	        _endOff = (_desiredLen - _startOff) max 200;

        // Road snapping: keep start/end points on (or very near) roads.
        // Use a soft radius first, then expand to a hard cap if needed.
        private _roadSnap = missionNamespace getVariable ["ARC_routeReconRoadSnapM", 140];
        if (!(_roadSnap isEqualType 0)) then { _roadSnap = 140; };
        _roadSnap = (_roadSnap max 0) min 1500;

        private _roadSnapHard = missionNamespace getVariable ["ARC_routeReconRoadSnapHardM", 900];
        if (!(_roadSnapHard isEqualType 0)) then { _roadSnapHard = 900; };
        _roadSnapHard = (_roadSnapHard max _roadSnap) min 2500;

        private _startRad = missionNamespace getVariable ["ARC_routeReconStartRadiusM", 75];
        if (!(_startRad isEqualType 0)) then { _startRad = 75; };
        _startRad = (_startRad max 25) min 200;

        private _endRad = missionNamespace getVariable ["ARC_routeReconEndRadiusM", 75];
        if (!(_endRad isEqualType 0)) then { _endRad = 75; };
        _endRad = (_endRad max 25) min 200;

        // Prefer the base gate as an orienting reference, fall back to airbase center.
        private _basePos = [];
        if ("North_Gate" in allMapMarkers) then { _basePos = getMarkerPos "North_Gate"; };
        if (!(_basePos isEqualType []) || { (count _basePos) < 2 }) then { _basePos = []; };
        if ((count _basePos) isEqualTo 0 && { "mkr_airbaseCenter" in allMapMarkers }) then { _basePos = getMarkerPos "mkr_airbaseCenter"; };
        if (!(_basePos isEqualType []) || { (count _basePos) < 2 }) then { _basePos = _pos; };
        _basePos = +_basePos; _basePos resize 3;

        private _dirLine = _basePos getDir _pos;

        private _startCand = _pos getPos [_startOff, (_dirLine + 180) % 360];
        _startCand resize 3;

        private _endCand = _pos getPos [_endOff, _dirLine];
        _endCand resize 3;

        // Keep route endpoints inside the terrain boundary.
        // Markers near the world edge can produce start/end candidates outside worldSize.
        private _wsRR = worldSize;
        private _mRR = missionNamespace getVariable ["ARC_routeReconWorldEdgeMarginM", 150];
        if (!(_mRR isEqualType 0) || { _mRR < 0 }) then { _mRR = 150; };
        _mRR = (_mRR max 0) min 1000;

        private _fn_clampWorld = {
            params ["_p", "_ws", "_m"];
            private _out = +_p; _out resize 3;
            if (!(_ws isEqualType 0) || { _ws <= 0 }) exitWith { _out };

            private _x = (_out select 0);
            private _y = (_out select 1);
            _x = (_x max _m) min (_ws - _m);
            _y = (_y max _m) min (_ws - _m);

            _out set [0, _x];
            _out set [1, _y];
            _out
        };

        _startCand = [_startCand, _wsRR, _mRR] call _fn_clampWorld;
        _endCand = [_endCand, _wsRR, _mRR] call _fn_clampWorld;

	        private _fn_snapToNearestRoad = {
	            params ["_p", "_snapR", "_snapHard"];

	            private _out = +_p;
	            _out resize 3;

	            // No snapping requested.
	            if (!(_snapR isEqualType 0) || { _snapR <= 0 }) exitWith { _out };

	            private _hard = _snapHard;
	            if (!(_hard isEqualType 0) || { _hard <= 0 }) then { _hard = _snapR; };
	            _hard = ((_hard max _snapR) max 25);

	            // Try the soft radius first, then expand until we find a road or hit the hard cap.
	            private _r = _snapR max 25;
	            private _roads = [];
	            while { (count _roads) == 0 && { _r <= _hard } } do
	            {
	                _roads = _out nearRoads _r;
	                if ((count _roads) == 0) then
	                {
	                    _r = _r * 1.6;
	                };
	            };

	            // Absolute fallback: BIS_fnc_nearestRoad (bounded by radius).
	            if ((count _roads) == 0) then
	            {
	                private _nr = [_out, (_hard * 1.25)] call BIS_fnc_nearestRoad;
	                if (!isNull _nr) then { _roads = [_nr]; };
	            };

	            if ((count _roads) == 0) exitWith { _out };

	            private _best = objNull;
	            private _bestD = 1e12;
	            {
	                if (isNull _x) then { continue; };
	                private _d = _out distance2D _x;
	                if (_d < _bestD) then { _bestD = _d; _best = _x; };
	            } forEach _roads;

	            if (!isNull _best) then
	            {
	                _out = getPosATL _best;
	                _out resize 3;
	            };

	            _out
	        };

        private _startPos = [_startCand, _roadSnap, _roadSnapHard] call _fn_snapToNearestRoad;
        private _endPos = [_endCand, _roadSnap, _roadSnapHard] call _fn_snapToNearestRoad;

        _startPos = [_startPos, _wsRR, _mRR] call _fn_clampWorld;
        _endPos = [_endPos, _wsRR, _mRR] call _fn_clampWorld;

	        // If the snapped endpoints violate min/max length, nudge the end offset and snap again.
	        private _distSE = _startPos distance2D _endPos;
	        private _tries = 0;
	        while { _tries < 6 && { (_distSE < _minLen) || (_distSE > _maxLen) } } do
	        {
	            _tries = _tries + 1;
	
	            private _targetLen = (_distSE max _minLen) min _maxLen;
	            private _delta = _targetLen - _distSE;
	
	            private _endOff2 = (_endOff + _delta) max 200;
	            _endOff2 = (_endOff2 max 250) min 8000;

	            private _endCand2 = _pos getPos [_endOff2, _dirLine];
	            _endCand2 resize 3;
	            _endCand2 = [_endCand2, _wsRR, _mRR] call _fn_clampWorld;

	            _endPos = [_endCand2, _roadSnap, _roadSnapHard] call _fn_snapToNearestRoad;
	            _endPos = [_endPos, _wsRR, _mRR] call _fn_clampWorld;
	
	            _distSE = _startPos distance2D _endPos;
	            _endOff = _endOff2;
	        };

        ["activeReconRouteEnabled", true] call ARC_fnc_stateSet;
        ["activeReconRouteStartPos", _startPos] call ARC_fnc_stateSet;
        ["activeReconRouteEndPos", _endPos] call ARC_fnc_stateSet;
        ["activeReconRouteStartReached", false] call ARC_fnc_stateSet;
        ["activeReconRouteEndReached", false] call ARC_fnc_stateSet;
        ["activeReconRouteStartRadius", _startRad] call ARC_fnc_stateSet;
        ["activeReconRouteEndRadius", _endRad] call ARC_fnc_stateSet;

        private _startTaskId = format ["%1_routeStart", _taskId];
        private _endTaskId = format ["%1_routeEnd", _taskId];

        ["activeReconRouteStartTaskId", _startTaskId] call ARC_fnc_stateSet;
        ["activeReconRouteEndTaskId", _endTaskId] call ARC_fnc_stateSet;

        // Create nested child tasks (start assigned; end created until start reached).
        if (!([_startTaskId] call BIS_fnc_taskExists)) then
        {
            private _tS = "Route Recon Start";
            private _dS = "Proceed to the route start point. Once on-site, begin route reconnaissance toward the end point.";
            [true, [_startTaskId, _taskId], [_dS, _tS, ""], _startPos, "ASSIGNED", 1, true, "MOVE", false] call BIS_fnc_taskCreate;
        };

        if (!([_endTaskId] call BIS_fnc_taskExists)) then
        {
            private _tE = "Route Recon End";
            private _dE = "Move along the route to the end point while observing and reporting. Avoid decisive engagement when possible.";
            [true, [_endTaskId, _taskId], [_dE, _tE, ""], _endPos, "CREATED", 1, false, "MOVE", false] call BIS_fnc_taskCreate;
        };

        // Keep the actionable child task "current" so the parent incident task does not override it.
        // (Route recon is sequential start -> end, so at init we force the start child to current.)
	        // Task "current" is local to each client; broadcast so players don't see the parent task override the child.
	        if (!(_startTaskId isEqualTo "")) then
	        {
	            [_startTaskId] remoteExecCall ["ARC_fnc_clientSetCurrentTask", 0];
	        };
    };
// Spawn an objective if this incident uses one
if (!(_objKind isEqualTo "")) then
{
    private _spawned = [];

    // Cache objectives use multiple containers; they are not a single netId objective.
    if (_objKind isEqualTo "CACHE_SEARCH") then
    {
        _spawned = [_taskId, _pos, _objRadius, _objAction] call _spawnCacheObjective;

        if (_spawned isEqualType [] && { (count _spawned) >= 3 }) then
        {
            private _basePos = _spawned select 0;
            private _nids = _spawned select 1;
            private _trueNid = _spawned select 2;

            ["activeObjectiveKind", _objKind] call ARC_fnc_stateSet;
            ["activeObjectiveClass", "CACHE"] call ARC_fnc_stateSet;
            ["activeObjectivePos", _basePos] call ARC_fnc_stateSet;
            ["activeObjectiveNetId", ""] call ARC_fnc_stateSet;
            ["activeObjectiveArmed", true] call ARC_fnc_stateSet;

            ["activeCacheContainerNetIds", _nids] call ARC_fnc_stateSet;
            ["activeCacheTrueNetId", _trueNid] call ARC_fnc_stateSet;

            missionNamespace setVariable ["ARC_activeObjective", objNull, true];
        };
    }
    else
    {
        _spawned = [_objKind, _objClass, _pos, _objRadius, _objAction, _failOnKilled] call _spawnObjective;
        if (_spawned isEqualType [] && { (count _spawned) >= 2 }) then
        {
            private _obj = _spawned select 0;
            private _oPos = _spawned select 1;

            ["activeObjectiveKind", _objKind] call ARC_fnc_stateSet;
            ["activeObjectiveClass", _objClass] call ARC_fnc_stateSet;
            ["activeObjectivePos", _oPos] call ARC_fnc_stateSet;
            ["activeObjectiveNetId", netId _obj] call ARC_fnc_stateSet;

            // If the objective can fail when killed, keep it unarmed until AO activation.
            ["activeObjectiveArmed", !(_failOnKilled)] call ARC_fnc_stateSet;

            missionNamespace setVariable ["ARC_activeObjective", _obj, true];
        };
    };
};

    // Spawn local friendly presence (host-nation police/army) for infrastructure tasks.
    // This is separate from the main AI threat layer; it can run during the objects-first phase.
    private _lsEnabled = missionNamespace getVariable ["ARC_localSupportEnabled", true];
    if (!(_lsEnabled isEqualType true) && !(_lsEnabled isEqualType false)) then { _lsEnabled = true; };

    if (_lsEnabled) then
    {
        private _lsNids = ["activeLocalSupportNetIds", []] call ARC_fnc_stateGet;
        if (!(_lsNids isEqualType [])) then { _lsNids = []; };

        private _haveLocal = false;
        {
            private _u = objectFromNetId _x;
            if (!isNull _u && { alive _u }) exitWith { _haveLocal = true; };
        } forEach _lsNids;

        if (!_haveLocal) then
        {
            private _spawnedLs = [_taskId, _typeU, _marker, _disp, _pos, _radius] call ARC_fnc_opsSpawnLocalSupport;

            if (_spawnedLs isEqualType [] && { (count _spawnedLs) > 0 }) then
            {
                ["activeLocalSupportNetIds", _spawnedLs] call ARC_fnc_stateSet;
                ["activeLocalSupportSpawned", true] call ARC_fnc_stateSet;
            }
            else
            {
                ["activeLocalSupportNetIds", []] call ARC_fnc_stateSet;
                ["activeLocalSupportSpawned", false] call ARC_fnc_stateSet;
            };
        };
    };

    // Spawn convoy package (LOGISTICS / ESCORT)
    if (_kind isEqualTo "CONVOY") then
    {
        // Resolve available start markers (supports ARC_convoy_start_# variants).
        private _startMarkers = [];
        if ("ARC_convoy_start" in allMapMarkers) then { _startMarkers pushBack "ARC_convoy_start"; };
        for "_i" from 1 to 12 do
        {
            private _mk = format ["ARC_convoy_start_%1", _i];
            if (_mk in allMapMarkers) then { _startMarkers pushBack _mk; };
        };

        private _cStartMarker = "";
        private _cMarkerPos = [];
        private _cDir = -1;

        // Mission-level explicit override still supported.
        private _overrideStart = missionNamespace getVariable ["ARC_convoyStartPos", []];
        private _overrideDir = missionNamespace getVariable ["ARC_convoyStartDir", -1];

        if (_overrideStart isEqualType [] && { (count _overrideStart) >= 2 }) then
        {
            _cMarkerPos = +_overrideStart; _cMarkerPos resize 3;
            _cDir = if (_overrideDir isEqualType 0 && { _overrideDir >= 0 }) then { _overrideDir % 360 } else { (_cMarkerPos getDir _pos) };
            _cStartMarker = "(override)";
        }
        else
        {
            if ((count _startMarkers) > 0) then
            {
                private _edgeMarkers = _startMarkers select { _x != "ARC_convoy_start" };
                private _useEdgeChance = missionNamespace getVariable ["ARC_convoyUseEdgeStartsChance", 0.45];
                if (!(_useEdgeChance isEqualType 0)) then { _useEdgeChance = 0.45; };
                _useEdgeChance = (_useEdgeChance max 0) min 1;

                // Escorts skew toward edge-starts; logistics are mixed.
                if (_typeU isEqualTo "ESCORT") then
                {
                    _useEdgeChance = (_useEdgeChance max 0.60) min 1;
                };

                private _useEdge = ((count _edgeMarkers) > 0) && { (random 1) < _useEdgeChance };
                _cStartMarker = if (_useEdge) then { selectRandom _edgeMarkers } else { selectRandom _startMarkers };

                _cMarkerPos = getMarkerPos _cStartMarker;
                _cMarkerPos resize 3;
                _cDir = markerDir _cStartMarker;
                if (!(_cDir isEqualType 0) || { _cDir < 0 }) then { _cDir = _cMarkerPos getDir _pos; };
                _cDir = _cDir % 360;
            }
            else
            {
                _cMarkerPos = +_basePos; _cMarkerPos resize 3;
                _cStartMarker = "(baseFallback)";
                _cDir = _cMarkerPos getDir _pos;
            };
        };

        // Helper: nearest road within radius (optionally avoid a named zone).
        // We heavily prefer road segments that are actually connected to the road graph.
        private _fn_nearestRoad = {
            params [
                ["_p", [0,0,0]],
                ["_rad", 120],
                ["_avoidZone", ""],
                ["_avoidNear", []],
                ["_avoidNearR", 220]
            ];

            if (!(_p isEqualType []) || { (count _p) < 2 }) exitWith { objNull };

            private _pos = +_p;
            _pos resize 3;

            private _roads = _pos nearRoads _rad;
            if ((count _roads) isEqualTo 0) exitWith { objNull };

            private _best = objNull;
            private _bestScore = 1e12;

            {
                private _rp = getPosATL _x;
                private _ok = true;

                if (!(_avoidZone isEqualTo "")) then
                {
                    private _z = [_rp] call ARC_fnc_worldGetZoneForPos;
                    if ((toUpper _z) isEqualTo (toUpper _avoidZone)) then
                    {
                        private _nearOk = (_avoidNear isEqualType [] && { (count _avoidNear) >= 2 } && { (_rp distance2D _avoidNear) <= _avoidNearR });
                        if (!_nearOk) then { _ok = false; };
                    };
                };

                if (_ok) then
                {
                    private _d = _pos distance2D _rp;

                    // Some map road objects (taxiways/parking/service segments) can be disconnected.
                    // If we snap to those, A* can't build a real route and you get a single straight-line leg.
                    private _conN = count (roadsConnectedTo _x);
                    private _conPen = if (_conN isEqualTo 0) then { 5000 } else { 0 };

                    private _score = _d + _conPen;
                    if (_score < _bestScore) then { _bestScore = _score; _best = _x; };
                };
            } forEach _roads;

            _best
        };

        // Snap convoy destination waypoint to a nearby road to reduce cross-country cutting.
        private _destWp = +_pos;
        _destWp resize 3;
        private _snapR = missionNamespace getVariable ["ARC_convoyDestSnapM", 150];
        if (!(_snapR isEqualType 0)) then { _snapR = 150; };
        _snapR = (_snapR max 30) min 600;
        private _rD = [_pos, _snapR] call _fn_nearestRoad;
        if (!isNull _rD) then
        {
            _destWp = getPosATL _rD;
            _destWp resize 3;
        };
        ["activeConvoyDestWpPos", _destWp] call ARC_fnc_stateSet;

        // Edge-starts: spawn slightly inset so the column doesn't place vehicles outside the map boundary.
        private _edgeInset = missionNamespace getVariable ["ARC_convoyEdgeSpawnInsetM", 60];
        if (!(_edgeInset isEqualType 0)) then { _edgeInset = 60; };
        _edgeInset = (_edgeInset max 0) min 250;

        private _spawnPos = +_cMarkerPos;
        _spawnPos resize 3;

        private _isEdgeStart = (!(_cStartMarker isEqualTo "") && { !(_cStartMarker isEqualTo "ARC_convoy_start") } && { !(_cStartMarker isEqualTo "(override)") });
        if (_isEdgeStart && { _edgeInset > 0 }) then
        {
            // Inset inward (toward Airbase/JBF), not along markerDir (markers may be imperfect).
            private _inDir = _cMarkerPos getDir _basePos;
            _spawnPos = _cMarkerPos getPos [_edgeInset, _inDir];
            _spawnPos resize 3;
            _cDir = _inDir % 360;
        };

        // Road snapping + link-up computation
        // Goals:
        //  - Spawn and link-up points snap cleanly to the road network
        //  - Do not spawn inside the Airbase zone (per design)
        //  - Edge-start convoys roll inland (toward JBF) before holding at link-up

        private _roadSnap = missionNamespace getVariable ["ARC_convoyRoadSnapM", 120];
        if (!(_roadSnap isEqualType 0)) then { _roadSnap = 120; };
        _roadSnap = (_roadSnap max 20) min 400;

        // Link-up distance (meters). For edge-start convoys this is the "roll-in" leg.
        private _distLink = missionNamespace getVariable ["ARC_convoyLinkupDistM", 650];
        if (!(_distLink isEqualType 0)) then { _distLink = 650; };
        _distLink = (_distLink max 80) min 2000;

        // Non-edge convoys only need a short "clear the pad" roll.
// Exception: Airbase (ARC_convoy_start) spawns should stage farther out so the link-up is outside the base area.
        if (!_isEdgeStart) then
        {
            private _isBaseStart = (_cStartMarker isEqualTo "ARC_convoy_start") || { _cStartMarker isEqualTo "(baseFallback)" };
            if (_isBaseStart) then
            {
                _distLink = (_distLink max 450) min 1200;
            }
            else
            {
                _distLink = (_distLink min 250) max 80;
            };
        };

        // Link-up bias target:
        // - Edge-start convoys: move inward toward the Airbase/JBF.
        // - Non-edge convoys: move toward the objective.
        private _linkTarget = if (_isEdgeStart) then { _basePos } else { _destWp };

        // 1) Snap spawn to a road, explicitly avoiding the Airbase zone.
        private _spawnRoad = objNull;
        private _rTry = _roadSnap;

        for "_k" from 0 to 2 do
        {
            _spawnRoad = [_spawnPos, _rTry, "Airbase"] call _fn_nearestRoad;
            if (!isNull _spawnRoad) exitWith {};
            _rTry = _rTry * 1.75;
        };

        if (isNull _spawnRoad) then
        {
            // Fallback (rare): accept any road rather than spawning off-road.
            _spawnRoad = [_spawnPos, _rTry] call _fn_nearestRoad;
        };

        if (!isNull _spawnRoad) then
        {
            _spawnPos = getPosATL _spawnRoad;
            _spawnPos resize 3;
        };

        // 2) Spawn direction policy
        // Vehicles should spawn facing the editor marker direction.
        // (Road-axis alignment can be useful, but it frequently causes tight-pad spawns to yaw into barriers.)
        private _markerDir = (_cDir % 360);
        private _spawnDir  = _markerDir;

        // 3) Compute link-up along the road network (preferred).
        // Base-start (ARC_convoy_start): push link-up OUTWARD away from the Airbase so convoys don't roll into the flightline.
        private _linkupPos = [];
        private _linkTargetLink = _linkTarget;

        private _isBaseStart2 = (!_isEdgeStart) && { (_cStartMarker isEqualTo "ARC_convoy_start") || { _cStartMarker isEqualTo "(baseFallback)" } };
        // Optional preset link-up markers (editor placed).
        // Mapping:
        //   ARC_convoy_start      -> ARC_convoy_linkup_airbase
        //   ARC_convoy_start_<N>  -> ARC_convoy_linkup_<N>
        // If present and valid, we use the preset (snapped to the nearest road) and skip dynamic link-up projection.
        private _usePresetLinkups = missionNamespace getVariable ["ARC_convoyUsePresetLinkups", true];
        if (!(_usePresetLinkups isEqualType true) && !(_usePresetLinkups isEqualType false)) then { _usePresetLinkups = true; };

        private _presetLinkMk = "";
        if (_usePresetLinkups) then
        {
            if ((_cStartMarker isEqualTo "ARC_convoy_start") || { _cStartMarker isEqualTo "(baseFallback)" }) then
            {
                _presetLinkMk = "ARC_convoy_linkup_airbase";
            }
            else
            {
                private _pref = "ARC_convoy_start_";
                if ((_cStartMarker find _pref) isEqualTo 0) then
                {
                    private _suffix = _cStartMarker select [count _pref];
                    private _idx = parseNumber _suffix;
                    if (_idx > 0) then { _presetLinkMk = format ["ARC_convoy_linkup_%1", _idx]; };
                };
            };
        };

        private _havePresetLink = false;
        private _presetLinkPos = [];

        if (!(_presetLinkMk isEqualTo "") && { _presetLinkMk in allMapMarkers }) then
        {
            _presetLinkPos = getMarkerPos _presetLinkMk;
            if (_presetLinkPos isEqualType [] && { (count _presetLinkPos) >= 2 }) then
            {
                _presetLinkPos resize 3;

                // Snap preset to the road network (avoid Airbase roads for base-starts).
                private _snapR3 = (_roadSnap max 60) min 500;
                private _rL = if (_isBaseStart2) then { [_presetLinkPos, _snapR3, "Airbase"] call _fn_nearestRoad } else { [_presetLinkPos, _snapR3] call _fn_nearestRoad };
                if (!isNull _rL) then { _presetLinkPos = getPosATL _rL; _presetLinkPos resize 3; };

                // Sanity: ensure it is far enough away to let vehicles clear the pad.
                private _minPreset = missionNamespace getVariable ["ARC_convoyPresetLinkupMinDistM", 80];
                if (!(_minPreset isEqualType 0)) then { _minPreset = 80; };
                _minPreset = (_minPreset max 20) min 500;

                if ((_spawnPos distance2D _presetLinkPos) >= _minPreset) then
                {
                    private _ok = true;
                    if (_isBaseStart2) then { if ((toUpper ([_presetLinkPos] call ARC_fnc_worldGetZoneForPos)) isEqualTo "AIRBASE") then { _ok = false; }; };

                    if (_ok) then
                    {
                        _linkupPos = +_presetLinkPos;
                        _linkupPos resize 3;
                        _havePresetLink = true;
                    };
                };
            };
        };

        ["activeConvoyLinkupMarker", if (_havePresetLink) then { _presetLinkMk } else { "" }] call ARC_fnc_stateSet;

        if (!_havePresetLink) then
        {
        if (_isBaseStart2) then
        {
            _distLink = (_distLink max 800) min 1500;
            _linkTargetLink = _spawnPos getPos [5000, _markerDir];
            _linkTargetLink resize 3;
        };

        private _picked = [_linkTargetLink, _distLink, _spawnPos, _spawnDir, false] call ARC_fnc_worldPickConvoySpawnAndLink;

        if (_picked isEqualType [] && { (count _picked) >= 3 }) then
        {
            _spawnPos = +(_picked select 0); _spawnPos resize 3;
            _linkupPos = +(_picked select 2); _linkupPos resize 3;
        }
        else
        {
            // Fallback: straight-line linkup + road snap.
            private _dirIn = (_spawnPos getDir _linkTargetLink) % 360;
            private _p = _spawnPos getPos [_distLink, _dirIn];
            _p resize 3;

            // Keep link-up reasonably inside the map.
            private _ws = worldSize;
            private _margin = 150;
            _p set [0, ((_p select 0) max _margin) min (_ws - _margin)];
            _p set [1, ((_p select 1) max _margin) min (_ws - _margin)];

            private _snapR2 = (_roadSnap max 100) min 500;
            private _rL = if (_isBaseStart2) then { [_p, _snapR2, "Airbase"] call _fn_nearestRoad } else { [_p, _snapR2] call _fn_nearestRoad };
            if (!isNull _rL) then { _p = getPosATL _rL; _p resize 3; };

            _linkupPos = _p;
        };

        // Safety: if a base-start link-up still ends up inside the Airbase zone, push it further outward.
        if (_isBaseStart2 && { _linkupPos isEqualType [] } && { (count _linkupPos) >= 2 }) then
        {
            private _zL = [_linkupPos] call ARC_fnc_worldGetZoneForPos;
            if ((toUpper _zL) isEqualTo "AIRBASE") then
            {
                private _step = 200;
                for "_k" from 0 to 4 do
                {
                    private _p2 = _linkupPos getPos [_step, _markerDir];
                    _p2 resize 3;
                    private _r2 = [_p2, (_roadSnap max 150) min 600, "Airbase"] call _fn_nearestRoad;
                    if (!isNull _r2) then { _linkupPos = getPosATL _r2; _linkupPos resize 3; };
                    private _z2 = [_linkupPos] call ARC_fnc_worldGetZoneForPos;
                    if (!((toUpper _z2) isEqualTo "AIRBASE")) exitWith {};
                    _step = _step + 200;
                };
            };
        };

        };

        ["activeConvoyStartMarker", _cStartMarker] call ARC_fnc_stateSet;
        ["activeConvoySpawnPos", _spawnPos] call ARC_fnc_stateSet;
        ["activeConvoyStartPos", _spawnPos] call ARC_fnc_stateSet;
        ["activeConvoyStartDir", _markerDir] call ARC_fnc_stateSet;
        ["activeConvoyLinkupPos", _linkupPos] call ARC_fnc_stateSet;
        ["activeConvoyLinkupReached", false] call ARC_fnc_stateSet;

        // Link-up subtask is created after the convoy is fully spawned and moving.
        ["activeConvoyLinkupTaskId", ""] call ARC_fnc_stateSet;
        ["activeConvoyLinkupTaskDone", false] call ARC_fnc_stateSet;


        // Visible marker policy:
// - Do NOT display convoy spawn points to players.
// - Link-up points are displayed (and also registered as a task).
if ("ARC_convoy_start_active" in allMapMarkers) then { deleteMarker "ARC_convoy_start_active"; };

private _showSpawnMarker = missionNamespace getVariable ["ARC_debugShowConvoySpawnMarker", false];
if (!(_showSpawnMarker isEqualType true) && !(_showSpawnMarker isEqualType false)) then { _showSpawnMarker = false; };
if (_showSpawnMarker) then
{
    createMarker ["ARC_convoy_start_active", _spawnPos];
    "ARC_convoy_start_active" setMarkerType "mil_start";
    "ARC_convoy_start_active" setMarkerColor "ColorWEST";
    "ARC_convoy_start_active" setMarkerDir _markerDir;
    "ARC_convoy_start_active" setMarkerText format ["Convoy Spawn (DEBUG): %1", _disp];
    "ARC_convoy_start_active" setMarkerAlpha 0.85;
};

        if ("ARC_convoy_linkup_active" in allMapMarkers) then { deleteMarker "ARC_convoy_linkup_active"; };
        if (_linkupPos isEqualType [] && { (count _linkupPos) >= 2 }) then
        {
            createMarker ["ARC_convoy_linkup_active", _linkupPos];
            "ARC_convoy_linkup_active" setMarkerType "mil_pickup";
            "ARC_convoy_linkup_active" setMarkerColor "ColorWEST";
            "ARC_convoy_linkup_active" setMarkerText format ["Convoy Link-up%1", if (_havePresetLink) then { " (Preset)" } else { "" }];
            "ARC_convoy_linkup_active" setMarkerAlpha 0.85;
        };

        // Build and optionally display convoy route (from link-up or spawn to the destination road waypoint).
        // This improves bridge consistency and reduces end-of-route offroad shortcuts.
        // Stored to state so execTickConvoy can create multiple road-following waypoints.
        private _oldRouteMarkers = ["activeConvoyRouteMarkers", []] call ARC_fnc_stateGet;
        if (_oldRouteMarkers isEqualType []) then
        {
            { if (_x isEqualType "" && { _x in allMapMarkers }) then { deleteMarker _x; }; } forEach _oldRouteMarkers;
        };
        ["activeConvoyRouteMarkers", []] call ARC_fnc_stateSet;
        ["activeConvoyRoutePoints",  []] call ARC_fnc_stateSet;
        ["activeConvoyRouteLenM",    -1] call ARC_fnc_stateSet;

        private _routeStart = if (_linkupPos isEqualType [] && { (count _linkupPos) >= 2 }) then { _linkupPos } else { _spawnPos };
        private _routeEnd   = if (_destWp isEqualType [] && { (count _destWp) >= 2 }) then { _destWp } else { _destPos };

        // Airbase ingress control:
        // For inbound convoys whose destination is inside the Airbase zone, force the route to pass through the
        // editor-placed marker "North_Gate".
        // This prevents AI from trying to take a cross-country shortcut over the airfield/runway area.
        private _ingressPos = [];
        private _useIngress = false;

        private _zEnd = [_routeEnd] call ARC_fnc_worldGetZoneForPos;
        private _zStart = [_routeStart] call ARC_fnc_worldGetZoneForPos;

        if ((toUpper _zEnd) isEqualTo "AIRBASE" && { !((toUpper _zStart) isEqualTo "AIRBASE") } && { "North_Gate" in allMapMarkers }) then
        {
            _ingressPos = getMarkerPos "North_Gate";
            _ingressPos resize 3;
            _useIngress = true;
        };

        private _routePts = [];
        private _routeBuildDiag = [];
        private _routeUsedFallbackAny = false;
        private _snapM = missionNamespace getVariable ["ARC_convoyRoadSnapM", 120];
        if (!(_snapM isEqualType 0)) then { _snapM = 120; };
        _snapM = (_snapM max 40) min 400;

        // Snap ingress to the road network (marker may sit slightly off the asphalt).
        if (_useIngress) then
        {
            private _rG = [_ingressPos, _snapM] call _fn_nearestRoad;
            if (!isNull _rG) then
            {
                _ingressPos = getPosATL _rG;
                _ingressPos resize 3;
            };
        };

        // Persist ingress point for convoy tick (used to force a waypoint at the gate).
        ["activeConvoyIngressPos", if (_useIngress) then { _ingressPos } else { [] }] call ARC_fnc_stateSet;

        // Helper: build a road-following route using A* over the road graph.
        // Returns a list of positions along the road chain (snapped to the road network).
        private _fn_buildRoadRoute = {
            params [
                ["_pStart", [0,0,0]],
                ["_pEnd",   [0,0,0]],
                ["_snap",   120],
                ["_avoidZone", ""],
                ["_avoidNear", []],
                ["_avoidNearR", 180]
            ];

            private _diagAStarSucceeded = false;
            private _diagFallbackUsed = false;

            private _fn_logRouteResult = {
                params ["_aStarOk", "_fallbackUsed", "_pts", ["_reason", ""]];

                private _lenM = [_pts] call _fn_routeLen;
                private _nPts = if (_pts isEqualType []) then { count _pts } else { 0 };

                _routeBuildDiag pushBack [_aStarOk, _fallbackUsed, _nPts, _lenM];
                if (_fallbackUsed) then { _routeUsedFallbackAny = true; };

                diag_log format [
                    "[ARC][ConvoyRoute] A* success=%1 fallback=%2 points=%3 lenM=%4 reason=%5",
                    _aStarOk,
                    _fallbackUsed,
                    _nPts,
                    round _lenM,
                    _reason
                ];
            };

            private _fn_routeLen = {
                params ["_pts"];

                private _len = 0;
                if (_pts isEqualType [] && { (count _pts) >= 2 }) then
                {
                    for "_li" from 1 to ((count _pts) - 1) do
                    {
                        _len = _len + ((_pts select (_li - 1)) distance2D (_pts select _li));
                    };
                };

                _len
            };

            private _fn_fallbackRoute = {
                params ["_s", "_e", "_snapLocal", "_avoidZoneLocal", "_avoidNearLocal", "_avoidNearRLocal"];


// sqflint-compatible helpers
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";
                private _hardSnap = missionNamespace getVariable ["ARC_convoyRoadSnapHardM", (_snapLocal * 4)];
                if (!(_hardSnap isEqualType 0)) then { _hardSnap = (_snapLocal * 4); };
                _hardSnap = (_hardSnap max (_snapLocal + 80)) min 1400;

                private _sampleStep = missionNamespace getVariable ["ARC_convoyFallbackSampleStepM", 180];
                if (!(_sampleStep isEqualType 0)) then { _sampleStep = 180; };
                _sampleStep = (_sampleStep max 80) min 500;

                private _distSE = _s distance2D _e;
                private _sampleCount = ceil (_distSE / _sampleStep);
                _sampleCount = (_sampleCount max 2) min 32;

                private _fallback = [];
                for "_si" from 0 to _sampleCount do
                {
                    private _t = _si / _sampleCount;
                    private _probe = [
                        (_s select 0) + ((_e select 0) - (_s select 0)) * _t,
                        (_s select 1) + ((_e select 1) - (_s select 1)) * _t,
                        0
                    ];

                    private _r = if (!(_avoidZoneLocal isEqualTo "")) then
                    {
                        [_probe, _hardSnap, _avoidZoneLocal, _avoidNearLocal, _avoidNearRLocal] call _fn_nearestRoad
                    }
                    else
                    {
                        [_probe, _hardSnap] call _fn_nearestRoad
                    };

                    private _pt = +_probe;
                    if (!isNull _r) then
                    {
                        _pt = getPosATL _r;
                        _pt resize 3;
                    };

                    if ((count _fallback) isEqualTo 0 || { _pt distance2D (_fallback select ((count _fallback) - 1)) > 20 }) then
                    {
                        _fallback pushBack _pt;
                    };
                };

                if ((count _fallback) < 3) then
                {
                    private _mid = [(_s select 0) + ((_e select 0) - (_s select 0)) * 0.50, (_s select 1) + ((_e select 1) - (_s select 1)) * 0.50, 0];
                    _fallback = [+_s, _mid, +_e];
                };

                // Snap endpoints to nearby roads (if available) so fallback remains road-biased.
                private _rStart = if (!(_avoidZoneLocal isEqualTo "")) then
                {
                    [_s, _hardSnap, _avoidZoneLocal, _avoidNearLocal, _avoidNearRLocal] call _fn_nearestRoad
                }
                else
                {
                    [_s, _hardSnap] call _fn_nearestRoad
                };

                private _rEnd = if (!(_avoidZoneLocal isEqualTo "")) then
                {
                    [_e, _hardSnap, _avoidZoneLocal, _avoidNearLocal, _avoidNearRLocal] call _fn_nearestRoad
                }
                else
                {
                    [_e, _hardSnap] call _fn_nearestRoad
                };

                if ((count _fallback) > 0) then
                {
                    if (!isNull _rStart) then
                    {
                        private _ps = getPosATL _rStart; _ps resize 3;
                        _fallback set [0, _ps];
                    };

                    if (!isNull _rEnd) then
                    {
                        private _pe = getPosATL _rEnd; _pe resize 3;
                        _fallback set [((count _fallback) - 1), _pe];
                    };
                };

                _fallback
            };

            // When we're avoiding a zone (ex: Airbase), also avoid snapping the start/end to a road inside that zone.
            private _r0 = if (!(_avoidZone isEqualTo "")) then
            {
                [_pStart, _snap, _avoidZone, _avoidNear, _avoidNearR] call _fn_nearestRoad
            }
            else
            {
                [_pStart, _snap] call _fn_nearestRoad
            };

            private _r1 = if (!(_avoidZone isEqualTo "")) then
            {
                [_pEnd, _snap, _avoidZone, _avoidNear, _avoidNearR] call _fn_nearestRoad
            }
            else
            {
                [_pEnd, _snap] call _fn_nearestRoad
            };

            if (isNull _r0 || { isNull _r1 }) exitWith
            {
                _diagFallbackUsed = true;
                private _fb = [_pStart, _pEnd, _snap, _avoidZone, _avoidNear, _avoidNearR] call _fn_fallbackRoute;
                [false, _diagFallbackUsed, _fb, "snap_failed"] call _fn_logRouteResult;
                _fb
            };

            private _k0 = str _r0;
            private _k1 = str _r1;

            private _pGoal = getPosATL _r1; _pGoal resize 3;

            private _open = [_r0];
            private _openKey = createHashMap;
            _openKey set [_k0, true];

            private _closed = createHashMap;
            private _came   = createHashMap;
            private _g      = createHashMap;
            private _f      = createHashMap;

            // Map key->road object for reconstruction (roads are local terrain objects).
            private _node = createHashMap;
            _node set [_k0, _r0];
            _node set [_k1, _r1];

            _g set [_k0, 0];
            _f set [_k0, ((getPosATL _r0) distance2D _pGoal)];

            private _maxIter = missionNamespace getVariable ["ARC_convoyRouteAStarMaxIter", 25000];
            if (!(_maxIter isEqualType 0)) then { _maxIter = 25000; };
            _maxIter = (_maxIter max 2500) min 50000;

            private _found = false;

            for "_iter" from 0 to (_maxIter - 1) do
            {
                if ((count _open) isEqualTo 0) exitWith {};

                // Pick open node with lowest f-score.
                private _bestIdx = 0;
                private _best    = _open select 0;
                private _bestKey = str _best;
                private _bestF   = [_f, _bestKey, 1e12] call _hg;

                for "_i" from 1 to ((count _open) - 1) do
                {
                    private _r  = _open select _i;
                    private _rk = str _r;
                    private _fv = [_f, _rk, 1e12] call _hg;
                    if (_fv < _bestF) then { _bestF = _fv; _bestIdx = _i; _best = _r; _bestKey = _rk; };
                };

                if (_best isEqualTo _r1) exitWith { _found = true; };

                _open deleteAt _bestIdx;
                _openKey set [_bestKey, false];
                _closed set [_bestKey, true];

                private _curPos = getPosATL _best; _curPos resize 3;
                private _gCur   = [_g, _bestKey, 1e12] call _hg;

                {
                    private _nbr = _x;
                    private _nk  = str _nbr;

                    if !([_closed, _nk, false] call _hg) then
                    {
                        _node set [_nk, _nbr];

                        private _nbrPos = getPosATL _nbr; _nbrPos resize 3;

                        // Optional zone avoidance: penalize candidates inside the avoid zone, except close to the
                        // allowed "near" point (used so inbound convoys do not cut across the airfield).
                        private _zPen = 0;
                        if (!(_avoidZone isEqualTo "")) then
                        {
                            private _z = [_nbrPos] call ARC_fnc_worldGetZoneForPos;
                            if ((toUpper _z) isEqualTo (toUpper _avoidZone)) then
                            {
                                private _nearOk = (_avoidNear isEqualType [] && { (count _avoidNear) >= 2 } && { (_nbrPos distance2D _avoidNear) <= _avoidNearR });
                                if (!_nearOk) then { _zPen = 5000; };
                            };
                        };

                        private _tent = _gCur + (_curPos distance2D _nbrPos) + _zPen;
                        private _gOld = [_g, _nk, 1e12] call _hg;

                        if (_tent < _gOld) then
                        {
                            _came set [_nk, _bestKey];
                            _g set [_nk, _tent];
                            _f set [_nk, _tent + (_nbrPos distance2D _pGoal)];

                            if !([_openKey, _nk, false] call _hg) then
                            {
                                _open pushBack _nbr;
                                _openKey set [_nk, true];
                            };
                        };
                    };
                } forEach (roadsConnectedTo _best);
            };

            if (!_found) exitWith
            {
                _diagFallbackUsed = true;
                private _fb = [_pStart, _pEnd, _snap, _avoidZone, _avoidNear, _avoidNearR] call _fn_fallbackRoute;
                [false, _diagFallbackUsed, _fb, "astar_no_path"] call _fn_logRouteResult;
                _fb
            };

            // Reconstruct path keys from goal back to start.
            private _keys = [];
            private _ck = _k1;

            for "_i" from 0 to 40000 do
            {
                _keys pushBack _ck;
                if (_ck isEqualTo _k0) exitWith {};

                private _prev = [_came, _ck, ""] call _hg;
                if (_prev isEqualTo "") exitWith { _keys = []; };

                _ck = _prev;
            };

            if ((count _keys) == 0) exitWith
            {
                _diagFallbackUsed = true;
                private _fb = [_pStart, _pEnd, _snap, _avoidZone, _avoidNear, _avoidNearR] call _fn_fallbackRoute;
                [false, _diagFallbackUsed, _fb, "astar_reconstruct_failed"] call _fn_logRouteResult;
                _fb
            };

            reverse _keys;

            // Convert to positions, keeping a reasonable point spacing (helps waypoint placement).
            private _pts = [];

            {
                private _r = [_node, _x, objNull] call _hg;
                if (!isNull _r) then
                {
                    private _p = getPosATL _r; _p resize 3;
                    if ((count _pts) isEqualTo 0 || { (_p distance2D (_pts select ((count _pts) - 1))) > 25 }) then
                    {
                        _pts pushBack _p;
                    };
                };
            } forEach _keys;

            // Ensure end point is present.
            private _pEndRoad = getPosATL _r1; _pEndRoad resize 3;
            if ((count _pts) isEqualTo 0 || { (_pEndRoad distance2D (_pts select ((count _pts) - 1))) > 10 }) then
            {
                _pts pushBack _pEndRoad;
            };

            _diagAStarSucceeded = true;
            [_diagAStarSucceeded, _diagFallbackUsed, _pts, "astar_path"] call _fn_logRouteResult;

            _pts
        };

        if (_useIngress) then
        {
            // First leg (outside -> gate): discourage cutting through the Airbase zone until we reach the gate.
            private _avoidR = missionNamespace getVariable ["ARC_convoyIngressNearGateM", 220];
            if (!(_avoidR isEqualType 0)) then { _avoidR = 220; };
            _avoidR = (_avoidR max 80) min 600;

            private _legA = [_routeStart, _ingressPos, _snapM, "Airbase", _ingressPos, _avoidR] call _fn_buildRoadRoute;
            private _legB = [_ingressPos, _routeEnd, _snapM] call _fn_buildRoadRoute;

            _routePts = +_legA;
            if ((count _routePts) > 0 && { (count _legB) > 0 }) then
            {
                private _pJoin = _legB select 0;
                if (((_routePts select ((count _routePts) - 1)) distance2D _pJoin) < 10) then
                {
                    _legB deleteAt 0;
                };
                _routePts append _legB;
            };
        }
        else
        {
            // General case: build a road route, but discourage cutting through the Airbase zone
            // when neither the start nor the destination is inside the Airbase.
            private _avoidZone = "";
            private _avoidNear = [];
            private _avoidNearR = 220;

            if (!((toUpper _zStart) isEqualTo "AIRBASE") && { !((toUpper _zEnd) isEqualTo "AIRBASE") }) then
            {
                _avoidZone = "Airbase";
                if ("North_Gate" in allMapMarkers) then
                {
                    _avoidNear = getMarkerPos "North_Gate";
                    _avoidNear resize 3;
                    // Allow a small corridor near the gate road network in case the zone boundary overlaps access roads.
                    _avoidNearR = missionNamespace getVariable ["ARC_convoyAirbaseAvoidNearGateM", 350];
                    if (!(_avoidNearR isEqualType 0)) then { _avoidNearR = 350; };
                    _avoidNearR = (_avoidNearR max 120) min 800;
                };
            };

            _routePts = [_routeStart, _routeEnd, _snapM, _avoidZone, _avoidNear, _avoidNearR] call _fn_buildRoadRoute;
            ["activeConvoyIngressPos", []] call ARC_fnc_stateSet;
        };

        if (_routeUsedFallbackAny && { (count _routePts) < 3 } && { (count _routePts) >= 2 }) then
        {
            _routePts = [_routePts select 0, _routePts select 1, _snapM, "", [], 0] call _fn_buildRoadRoute;
        };

        // Store route points for the convoy tick (waypoint build) and compute an approximate road-distance.
        private _routeLen = 0;
        if ((count _routePts) >= 2) then
        {
            for "_i" from 1 to ((count _routePts) - 1) do
            {
                _routeLen = _routeLen + ((_routePts select (_i - 1)) distance2D (_routePts select _i));
            };
        };

        diag_log format [
            "[ARC][ConvoyRoute] Summary: calls=%1 fallbackAny=%2 finalPoints=%3 finalLenM=%4",
            count _routeBuildDiag,
            _routeUsedFallbackAny,
            count _routePts,
            round _routeLen
        ];
        ["activeConvoyRoutePoints", _routePts] call ARC_fnc_stateSet;
        ["activeConvoyRouteLenM", _routeLen] call ARC_fnc_stateSet;

        // Route markers (optional): small dots along the route for escort planning.
        private _rmEnabled = missionNamespace getVariable ["ARC_convoyRouteMarkersEnabled", true];
        if (!(_rmEnabled isEqualType false) && !(_rmEnabled isEqualType true)) then { _rmEnabled = true; };
        if (_rmEnabled && { (count _routePts) >= 2 }) then
        {
            private _rmCount = missionNamespace getVariable ["ARC_convoyRouteMarkerCount", 10];
            if (!(_rmCount isEqualType 0)) then { _rmCount = 10; };
            _rmCount = (_rmCount max 3) min 20;

            private _rmAlpha = missionNamespace getVariable ["ARC_convoyRouteMarkerAlpha", 0.35];
            if (!(_rmAlpha isEqualType 0)) then { _rmAlpha = 0.35; };
            _rmAlpha = (_rmAlpha max 0.05) min 0.9;

            private _names = [];

// Sample along the polyline by distance so markers spread across the full route,
// even when _routePts is sparse (ex: a short or fallback route).
private _total = _routeLen;
if (!(_total isEqualType 0) || { _total <= 0 }) then
{
    _total = 0;
    for "_k" from 1 to ((count _routePts) - 1) do
    {
        _total = _total + ((_routePts select (_k - 1)) distance2D (_routePts select _k));
    };
};

private _cum = [0];
private _acc = 0;
for "_k" from 1 to ((count _routePts) - 1) do
{
    _acc = _acc + ((_routePts select (_k - 1)) distance2D (_routePts select _k));
    _cum pushBack _acc;
};

for "_i" from 0 to (_rmCount - 1) do
{
    private _t = if ((_rmCount - 1) > 0) then { _i / (_rmCount - 1) } else { 0 };
    private _dReq = _total * _t;

    private _p = +(_routePts select 0);
    _p resize 3;

    // Find segment containing _dReq.
    private _seg = 0;
    for "_s" from 1 to ((count _cum) - 1) do
    {
        if ((_cum select _s) >= _dReq) exitWith { _seg = _s; };
        _seg = _s;
    };

    if (_seg > 0) then
    {
        private _a = _cum select (_seg - 1);
        private _b = _cum select _seg;

        private _pA = +(_routePts select (_seg - 1));
        private _pB = +(_routePts select _seg);
        _pA resize 3; _pB resize 3;

        private _den = ((_b - _a) max 0.001);
        private _u = ((_dReq - _a) / _den);
        _u = (_u max 0) min 1;

        private _dx = (_pB select 0) - (_pA select 0);
        private _dy = (_pB select 1) - (_pA select 1);
        _p = [(_pA select 0) + (_dx * _u), (_pA select 1) + (_dy * _u), _pA select 2];
        _p resize 3;
    };

    private _mk = format ["ARC_convoy_route_active_%1", _i];
    if (_mk in allMapMarkers) then { deleteMarker _mk; };
    createMarker [_mk, _p];
    _mk setMarkerType "mil_dot";
    _mk setMarkerColor "ColorWEST";
    _mk setMarkerAlpha _rmAlpha;
    _mk setMarkerSize [0.7, 0.7];
    if (_i isEqualTo 0) then { _mk setMarkerText "Convoy Route"; };
    _names pushBack _mk;
};
["activeConvoyRouteMarkers", _names] call ARC_fnc_stateSet;
        };

        // Ensure convoy tasks have enough time to complete (edge-start convoys can outlast the default deadline model).
        // We extend the existing deadline only; never shorten.
        private _now2 = serverTime;
        private _createdAt2 = ["activeIncidentCreatedAt", _now2] call ARC_fnc_stateGet;
        if (!(_createdAt2 isEqualType 0) || { _createdAt2 <= 0 }) then { _createdAt2 = _now2; };

        private _overhead = missionNamespace getVariable ["ARC_convoyDeadlineOverheadSec", 1200];
        if (!(_overhead isEqualType 0)) then { _overhead = 1200; };
        _overhead = (_overhead max 300) min 7200;
        if (_linkupPos isEqualType [] && { (count _linkupPos) >= 2 }) then { _overhead = _overhead + 600; };

        private _etaFactor = missionNamespace getVariable ["ARC_convoyETAFactor", 1.35];
        if (!(_etaFactor isEqualType 0)) then { _etaFactor = 1.35; };
        _etaFactor = (_etaFactor max 1.0) min 2.5;

        // Use a conservative speed for ETA/deadline math. Convoys routinely run slower than the nominal cap,
        // especially with longer columns and bridge/corner navigation.
        private _vms = (((_speedKph max 10) min 20)) / 3.6;
        private _etaSec = 0;
        if (_routeLen > 0) then
        {
            _etaSec = (_routeLen * _etaFactor) / _vms;
        }
        else
        {
            _etaSec = ((_routeStart distance2D _routeEnd) * _etaFactor) / _vms;
        };

        // Add a small destination dwell + buffer.
        private _needed = _overhead + _etaSec + 900;
        private _candDeadlineAt = _createdAt2 + _needed;

        private _curDeadlineAt = ["activeExecDeadlineAt", -1] call ARC_fnc_stateGet;
        if (!(_curDeadlineAt isEqualType 0) || { _curDeadlineAt <= 0 }) then { _curDeadlineAt = _candDeadlineAt; };

        if (_candDeadlineAt > _curDeadlineAt) then
        {
            ["activeExecDeadlineAt", _candDeadlineAt] call ARC_fnc_stateSet;
        };

        // Convoy supply emphasis (used to adjust base resources on completion).
        // We select the scarcest stock at the time the task is generated.
        private _supplyKind = "";
        if (_typeU in ["LOGISTICS","ESCORT"]) then
        {
            private _f = ["baseFuel", 0.75] call ARC_fnc_stateGet;
            private _a = ["baseAmmo", 0.65] call ARC_fnc_stateGet;
            private _m = ["baseMed", 0.80] call ARC_fnc_stateGet;
            if (!(_f isEqualType 0)) then { _f = 0.75; };
            if (!(_a isEqualType 0)) then { _a = 0.65; };
            if (!(_m isEqualType 0)) then { _m = 0.80; };
            private _min = (_f min _a) min _m;
            _supplyKind = if (_min isEqualTo _f) then {"FUEL"} else { if (_min isEqualTo _a) then {"AMMO"} else {"MED"} };
        };

        // Convoy role-bundle plan: map incident context to stable role identifiers for spawn-time consumption.
        // Stored as key/value pairs for broad SQF compatibility (no hashMap dependency).
        private _isVipEscort = false;
        if (_typeU isEqualTo "ESCORT") then
        {
            private _incidentMarker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
            if (!(_incidentMarker isEqualType "")) then { _incidentMarker = ""; };

            private _incidentName = ["activeIncidentName", ""] call ARC_fnc_stateGet;
            if (!(_incidentName isEqualType "")) then { _incidentName = ""; };

            if (_incidentMarker in ["ARC_loc_PresidentialPalace", "ARC_loc_EmbassyCompound"]) then
            {
                _isVipEscort = true;
            }
            else
            {
                private _nU = toUpper _incidentName;
                _isVipEscort = ((_nU find "MOTORCADE") >= 0)
                    || { (_nU find "DIPLOMATIC") >= 0 }
                    || { (_nU find "VIP") >= 0 };
            };
        };

        private _ctxMarker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
        if (!(_ctxMarker isEqualType "")) then { _ctxMarker = ""; };

        private _ctxName = ["activeIncidentName", ""] call ARC_fnc_stateGet;
        if (!(_ctxName isEqualType "")) then { _ctxName = ""; };

        private _incidentContext = toUpper (format ["%1 %2 %3", _ctxMarker, _ctxName, _disp]);

        private _roleBundleId = switch (_typeU) do
        {
            case "LOGISTICS":
            {
                if ((_incidentContext find "HEADQUARTERS") >= 0 || { (_incidentContext find "TOC") >= 0 }) exitWith { "LOGI_HEADQUARTERS" };
                if ((_incidentContext find "MP") >= 0 || { (_incidentContext find "MILITARY POLICE") >= 0 }) exitWith { "LOGI_MPS" };
                if (((_incidentContext find "1-73") >= 0) || { ((_incidentContext find "173") >= 0) && { (_incidentContext find "CAV") >= 0 } }) exitWith { "LOGI_1_73_CAV" };
                if ((_incidentContext find "CONVOY SECURITY") >= 0 || { (_incidentContext find "SHIPMENT SECURITY") >= 0 }) exitWith { "LOGI_CONVOY_SECURITY" };
                if ((_incidentContext find "TRANSPORT") >= 0 || { (_incidentContext find "RESUPPLY") >= 0 }) exitWith { "LOGI_TRANSPORT" };
                if ((_incidentContext find "MEDICAL") >= 0 || { (_incidentContext find "CASUALTY") >= 0 }) exitWith { "LOGI_MEDICAL" };
                if ((_incidentContext find "AMMO") >= 0 || { (_incidentContext find "MUNITION") >= 0 }) exitWith { "LOGI_AMMO" };
                if ((_incidentContext find "REPAIR") >= 0 || { (_incidentContext find "ENGINEERING") >= 0 }) exitWith { "LOGI_REPAIR" };
                if ((_incidentContext find "FUEL") >= 0) exitWith { "LOGI_FUEL" };

                switch (_supplyKind) do
                {
                    case "FUEL": { "LOGI_FUEL" };
                    case "AMMO": { "LOGI_AMMO" };
                    case "MED":  { "LOGI_MEDICAL" };
                    default        { "LOGI_TRANSPORT" };
                };
            };
            case "ESCORT":
            {
                if ((_incidentContext find "MINE SECURITY CONTRACTOR") >= 0 || { (_incidentContext find "PRIVATE CONTRACTOR") >= 0 }) exitWith { "LOGI_CONTRACTOR_SECURITY" };
                if ((_incidentContext find "PRIVATE SECURITY") >= 0 || { (_incidentContext find "PMC") >= 0 }) exitWith { "LOGI_PRIVATE_SECURITY" };
                if ((_incidentContext find "GOVERNMENT") >= 0 || { (_incidentContext find "PRESIDENT") >= 0 } || { (_incidentContext find "DIPLOMATIC") >= 0 }) exitWith { "LOGI_GOVERNMENT" };
                if (_isVipEscort) exitWith { "ESCORT_VIP" };
                "ESCORT_STANDARD"
            };
            default { "CONVOY_GENERIC" };
        };

        private _rolePlan = [
            ["incidentType", _typeU],
            ["bundleId", _roleBundleId],
            ["supplyKind", _supplyKind],
            ["vipEscort", _isVipEscort],
            ["leadRole", "lead"],
            ["escortRole", "escort"],
            ["logisticsRole", "logistics"]
        ];

        ["activeConvoySupplyKind", _supplyKind] call ARC_fnc_stateSet;
        ["activeConvoyRolePlan", _rolePlan] call ARC_fnc_stateSet;

        // Convoy spawn is handled by execTickConvoy (async) so we can spawn sequentially
        // without stalling the exec loop (and to prevent duplicate spawns).
        ["activeConvoyNetIds", []] call ARC_fnc_stateSet;
        ["activeConvoySpawning", false] call ARC_fnc_stateSet;
        ["activeConvoySpawningSince", -1] call ARC_fnc_stateSet;

        // Preserve the planned speed (execSpawnConvoy may still adjust this when it spawns).
        ["activeConvoySpeedKph", _speedKph] call ARC_fnc_stateSet;
        ["activeConvoyDetectedAt", -1] call ARC_fnc_stateSet;
        ["activeConvoyDepartAt", -1] call ARC_fnc_stateSet;
        ["activeConvoyLastMoveAt", -1] call ARC_fnc_stateSet;
        ["activeConvoyLastMovePos", _spawnPos] call ARC_fnc_stateSet;
        ["activeConvoyLastRecoveryAt", -1] call ARC_fnc_stateSet;
        ["activeConvoyBypassUntil", -1] call ARC_fnc_stateSet;

        // Convoy missions use their own start trigger (near convoy). Don't auto-activate here.
        ["activeExecActivated", false] call ARC_fnc_stateSet;
        ["activeExecActivatedAt", -1] call ARC_fnc_stateSet;
    };

    // Route support elements (Thunder/TNP/Sheriff at intersections)
    // Spawn on acceptance (not assignment). Persist behavior mirrors checkpoint compositions.
    if (_accepted) then
    {
        private _rsSpawned = ["activeRouteSupportSpawned", false] call ARC_fnc_stateGet;
        if (!(_rsSpawned isEqualType true)) then { _rsSpawned = false; };

        private _rsTaskId = ["activeRouteSupportTaskId", ""] call ARC_fnc_stateGet;
        if (!(_rsTaskId isEqualType "")) then { _rsTaskId = ""; };

        // Re-spawn only when this is a new task package (or state was wiped).
        if (!_rsSpawned || { !(_rsTaskId isEqualTo _taskId) }) then
        {
            private _kNow = ["activeExecKind", ""] call ARC_fnc_stateGet;
            if (!(_kNow isEqualType "")) then { _kNow = ""; };

            private _rp = [];
            if ((toUpper _kNow) isEqualTo "CONVOY") then
            {
                _rp = ["activeConvoyRoutePoints", []] call ARC_fnc_stateGet;
                if (!(_rp isEqualType [])) then { _rp = []; };
            };

            // If the accepting group is already on/near the objective, do not spawn route support again.
            // This prevents "stacking" support elements when a follow-on lead spawns in the same AO.
            private _skipNearM = missionNamespace getVariable ["ARC_routeSupportSkipIfGroupNearObjectiveM", 500];
            if (!(_skipNearM isEqualType 0) || { _skipNearM < 0 }) then { _skipNearM = 500; };
            _skipNearM = (_skipNearM max 0) min 2000;

            private _skipRouteSupport = false;

            // IED incidents must spawn route support (cordon) even if the accepting group is already on-scene.
            if (_typeU isEqualTo "IED") then { _skipRouteSupport = false; _skipNearM = 0; };

            if (_skipNearM > 0) then
            {
                private _accGid = ["activeIncidentAcceptedByGroup", ""] call ARC_fnc_stateGet;
                if (_accGid isEqualType "" && { !(_accGid isEqualTo "") }) then
                {
                    {
                        if (!isNull _x && { (groupId (group _x)) isEqualTo _accGid } && { (_x distance2D _pos) <= _skipNearM }) exitWith
                        {
                            _skipRouteSupport = true;
                        };
                    } forEach allPlayers;
                };
            };

            diag_log format ["[ARC][RouteSupport] Decision | taskId=%1 type=%2 skip=%3 nearM=%4", _taskId, _typeU, _skipRouteSupport, round _skipNearM];

            if (_skipRouteSupport) then
            {
                diag_log format ["[ARC][RouteSupport] Skipping route support spawn (group already within %1m of objective).", round _skipNearM];
                ["activeRouteSupportNetIds", []] call ARC_fnc_stateSet;
                ["activeRouteSupportSpawned", true] call ARC_fnc_stateSet;
                ["activeRouteSupportTaskId", _taskId] call ARC_fnc_stateSet;
            }
            else
            {
                private _rsNids = [];
                _rsNids = [_taskId, _typeU, _m, _disp, _pos, _radius, _rp] call ARC_fnc_opsSpawnRouteSupport;
                if (!(_rsNids isEqualType [])) then { _rsNids = []; };

                ["activeRouteSupportNetIds", _rsNids] call ARC_fnc_stateSet;
                ["activeRouteSupportSpawned", true] call ARC_fnc_stateSet;
                ["activeRouteSupportTaskId", _taskId] call ARC_fnc_stateSet;
            };
        };
    };

    // Useful for server-side dt
    missionNamespace setVariable ["ARC_exec_lastTick", serverTime];

    // Broadcast minimal exec state to clients (timers / situational awareness HUDs).
    // These are mirrors of authoritative state values.
    missionNamespace setVariable ["ARC_activeExecKind", ["activeExecKind", "NONE"] call ARC_fnc_stateGet, true];
    missionNamespace setVariable ["ARC_activeExecPos", ["activeExecPos", []] call ARC_fnc_stateGet, true];
    missionNamespace setVariable ["ARC_activeExecRadius", ["activeExecRadius", 0] call ARC_fnc_stateGet, true];
    missionNamespace setVariable ["ARC_activeExecStartedAt", ["activeExecStartedAt", -1] call ARC_fnc_stateGet, true];
    missionNamespace setVariable ["ARC_activeExecDeadlineAt", ["activeExecDeadlineAt", -1] call ARC_fnc_stateGet, true];
    missionNamespace setVariable ["ARC_activeExecArrivalReq", ["activeExecArrivalReq", 0] call ARC_fnc_stateGet, true];
    missionNamespace setVariable ["ARC_activeExecArrived", ["activeExecArrived", false] call ARC_fnc_stateGet, true];
    missionNamespace setVariable ["ARC_activeExecHoldReq", ["activeExecHoldReq", 0] call ARC_fnc_stateGet, true];
    missionNamespace setVariable ["ARC_activeExecHoldAccum", ["activeExecHoldAccum", 0] call ARC_fnc_stateGet, true];
    missionNamespace setVariable ["ARC_activeExecActivated", ["activeExecActivated", false] call ARC_fnc_stateGet, true];

    // Refresh task description so players see the end-state criteria
    [] call ARC_fnc_taskUpdateActiveDescription;
};

// If an objective should exist but is missing (restart cleanup), rebuild.
private _ok = true;
private _kindNow = ["activeExecKind", ""] call ARC_fnc_stateGet;
private _objKindNow = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
if (_kindNow isEqualTo "INTERACT" && { !(_objKindNow isEqualTo "") }) then
{
    private _nid = ["activeObjectiveNetId", ""] call ARC_fnc_stateGet;
    if (!(_nid isEqualTo "")) then
    {
        private _obj = objectFromNetId _nid;
        if (isNull _obj) then
        {
            // Rebuild the full package.
            ["activeExecTaskId", ""] call ARC_fnc_stateSet;
            _ok = [] call ARC_fnc_execInitActive;
        };
    };
};

// ROUTE_RECON: after restarts, the parent task may be rehydrated but child tasks do not exist.
// Ensure the start/end child tasks are present and restore their states from ARC_state.
if (_kindNow isEqualTo "ROUTE_RECON") then
{
    private _acceptedNow = ["activeIncidentAccepted", false] call ARC_fnc_stateGet;
    if (!(_acceptedNow isEqualType true)) then { _acceptedNow = false; };

    if (_acceptedNow) then
    {
        private _startTaskId = ["activeReconRouteStartTaskId", ""] call ARC_fnc_stateGet;
        private _endTaskId   = ["activeReconRouteEndTaskId", ""] call ARC_fnc_stateGet;
        private _startPos    = ["activeReconRouteStartPos", []] call ARC_fnc_stateGet;
        private _endPos      = ["activeReconRouteEndPos", []] call ARC_fnc_stateGet;

        private _startReached = ["activeReconRouteStartReached", false] call ARC_fnc_stateGet;
        if (!(_startReached isEqualType true)) then { _startReached = false; };

        private _endReached = ["activeReconRouteEndReached", false] call ARC_fnc_stateGet;
        if (!(_endReached isEqualType true)) then { _endReached = false; };

        if (!(_startTaskId isEqualTo "") && { !([_startTaskId] call BIS_fnc_taskExists) } && { _startPos isEqualType [] && { (count _startPos) >= 2 } }) then
        {
            private _tS = "Route Recon Start";
            private _dS = "Proceed to the route start point. Once on-site, begin route reconnaissance toward the end point.";
            [true, [_startTaskId, _taskId], [_dS, _tS, ""], _startPos, "ASSIGNED", 1, true, "MOVE", false] call BIS_fnc_taskCreate;
        };

        if (!(_endTaskId isEqualTo "") && { !([_endTaskId] call BIS_fnc_taskExists) } && { _endPos isEqualType [] && { (count _endPos) >= 2 } }) then
        {
            private _tE = "Route Recon End";
            private _dE = "Move along the route to the end point while observing and reporting. Avoid decisive engagement when possible.";
            [true, [_endTaskId, _taskId], [_dE, _tE, ""], _endPos, "CREATED", 1, false, "MOVE", false] call BIS_fnc_taskCreate;
        };

        // Restore child task states (start always assigned until reached; end stays created until start reached).
        if (!(_startTaskId isEqualTo "")) then
        {
            private _stS = if (_startReached) then { "SUCCEEDED" } else { "ASSIGNED" };
            [_startTaskId, _stS, true] call BIS_fnc_taskSetState;
        };

        if (!(_endTaskId isEqualTo "")) then
        {
            private _stE = "CREATED";
            if (_endReached) then
            {
                _stE = "SUCCEEDED";
            }
            else
            {
                if (_startReached) then { _stE = "ASSIGNED"; };
            };
            [_endTaskId, _stE, true] call BIS_fnc_taskSetState;
        };

	        // Ensure the correct child task remains "current" after persistence rehydration.
	        // Current task is local per-client, so broadcast the selection.
	        private _cur = "";
	        if (!_startReached) then
	        {
	            _cur = _startTaskId;
	        }
	        else
	        {
	            if (!_endReached) then { _cur = _endTaskId; };
	        };

	        if (!(_cur isEqualTo "")) then
	        {
	            [_cur] remoteExecCall ["ARC_fnc_clientSetCurrentTask", 0];
	        };
    };
};

_ok
