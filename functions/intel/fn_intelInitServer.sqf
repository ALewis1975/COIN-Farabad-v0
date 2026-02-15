/*
    ARC_fnc_intelInitServer

    Server-side intel layer init.

    - Establishes default tuning vars (metrics cadence, retention caps).
    - Ensures at least one metrics snapshot exists.
    - Publishes queue + orders snapshots for clients.

    Returns:
      BOOL
*/

if (!isServer) exitWith {false};

if (missionNamespace getVariable ["ARC_intelInitServer_done", false]) exitWith {true};
missionNamespace setVariable ["ARC_intelInitServer_done", true];

// -------------------------------------------------------------------------
// Tuning / retention (public so clients can render consistent intervals)
// -------------------------------------------------------------------------
private _metricsInterval = missionNamespace getVariable ["ARC_metricsIntervalSec", 900];
if (!(_metricsInterval isEqualType 0)) then { _metricsInterval = 900; };
_metricsInterval = (_metricsInterval max 60) min 7200;
missionNamespace setVariable ["ARC_metricsIntervalSec", _metricsInterval, true];

private _snapCap = missionNamespace getVariable ["ARC_metricsSnapshotsCap", 24];
if (!(_snapCap isEqualType 0)) then { _snapCap = 24; };
_snapCap = (_snapCap max 4) min 96;
missionNamespace setVariable ["ARC_metricsSnapshotsCap", _snapCap, true];

private _snapPubMax = missionNamespace getVariable ["ARC_metricsSnapshotsPublicMax", 8];
if (!(_snapPubMax isEqualType 0)) then { _snapPubMax = 8; };
_snapPubMax = (_snapPubMax max 2) min 24;
missionNamespace setVariable ["ARC_metricsSnapshotsPublicMax", _snapPubMax, true];

private _queueCap = missionNamespace getVariable ["ARC_tocQueueCap", 30];
if (!(_queueCap isEqualType 0)) then { _queueCap = 30; };
_queueCap = (_queueCap max 10) min 100;
missionNamespace setVariable ["ARC_tocQueueCap", _queueCap, true];

private _orderCap = missionNamespace getVariable ["ARC_tocOrderCap", 30];
if (!(_orderCap isEqualType 0)) then { _orderCap = 30; };
_orderCap = (_orderCap max 10) min 100;
missionNamespace setVariable ["ARC_tocOrderCap", _orderCap, true];

// -------------------------------------------------------------------------
// Seed metrics if missing
// -------------------------------------------------------------------------
private _snaps = ["metricsSnapshots", []] call ARC_fnc_stateGet;
if (!(_snaps isEqualType []) || { (count _snaps) isEqualTo 0 }) then
{
    [] call ARC_fnc_intelMetricsTick;
};

// Publish now (JIP-safe)
[] call ARC_fnc_intelQueueBroadcast;
[] call ARC_fnc_intelOrderBroadcast;

// Refresh public state (includes metrics tail)
[] call ARC_fnc_publicBroadcastState;

true
