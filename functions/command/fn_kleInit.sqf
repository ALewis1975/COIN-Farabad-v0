/*
    ARC_fnc_kleInit

    Server-side: initialize a Key Leader Engagement (KLE) task.

    Called when a KLE incident is created by ARC_fnc_incidentCreate. Spawns
    a named elder NPC at the task position, adds an ACE interaction menu, and
    starts a session-watch tick. When the player element completes the engagement
    (proximity + time threshold) the server applies the outcome influence delta.

    Params:
      0: STRING - taskId (the active incident task ID)
      1: ARRAY  - posATL [x,y,z]
      2: STRING - displayName (incident display name, for log/context)

    State keys written (server-local, no broadcast):
      kle_v0_active          - BOOL
      kle_v0_taskId          - STRING
      kle_v0_elderNetId      - STRING (netId of spawned NPC)
      kle_v0_startTs         - NUMBER (serverTime)
      kle_v0_completedTs     - NUMBER (-1 until complete)
      kle_v0_outcome         - STRING ("SUCCESS"|"FAIL"|"")

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

params [
    ["_taskId", "", [""]],
    ["_pos",    [], [[]]],
    ["_disp",   "", [""]]
];

if (_taskId isEqualTo "") exitWith {false};
if (_pos isEqualTo [] || { (count _pos) < 2 }) exitWith {false};
_pos resize 3;

// Idempotent
if (missionNamespace getVariable ["kle_v0_active", false]) exitWith
{
    diag_log "[ARC][KLE] kleInit: a KLE task is already active — skipping duplicate init.";
    false
};

missionNamespace setVariable ["kle_v0_active",       true];
missionNamespace setVariable ["kle_v0_taskId",       _taskId];
missionNamespace setVariable ["kle_v0_startTs",      serverTime];
missionNamespace setVariable ["kle_v0_completedTs",  -1];
missionNamespace setVariable ["kle_v0_outcome",      ""];
missionNamespace setVariable ["kle_v0_elderNetId",   ""];

// Engagement parameters
private _engageTimeS   = missionNamespace getVariable ["ARC_kleEngageDurationS",   300];  // 5 min dwell
private _proxRadiusM   = missionNamespace getVariable ["ARC_kleProximityM",          75];
private _influenceDelta = missionNamespace getVariable ["ARC_kleInfluenceDelta",    0.06]; // GREEN/WHITE delta on success
if (!(_engageTimeS    isEqualType 0)) then { _engageTimeS    = 300; };
if (!(_proxRadiusM    isEqualType 0)) then { _proxRadiusM    = 75; };
if (!(_influenceDelta isEqualType 0)) then { _influenceDelta = 0.06; };
_engageTimeS    = (_engageTimeS    max 60)  min 1800;
_proxRadiusM    = (_proxRadiusM    max 20)  min 300;
_influenceDelta = (_influenceDelta max 0.01) min 0.20;

// Spawn elder NPC
private _elderClasses = ["C_man_1", "C_man_polo_1_F", "C_man_polo_4_F", "C_man_polo_6_F"];
private _elderClass = _elderClasses select (floor (random (count _elderClasses)));
private _elderGrp   = createGroup [civilian, true];
_elderGrp setGroupIdGlobal [format ["KLE Elder %1", _taskId]];
private _elder      = _elderGrp createUnit [_elderClass, _pos, [], 2, "NONE"];

if (isNull _elder) exitWith
{
    diag_log format ["[ARC][KLE][WARN] kleInit: failed to spawn elder NPC at %1.", mapGridPosition _pos];
    missionNamespace setVariable ["kle_v0_active", false];
    false
};

_elder setVariable ["ARC_kleElder", true, true];
_elder setVariable ["ARC_kleTaskId", _taskId, true];
_elder allowDamage false;
_elder disableAI "AUTOTARGET";
_elder disableAI "TARGET";
_elder disableAI "MOVE";

// Name the elder for realism
private _elderNames = ["Elder Hassan", "Elder Malik", "Elder Farid", "Elder Yusuf", "Elder Karim"];
private _elderName  = _elderNames select (floor (random (count _elderNames)));
_elder setName _elderName;

private _elderNid = netId _elder;
missionNamespace setVariable ["kle_v0_elderNetId", _elderNid, true];

diag_log format ["[ARC][KLE] kleInit: elder '%1' spawned at %2 (taskId=%3).", _elderName, mapGridPosition _pos, _taskId];

// ── KLE engagement monitor (spawned loop) ──────────────────────────────────
[_taskId, _pos, _proxRadiusM, _engageTimeS, _influenceDelta, _elderNid, _elderName] spawn
{
    params ["_taskId", "_pos", "_proxRadiusM", "_engageTimeS", "_influenceDelta", "_elderNid", "_elderName"];

    private _startTs = serverTime;
    private _dwellAccum = 0;
    private _completed = false;

    while { !_completed && { missionNamespace getVariable ["kle_v0_active", false] } } do
    {
        sleep 5;

        // Check if the task is still active
        private _activeTask = ["activeTaskId", ""] call ARC_fnc_stateGet;
        if (!(_activeTask isEqualTo _taskId)) exitWith
        {
            diag_log format ["[ARC][KLE] kleWatch: task=%1 no longer active — KLE aborted.", _taskId];
            missionNamespace setVariable ["kle_v0_active",     false];
            missionNamespace setVariable ["kle_v0_outcome",    "FAIL"];
            missionNamespace setVariable ["kle_v0_completedTs", serverTime];
        };

        // Count BLUFOR players within engagement radius
        private _near = _pos nearEntities [["Man"], _proxRadiusM];
        private _bluforNear = count (_near select { side (group _x) isEqualTo west && { isPlayer _x } });

        if (_bluforNear > 0) then { _dwellAccum = _dwellAccum + 5; };

        // Success: enough dwell time accumulated
        if (_dwellAccum >= _engageTimeS) then
        {
            _completed = true;
            missionNamespace setVariable ["kle_v0_outcome",    "SUCCESS"];
            missionNamespace setVariable ["kle_v0_completedTs", serverTime];
            missionNamespace setVariable ["kle_v0_active",     false];

            // Apply WHITE/GREEN influence delta via CIVSUB
            if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
            {
                private _districtId = "";
                if (!isNil "ARC_fnc_civsubDistrictsFindByPos") then
                {
                    private _dr = [_pos] call ARC_fnc_civsubDistrictsFindByPos;
                    if (_dr isEqualType [] && { (count _dr) >= 1 }) then { _districtId = _dr select 0; };
                };

                if (!(_districtId isEqualTo "")) then
                {
                    private _bundle = createHashMap;
                    _bundle set ["districtId",     _districtId];
                    _bundle set ["source",         createHashMap];
                    (_bundle get "source") set ["event", "KLE_SUCCESS"];
                    _bundle set ["G_delta",  _influenceDelta];
                    _bundle set ["W_delta",  _influenceDelta * 0.5];
                    _bundle set ["R_delta",  -(_influenceDelta * 0.3)];

                    [_bundle, _districtId] call ARC_fnc_civsubDeltaApplyToDistrict;
                    diag_log format ["[ARC][KLE] kleWatch: SUCCESS delta applied to district=%1 G+=%2 W+=%3.", _districtId, _influenceDelta, _influenceDelta * 0.5];
                };
            };

            // Emit a HUMINT lead
            if (!isNil "ARC_fnc_leadCreate") then
            {
                private _leadId = ["RECON", format ["KLE HUMINT — Elder %1 tip.", _elderName], _pos, 0.55, 3600, _taskId, "KLE", "", "HUMINT"] call ARC_fnc_leadCreate;
                diag_log format ["[ARC][KLE] kleWatch: HUMINT lead=%1 emitted.", _leadId];
            };

            // Intel log
            if (!isNil "ARC_fnc_intelLog") then
            {
                ["HUMINT", format ["KLE SUCCESS: Elder %1 engagement complete. HUMINT lead generated.", _elderName], _pos, [["event","KLE_SUCCESS"],["taskId",_taskId],["elder",_elderName]]] call ARC_fnc_intelLog;
            };

            // Mark task ready to close
            ["activeIncidentCloseReady", true] call ARC_fnc_stateSet;
            missionNamespace setVariable ["ARC_activeIncidentCloseReady", true, true];

            diag_log format ["[ARC][KLE] kleWatch: SUCCESS — taskId=%1 elder=%2 dwell=%3s.", _taskId, _elderName, _dwellAccum];
        };
    };
};

true
