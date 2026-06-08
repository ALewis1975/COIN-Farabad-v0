/*
    ARC_fnc_runtimePolicyBuild

    Server-owned Runtime Boundary snapshot builder.

    Builds a compact, presentation-oriented runtime policy snapshot from current
    server facts. This is read-model data only: no subsystem consumes it for
    behavior in this PR.

    Returns: ARRAY of pairs
*/

if (!isServer) exitWith { [] };

private _playersRaw = allPlayers;
private _headlessClients = entities "HeadlessClient_F";
private _players = _playersRaw - _headlessClients;
private _alivePlayers = _players select { alive _x };

private _aiUnits = 0;
{
    if (!isPlayer _x) then { _aiUnits = _aiUnits + 1; };
} forEach allUnits;

private _allUnitsCount = count allUnits;
private _groupsCount = count allGroups;
private _vehiclesCount = count vehicles;
private _serverFps = diag_fps;

private _safeMode = missionNamespace getVariable ["ARC_safeModeEnabled", false];
if (!(_safeMode isEqualType true) && !(_safeMode isEqualType false)) then { _safeMode = false; };

private _serverMode = if (isDedicated) then { "DEDICATED" } else { "HOSTED" };

private _fpsBand = "OK";
if (_serverFps < 25) then { _fpsBand = "WARN"; };
if (_serverFps < 15) then { _fpsBand = "CRITICAL"; };

private _aiPressureBand = "LOW";
if (_aiUnits >= 120) then { _aiPressureBand = "MED"; };
if (_aiUnits >= 200) then { _aiPressureBand = "HIGH"; };

private _vehiclePressureBand = "LOW";
if (_vehiclesCount >= 80) then { _vehiclePressureBand = "MED"; };
if (_vehiclesCount >= 140) then { _vehiclePressureBand = "HIGH"; };

private _degradedMode = "NONE";
private _schedulerBudgetBand = "NORMAL";
if (_safeMode) then
{
    _degradedMode = "LOCKDOWN";
    _schedulerBudgetBand = "LOCKED";
}
else
{
    if ((_serverFps < 15) || { _aiUnits >= 220 } || { _vehiclesCount >= 180 }) then
    {
        _degradedMode = "HEAVY";
        _schedulerBudgetBand = "MINIMAL";
    }
    else
    {
        if ((_serverFps < 25) || { _aiUnits >= 140 } || { _vehiclesCount >= 120 } || { (count _players) >= 30 }) then
        {
            _degradedMode = "LIGHT";
            _schedulerBudgetBand = "REDUCED";
        };
    };
};

private _spawnPolicy = [
    ["civilian", _schedulerBudgetBand],
    ["traffic", _schedulerBudgetBand],
    ["airbaseAmbience", _schedulerBudgetBand],
    ["threatPhysical", _schedulerBudgetBand],
    ["sitePopulation", _schedulerBudgetBand],
    ["missionSpine", "PRESERVE"]
];

private _counts = [
    ["players", count _players],
    ["alivePlayers", count _alivePlayers],
    ["allPlayersRaw", count _playersRaw],
    ["headlessClients", count _headlessClients],
    ["aiUnits", _aiUnits],
    ["allUnits", _allUnitsCount],
    ["groups", _groupsCount],
    ["vehicles", _vehiclesCount]
];

private _bands = [
    ["serverFps", _fpsBand],
    ["aiPressure", _aiPressureBand],
    ["vehiclePressure", _vehiclePressureBand],
    ["schedulerBudget", _schedulerBudgetBand]
];

private _metrics = [
    ["serverFps", _serverFps],
    ["serverTime", serverTime]
];

private _cleanupPolicy = [
    ["mode", _schedulerBudgetBand],
    ["note", "diagnostic-only"]
];

private _notes = [];
if (_safeMode) then { _notes pushBack "safe_mode_enabled"; };
if (_fpsBand isEqualTo "CRITICAL") then { _notes pushBack "server_fps_critical"; };
if (_aiPressureBand isEqualTo "HIGH") then { _notes pushBack "ai_pressure_high"; };
if (_vehiclePressureBand isEqualTo "HIGH") then { _notes pushBack "vehicle_pressure_high"; };

[
    ["schema", "ARC_runtimePolicy_v1"],
    ["version", [1,0,0]],
    ["builtAtServerTime", serverTime],
    ["serverMode", _serverMode],
    ["safeMode", _safeMode],
    ["degradedMode", _degradedMode],
    ["playerCount", count _players],
    ["counts", _counts],
    ["bands", _bands],
    ["metrics", _metrics],
    ["spawnPolicy", _spawnPolicy],
    ["cleanupPolicy", _cleanupPolicy],
    ["jipPosture", "NORMAL"],
    ["notes", _notes]
]
