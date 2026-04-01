/*
    ARC_fnc_threatVirtualPoolTick

    Server-only. Starts (or no-ops if already running) the virtual OpFor group pool
    management loop.

    Tick cadence: ARC_threatVirtualPoolTickS (default 60 s).

    Each tick processes all records in threat_v0_records where type == "VIRTUAL_OPFOR":

        VIRTUAL_DORMANT
            If any player is within ARC_threatVirtualActivationRadiusM (default 600 m)
            of the group position → transition to VIRTUAL_ACTIVE.
            If lastMoved timestamp is older than ARC_threatVirtualRepositionS
            (default 600 s) → offset position by a small random delta to simulate
            insurgent patrol drift.

        VIRTUAL_ACTIVE
            If no player is within ARC_threatVirtualActivationRadiusM → revert to
            VIRTUAL_DORMANT.
            If a player is within ARC_threatVirtualSpawnRadiusM (default 400 m) AND
            there is an active incident in a non-Airbase/GreenZone area → physically
            spawn the group and transition to PHYSICAL.

        PHYSICAL
            Track "last player nearby" timestamp.
            If all spawned units are dead or deleted → clean up, transition to
            VIRTUAL_DORMANT.
            If no player within ARC_threatVirtualDespawnRadiusM (default 700 m) for
            ARC_threatVirtualDespawnDelayS (default 90 s) → delete group, transition
            to VIRTUAL_DORMANT.

    Returns: BOOL (true if loop started, false if already running)
*/

if (!isServer) exitWith {false};

if (!isNil { missionNamespace getVariable "ARC_virtualPoolLoopRunning" }) exitWith {
    diag_log "[ARC][VPOOL][INFO] ARC_fnc_threatVirtualPoolTick: loop already running — no-op.";
    false
};

missionNamespace setVariable ["ARC_virtualPoolLoopRunning", true];

diag_log "[ARC][VPOOL][INFO] ARC_fnc_threatVirtualPoolTick: loop started.";

[] spawn {

    private _tickS = missionNamespace getVariable ["ARC_threatVirtualPoolTickS", 60];
    if (!(_tickS isEqualType 0) || {_tickS < 10}) then { _tickS = 60; };

    while {true} do {

        sleep _tickS;

        if (!isServer) exitWith {};
        if (!(missionNamespace getVariable ["ARC_serverReady", false])) then { continue; };

        private _enabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
        if (!(_enabled isEqualType true) && !(_enabled isEqualType false)) then { _enabled = true; };
        if (!_enabled) then { continue; };

        // Configuration
        private _activationR = missionNamespace getVariable ["ARC_threatVirtualActivationRadiusM", 600];
        if (!(_activationR isEqualType 0)) then { _activationR = 600; };
        _activationR = (_activationR max 100) min 2000;

        private _spawnR = missionNamespace getVariable ["ARC_threatVirtualSpawnRadiusM", 400];
        if (!(_spawnR isEqualType 0)) then { _spawnR = 400; };
        _spawnR = (_spawnR max 50) min 1000;

        private _despawnR = missionNamespace getVariable ["ARC_threatVirtualDespawnRadiusM", 700];
        if (!(_despawnR isEqualType 0)) then { _despawnR = 700; };
        _despawnR = (_despawnR max 100) min 3000;

        private _despawnDelayS = missionNamespace getVariable ["ARC_threatVirtualDespawnDelayS", 90];
        if (!(_despawnDelayS isEqualType 0)) then { _despawnDelayS = 90; };
        _despawnDelayS = (_despawnDelayS max 10) min 600;

        private _repositionS = missionNamespace getVariable ["ARC_threatVirtualRepositionS", 600];
        if (!(_repositionS isEqualType 0)) then { _repositionS = 600; };
        _repositionS = (_repositionS max 60) min 3600;

        // Determine active incident zone (for spawn gating)
        private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
        if (!(_activeTaskId isEqualType "")) then { _activeTaskId = ""; };
        private _activeMarker = ["activeIncidentMarker", ""] call ARC_fnc_stateGet;
        if (!(_activeMarker isEqualType "")) then { _activeMarker = ""; };

        private _activeIncidentZone = "";
        if (!(_activeMarker isEqualTo "")) then {
            private _mPos = getMarkerPos _activeMarker;
            if (_mPos isEqualType [] && {(count _mPos) >= 2}) then {
                _activeIncidentZone = [_mPos] call ARC_fnc_worldGetZoneForPos;
            };
        };

        // Unit class fallback
        private _unitClasses = missionNamespace getVariable ["ARC_opforPatrolUnitClasses", []];
        if (!(_unitClasses isEqualType []) || {(count _unitClasses) == 0}) then {
            _unitClasses = ["O_G_Soldier_F", "O_G_Soldier_GL_F", "O_G_Soldier_AR_F", "O_G_medic_F", "O_G_Soldier_TL_F"];
        };

        // Get current alive players (server poll)
        private _alivePlayers = allPlayers select { alive _x };

        // Load records
        private _records = ["threat_v0_records", []] call ARC_fnc_stateGet;
        if (!(_records isEqualType [])) then { _records = []; };

        private _activeVgIndex = ["threat_v0_vgroup_active_index", []] call ARC_fnc_stateGet;
        if (!(_activeVgIndex isEqualType [])) then { _activeVgIndex = []; };

        private _dirty      = false;
        private _now        = serverTime;

        // Helpers for pairs-array read/write (using select for sqflint compat)
        private _kvGet = {
            params ["_pairs", "_key", "_default"];
            if (!(_pairs isEqualType [])) exitWith {_default};
            private _val = _default;
            { if (_x isEqualType [] && {(count _x) >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _val = _x select 1; }; } forEach _pairs;
            _val
        };

        private _kvSet = {
            params ["_pairs", "_key", "_value"];
            if (!(_pairs isEqualType [])) then { _pairs = []; };
            private _idx = -1;
            { if (_x isEqualType [] && {(count _x) >= 2} && {(_x select 0) isEqualTo _key}) exitWith { _idx = _forEachIndex; }; } forEach _pairs;
            if (_idx < 0) then { _pairs pushBack [_key, _value]; } else { _pairs set [_idx, [_key, _value]]; };
            _pairs
        };

        {
            private _rec = _x;
            private _ri  = _forEachIndex;

            // Only process VIRTUAL_OPFOR records
            if (!([_rec, "type", ""] call _kvGet) isEqualTo "VIRTUAL_OPFOR") then { continue; };

            private _state     = [_rec, "state",   "VIRTUAL_DORMANT"] call _kvGet;
            private _vgId      = [_rec, "vgroup_id", ""]              call _kvGet;
            private _vgPos     = [_rec, "pos",        [0,0,0]]        call _kvGet;
            private _strength  = [_rec, "strength",   3]              call _kvGet;
            private _lastMoved = [_rec, "lastMoved",  0]              call _kvGet;
            private _lastNear  = [_rec, "lastPlayerNearTs", -1]       call _kvGet;
            private _spawnedU  = [_rec, "spawnedUnits", []]           call _kvGet;

            if (!(_vgPos isEqualType []) || {(count _vgPos) < 2}) then { continue; };

            // Nearest player distance
            private _nearestPlayerD = 1e12;
            {
                if (_x distance2D _vgPos < _nearestPlayerD) then {
                    _nearestPlayerD = _x distance2D _vgPos;
                };
            } forEach _alivePlayers;

            private _playerNearby      = (_nearestPlayerD <= _activationR);
            private _playerVeryNearby  = (_nearestPlayerD <= _spawnR);
            private _playerFar         = (_nearestPlayerD > _despawnR);

            switch (_state) do {

                // ------------------------------------------------------------------
                case "VIRTUAL_DORMANT":
                {
                    if (_playerNearby) then {
                        _rec    = [_rec, "state", "VIRTUAL_ACTIVE"] call _kvSet;
                        _dirty  = true;
                        diag_log format ["[ARC][VPOOL][INFO] %1 activated (dist=%2 m)", _vgId, round _nearestPlayerD];
                    } else {
                        // Drift patrol: offset position when stale
                        if ((_now - _lastMoved) > _repositionS) then {
                            private _driftX = random 200 - 100;
                            private _driftY = random 200 - 100;
                            private _newPos = [(_vgPos select 0) + _driftX, (_vgPos select 1) + _driftY, 0];
                            _rec   = [_rec, "pos",       _newPos] call _kvSet;
                            _rec   = [_rec, "lastMoved", _now]    call _kvSet;
                            _dirty = true;
                        };
                    };
                };

                // ------------------------------------------------------------------
                case "VIRTUAL_ACTIVE":
                {
                    if (!_playerNearby) then {
                        // Player left activation radius — revert
                        _rec   = [_rec, "state", "VIRTUAL_DORMANT"] call _kvSet;
                        _dirty = true;
                        diag_log format ["[ARC][VPOOL][INFO] %1 reverted to DORMANT (dist=%2 m)", _vgId, round _nearestPlayerD];
                    } else {
                        // Spawn gate: player very nearby AND there is an active combat incident
                        private _combatIncidentActive = !((_activeTaskId isEqualTo "") || {_activeIncidentZone in ["Airbase", "GreenZone", ""]});
                        if (_playerVeryNearby && { _combatIncidentActive }) then {
                            // Physically spawn group
                            private _spawnPos          = _vgPos;
                            private _vgPatrolRadiusM   = missionNamespace getVariable ["ARC_threatVirtualPatrolRadiusM", 200];
                            if (!(_vgPatrolRadiusM isEqualType 0)) then { _vgPatrolRadiusM = 200; };
                            _vgPatrolRadiusM = (_vgPatrolRadiusM max 50) min 600;

                            private _vgPatrolWaypointN = missionNamespace getVariable ["ARC_threatVirtualPatrolWaypointN", 5];
                            if (!(_vgPatrolWaypointN isEqualType 0)) then { _vgPatrolWaypointN = 5; };
                            _vgPatrolWaypointN = (_vgPatrolWaypointN max 3) min 10;

                            private _grp           = createGroup east;
                            private _spawnedNetIds = [];

                            for "_i" from 1 to _strength do {
                                private _cls = selectRandom _unitClasses;
                                private _u   = _grp createUnit [_cls, _spawnPos, [], 10, "NONE"];
                                _u setSkill (0.35 + random 0.25);
                                _spawnedNetIds pushBack (netId _u);
                            };

                            // Simple patrol task
                            if (!isNil "CBA_fnc_taskPatrol") then {
                                [_grp, _spawnPos, _vgPatrolRadiusM, _vgPatrolWaypointN, "MOVE", "AWARE", "YELLOW", "LIMITED", "STAG COLUMN"] call CBA_fnc_taskPatrol;
                            } else {
                                for "_w" from 1 to _vgPatrolWaypointN do {
                                    private _ang   = random 360;
                                    private _dist  = 50 + random _vgPatrolRadiusM;
                                    private _wpPos = [(_spawnPos select 0) + (sin _ang) * _dist, (_spawnPos select 1) + (cos _ang) * _dist, 0];
                                    private _wp    = _grp addWaypoint [_wpPos, 0];
                                    _wp setWaypointType "MOVE";
                                    _wp setWaypointBehaviour "AWARE";
                                    _wp setWaypointCombatMode "YELLOW";
                                    _wp setWaypointSpeed "LIMITED";
                                };
                                private _wpC = _grp addWaypoint [_spawnPos, 0];
                                _wpC setWaypointType "CYCLE";
                            };

                            _rec   = [_rec, "state",          "PHYSICAL"]       call _kvSet;
                            _rec   = [_rec, "spawnedUnits",   _spawnedNetIds]   call _kvSet;
                            _rec   = [_rec, "lastPlayerNearTs", _now]            call _kvSet;
                            _dirty = true;

                            _activeVgIndex pushBackUnique _vgId;

                            diag_log format ["[ARC][VPOOL][INFO] %1 spawned PHYSICAL (%2 units) at %3", _vgId, _strength, _spawnPos];
                        };
                    };
                };

                // ------------------------------------------------------------------
                case "PHYSICAL":
                {
                    // Validate spawned units
                    private _liveNetIds = [];
                    {
                        private _u = objectFromNetId _x;
                        if (!isNull _u && { alive _u }) then { _liveNetIds pushBack _x; };
                    } forEach _spawnedU;

                    if ((count _liveNetIds) == 0) then {
                        // All units dead/deleted — clean up
                        _rec   = [_rec, "state",        "VIRTUAL_DORMANT"] call _kvSet;
                        _rec   = [_rec, "spawnedUnits", []]                call _kvSet;
                        _dirty = true;
                        _activeVgIndex = _activeVgIndex - [_vgId];
                        diag_log format ["[ARC][VPOOL][INFO] %1 all units gone — reverted to DORMANT", _vgId];
                    } else {
                        // Update live unit list
                        if ((count _liveNetIds) != (count _spawnedU)) then {
                            _rec   = [_rec, "spawnedUnits", _liveNetIds] call _kvSet;
                            _dirty = true;
                        };

                        // Despawn if players have been out of range long enough
                        if (!_playerFar) then {
                            _rec   = [_rec, "lastPlayerNearTs", _now] call _kvSet;
                            _dirty = true;
                        } else {
                            if (_lastNear > 0 && { (_now - _lastNear) >= _despawnDelayS }) then {
                                // Despawn: delete all live units
                                {
                                    private _u = objectFromNetId _x;
                                    if (!isNull _u) then { deleteVehicle _u; };
                                } forEach _liveNetIds;

                                // Update position to last known group position
                                if ((count _liveNetIds) > 0) then {
                                    private _lastUnit = objectFromNetId (_liveNetIds select 0);
                                    if (!isNull _lastUnit) then {
                                        _rec = [_rec, "pos", getPosATL _lastUnit] call _kvSet;
                                    };
                                };

                                _rec   = [_rec, "state",          "VIRTUAL_DORMANT"] call _kvSet;
                                _rec   = [_rec, "spawnedUnits",   []]                call _kvSet;
                                _rec   = [_rec, "lastPlayerNearTs", -1]              call _kvSet;
                                _rec   = [_rec, "lastMoved",       _now]             call _kvSet;
                                _dirty = true;
                                _activeVgIndex = _activeVgIndex - [_vgId];

                                diag_log format ["[ARC][VPOOL][INFO] %1 despawned (no players for %2 s)", _vgId, _despawnDelayS];
                            };
                        };
                    };
                };
            };

            if (_dirty) then {
                _records set [_ri, _rec];
            };

        } forEach _records;

        if (_dirty) then {
            ["threat_v0_records",             _records]       call ARC_fnc_stateSet;
            ["threat_v0_vgroup_active_index",  _activeVgIndex] call ARC_fnc_stateSet;
        };
    };
};

true
