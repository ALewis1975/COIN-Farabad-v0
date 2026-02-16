/*
    Publish a small, JIP-safe "public state snapshot" into missionNamespace.

    Client UI (briefing / TOC screens) should NOT read ARC_state directly.
    Instead it should read these public variables which are designed for presentation.
*/

if (!isServer) exitWith {false};

private _p = ["insurgentPressure", 0.35] call ARC_fnc_stateGet;
private _c = ["corruption", 0.55] call ARC_fnc_stateGet;
private _i = ["infiltration", 0.35] call ARC_fnc_stateGet;

private _sent = ["civSentiment", 0.55] call ARC_fnc_stateGet;
private _leg  = ["govLegitimacy", 0.45] call ARC_fnc_stateGet;
private _cas  = ["civCasualties", 0] call ARC_fnc_stateGet;

private _fuel = ["baseFuel", 0.38] call ARC_fnc_stateGet;
private _ammo = ["baseAmmo", 0.32] call ARC_fnc_stateGet;
private _med  = ["baseMed",  0.40] call ARC_fnc_stateGet;

// Activity counters (help players see the campaign move)
// NOTE: intelCounter is a monotonic ID generator; it includes OPS items.
// For player-facing counts we only count non-OPS entries.
private _log = ["intelLog", []] call ARC_fnc_stateGet;
if (!(_log isEqualType [])) then { _log = []; };

private _intelCount = count (_log select { _x isEqualType [] && { (count _x) >= 3 } && { toUpper (_x # 2) isNotEqualTo "OPS" } });
private _opsCount   = count (_log select { _x isEqualType [] && { (count _x) >= 3 } && { toUpper (_x # 2) isEqualTo "OPS" } });

// Recent incident history tail (for dashboards)
private _hist = ["incidentHistory", []] call ARC_fnc_stateGet;
if (!(_hist isEqualType [])) then { _hist = []; };
private _hCount = count _hist;
private _hStart = (_hCount - 8) max 0;
private _hTail = _hist select [_hStart, _hCount - _hStart];

// Metric snapshot tail (for in-game dashboards / change monitor)
private _snaps = ["metricsSnapshots", []] call ARC_fnc_stateGet;
if (!(_snaps isEqualType [])) then { _snaps = []; };
private _sCount = count _snaps;
private _sMax = missionNamespace getVariable ["ARC_metricsSnapshotsPublicMax", 8];
if (!(_sMax isEqualType 0)) then { _sMax = 8; };
private _sStart = (_sCount - _sMax) max 0;
private _sTail = _snaps select [_sStart, _sCount - _sStart];

private _pub = [
    ["insurgentPressure", _p],
    ["corruption", _c],
    ["infiltration", _i],
    ["civSentiment", _sent],
    ["govLegitimacy", _leg],
    ["civCasualties", _cas],
    ["baseFuel", _fuel],
    ["baseAmmo", _ammo],
    ["baseMed", _med],
    ["intelCount", _intelCount],
    ["opsCount", _opsCount],
    ["incidentCount", _hCount],
    ["incidentHistoryTail", _hTail],
    ["metricsSnapshotsTail", _sTail]
];

missionNamespace setVariable ["ARC_pub_state", _pub, true];
missionNamespace setVariable ["ARC_pub_stateUpdatedAt", serverTime, true];
// Optional debug snapshot for the in-game inspector diary.
private _dbgEnabled = missionNamespace getVariable ["ARC_debugInspectorEnabled", false];
if (!(_dbgEnabled isEqualType true)) then { _dbgEnabled = false; };

if (_dbgEnabled) then
{
    // Throttle to avoid rebuilding summaries too frequently (public state can publish often).
    private _lastDbg = missionNamespace getVariable ["ARC_pub_debugUpdatedAt", -1];
    if (!(_lastDbg isEqualType 0)) then { _lastDbg = -1; };

    if ((_lastDbg < 0) || { (serverTime - _lastDbg) > 5 }) then
    {
        private _cleanupQueue = ["cleanupQueue", []] call ARC_fnc_stateGet;
        if (!(_cleanupQueue isEqualType [])) then { _cleanupQueue = []; };

        private _labelCounts = createHashMap;
        {
            private _label = _x param [4, ""];
            if (!(_label isEqualType "")) then { _label = ""; };

            // Group by prefix to keep the list compact (ex: "patrolContact:XYZ" -> "patrolContact").
            private _key = _label;
            private _p = _label find ":";
            if (_p > 0) then { _key = _label select [0, _p]; };
            if (_key isEqualTo "") then { _key = "(none)"; };

            _labelCounts set [_key, 1 + (_labelCounts getOrDefault [_key, 0])];
        } forEach _cleanupQueue;

        private _tmp = [];
        { _tmp pushBack [_y, _x]; } forEach _labelCounts;  // [count,label]
        _tmp sort false;

        private _cleanupByLabel = _tmp apply { [_x # 1, _x # 0] };

        private _convoyNids = ["activeConvoyNetIds", []] call ARC_fnc_stateGet;
        if (!(_convoyNids isEqualType [])) then { _convoyNids = []; };

        private _localNids = ["activeLocalSupportNetIds", []] call ARC_fnc_stateGet;
        if (!(_localNids isEqualType [])) then { _localNids = []; };

        private _routeNids = ["activeRouteSupportNetIds", []] call ARC_fnc_stateGet;
        if (!(_routeNids isEqualType [])) then { _routeNids = []; };

        private _cpNids = missionNamespace getVariable ["ARC_persistentCheckpointNetIds", []];
        if (!(_cpNids isEqualType [])) then { _cpNids = []; };

        private _cap = 25;

        private _convoyShort = +_convoyNids;
        if ((count _convoyShort) > _cap) then { _convoyShort resize _cap; };

        private _localShort = +_localNids;
        if ((count _localShort) > _cap) then { _localShort resize _cap; };

        private _routeShort = +_routeNids;
        if ((count _routeShort) > _cap) then { _routeShort resize _cap; };

        private _cpShort = +_cpNids;
        if ((count _cpShort) > _cap) then { _cpShort resize _cap; };

        // Threat v0 debug (server-only state; summarized for inspector)
        private _tEnabled = ["threat_v0_enabled", true] call ARC_fnc_stateGet;
        if (!(_tEnabled isEqualType true) && !(_tEnabled isEqualType false)) then { _tEnabled = true; };

        private _tOpen = ["threat_v0_open_index", []] call ARC_fnc_stateGet;
        if (!(_tOpen isEqualType [])) then { _tOpen = []; };

        private _tClosed = ["threat_v0_closed_index", []] call ARC_fnc_stateGet;
        if (!(_tClosed isEqualType [])) then { _tClosed = []; };

        private _tLast = missionNamespace getVariable ["threat_v0_debug_last_event", []];
        if (!(_tLast isEqualType [])) then { _tLast = []; };

        private _dbg = [
            ["cleanupCount", count _cleanupQueue],
            ["cleanupByLabel", _cleanupByLabel],

            ["netIdCap", _cap],

            ["activeConvoyCount", count _convoyNids],
            ["activeConvoyNetIds", _convoyShort],

            ["activeLocalSupportCount", count _localNids],
            ["activeLocalSupportNetIds", _localShort],

            ["activeRouteSupportCount", count _routeNids],
            ["activeRouteSupportNetIds", _routeShort],

            ["persistentCheckpointCount", count _cpNids],
            ["persistentCheckpointNetIds", _cpShort],

            ["threatEnabled", _tEnabled],
            ["threatOpenCount", count _tOpen],
            ["threatClosedCount", count _tClosed],
            ["threatLast", _tLast],

            // IED Phase 1 (active device/trigger summary)
            ["activeIedDeviceId", ["activeIedDeviceId", ""] call ARC_fnc_stateGet],
            ["activeIedTriggerEnabled", ["activeIedTriggerEnabled", false] call ARC_fnc_stateGet],
            ["activeIedTriggerRadiusM", ["activeIedTriggerRadiusM", 0] call ARC_fnc_stateGet],

["activeIedEvidenceNetId", ["activeIedEvidenceNetId", ""] call ARC_fnc_stateGet],
["activeIedEvidenceCollected", ["activeIedEvidenceCollected", false] call ARC_fnc_stateGet],
["activeIedEvidenceTransportEnabled", ["activeIedEvidenceTransportEnabled", false] call ARC_fnc_stateGet],
["activeIedEvidenceDelivered", ["activeIedEvidenceDelivered", false] call ARC_fnc_stateGet],
["activeIedEvidenceLeadId", ["activeIedEvidenceLeadId", ""] call ARC_fnc_stateGet],
["activeIedDetectedByScan", ["activeIedDetectedByScan", false] call ARC_fnc_stateGet],
            ["iedPhase1RecordsCount", count (missionNamespace getVariable ["ARC_iedPhase1_deviceRecords", []])],

            // VBIED (Phase 3)
            ["activeVbiedTriggerEnabled", ["activeVbiedTriggerEnabled", false] call ARC_fnc_stateGet],
            ["activeVbiedTriggerRadiusM", ["activeVbiedTriggerRadiusM", 0] call ARC_fnc_stateGet],
            ["activeVbiedDeviceId", ["activeVbiedDeviceId", ""] call ARC_fnc_stateGet],
            ["activeVbiedDetonated", ["activeVbiedDetonated", false] call ARC_fnc_stateGet],
            ["activeVbiedSafe", ["activeVbiedSafe", false] call ARC_fnc_stateGet],
            ["activeVbiedDisposed", ["activeVbiedDisposed", false] call ARC_fnc_stateGet],
            ["activeVbiedDestroyedCause", ["activeVbiedDestroyedCause", ""] call ARC_fnc_stateGet],
            ["vbiedPhase3RecordsCount", count (missionNamespace getVariable ["ARC_vbiedPhase3_deviceRecords", []])]
        ];

        // CIVSUB v1 (only when enabled)
        if (missionNamespace getVariable ["civsub_v1_enabled", false]) then
        {
            private _civDbg = [] call ARC_fnc_civsubDebugSnapshot;
            if (_civDbg isEqualType []) then { _dbg append _civDbg; };
        };


        missionNamespace setVariable ["ARC_pub_debug", _dbg, true];
        missionNamespace setVariable ["ARC_pub_debugUpdatedAt", serverTime, true];
    };
};

// ---------------------------------------------------------------------------
// Console VM meta (rev) publish: monotonic rev to stabilize UI refresh ordering
// ---------------------------------------------------------------------------
private _rev = missionNamespace getVariable ["ARC_consoleVM_rev", 0];
if (!(_rev isEqualType 0)) then { _rev = 0; };
_rev = _rev + 1;
missionNamespace setVariable ["ARC_consoleVM_rev", _rev];
missionNamespace setVariable ["ARC_consoleVM_meta", [
    ["schema", "Console_VM_v1"],
    ["schemaVersion", 1],
    ["rev", _rev],
    ["publishedAt", serverTime],
    ["source", "publicBroadcastState"]
], true];

true
