/*
    ARC_fnc_civsubCivBuildClassPool

    Build/caches a civilian unit classname pool for CIVSUB physical spawning.

    Priority order:
      1) missionNamespace override civsub_v1_civ_classPool (explicit list)
      2) known 3CB Takistan Civilians list if preferred faction is UK3CB_TKC_C
      3) config scan for preferred faction
      4) config scan for any UK3CB civilian man classes
      5) vanilla fallback

    Cache is keyed by preferred faction (or EXPLICIT/KNOWN/ANY3CB/FALLBACK) to avoid stale pools.
*/

private _explicit = missionNamespace getVariable ["civsub_v1_civ_classPool", []];
if (_explicit isEqualType [] && {count _explicit > 0}) exitWith {
    missionNamespace setVariable ["civsub_v1_civ_classPool_cached", _explicit, true];
    missionNamespace setVariable ["civsub_v1_civ_classPool_cached_key", "EXPLICIT", true];
    _explicit
};

private _preferredFaction = missionNamespace getVariable ["civsub_v1_civ_preferredFaction", "UK3CB_TKC_C"]; 
private _forceRebuild = missionNamespace getVariable ["civsub_v1_civ_classPool_forceRebuild", false];

private _cached = missionNamespace getVariable ["civsub_v1_civ_classPool_cached", []];
private _cachedKey = missionNamespace getVariable ["civsub_v1_civ_classPool_cached_key", ""]; 
if (!_forceRebuild && {_cached isEqualType [] && {count _cached > 0} && {_cachedKey == _preferredFaction}}) exitWith { _cached };

// 2) Known 3CB Takistan Civilians list (bypasses fragile side/scope assumptions)
if (_preferredFaction == "UK3CB_TKC_C") then {
    private _known = [
        "UK3CB_TKC_C_CIV",
        "UK3CB_TKC_C_DOC",
        "UK3CB_TKC_C_PILOT",
        "UK3CB_TKC_C_SPOT",
        "UK3CB_TKC_C_WORKER"
    ];

    private _poolKnown = _known select { isClass (configFile >> "CfgVehicles" >> _x) };
    if ((count _poolKnown) > 0) exitWith {
        missionNamespace setVariable ["civsub_v1_civ_classPool_cached", _poolKnown, true];
        missionNamespace setVariable ["civsub_v1_civ_classPool_cached_key", _preferredFaction, true];
        _poolKnown
    };
};

// 3/4) Scan configs
private _poolPreferred = [];
private _poolAny3cb = [];

private _cfg = configFile >> "CfgVehicles";
{
    // keep it cheap; only public units
    if (getNumber (_x >> "scope") == 2) then {
        private _cn = configName _x;
        if (_cn isKindOf "Man") then {
            private _f = getText (_x >> "faction");
            if (_f == _preferredFaction) then {
                _poolPreferred pushBack _cn;
            } else {
                // UK3CB civilian factions generally start with UK3CB_
                if ((_f find "UK3CB_") == 0) then {
                    _poolAny3cb pushBack _cn;
                };
            };
        };
    };
} forEach ("true" configClasses _cfg);

private _pool = [];
private _key = _preferredFaction;
if ((count _poolPreferred) > 0) then {
    _pool = _poolPreferred;
} else {
    if ((count _poolAny3cb) > 0) then {
        _pool = _poolAny3cb;
        _key = "ANY3CB";
    } else {
        _pool = ["C_Man_casual_2_F","C_Man_casual_1_F","C_man_1"];
        _key = "FALLBACK";
    };
};

missionNamespace setVariable ["civsub_v1_civ_classPool_cached", _pool, true];
missionNamespace setVariable ["civsub_v1_civ_classPool_cached_key", _key, true];
_pool
