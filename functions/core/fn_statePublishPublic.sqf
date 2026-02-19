/*
    Server-authoritative coordinator for ARC public state publication.

    Params:
      0: ARRAY - public state payload (pairs array)
      1: STRING - source tag for diagnostics (optional)
      2: BOOL   - force publish (bypass guardrails, optional)
      3: NUMBER - minimum publish interval in seconds (optional)

    Returns:
      BOOL - true when a publish occurred, false when suppressed.
*/

params [
    ["_payload", [], [[]]],
    ["_source", "unknown", [""]],
    ["_force", false, [true]],
    ["_minInterval", 0.25, [0]]
];

if (!isServer) exitWith { false };

if (_minInterval < 0) then { _minInterval = 0; };

private _now = serverTime;
private _lastUpdatedAt = missionNamespace getVariable ["ARC_pub_stateUpdatedAt", -1];
if (!(_lastUpdatedAt isEqualType 0)) then { _lastUpdatedAt = -1; };

private _currentPayload = missionNamespace getVariable ["ARC_pub_state", []];
if (!(_currentPayload isEqualType [])) then { _currentPayload = []; };

// Guardrail 1: suppress stale-equivalent writes unless caller explicitly forces publish.
if (!_force && { _payload isEqualTo _currentPayload }) exitWith
{
    missionNamespace setVariable ["ARC_pub_stateLastPublishSuppressed", ["stale", _source, _now]];
    false
};

// Guardrail 2: suppress excessive publish cadence.
if (
    !_force &&
    { _minInterval > 0 } &&
    { _lastUpdatedAt >= 0 } &&
    { (_now - _lastUpdatedAt) < _minInterval }
) exitWith
{
    missionNamespace setVariable ["ARC_pub_stateLastPublishSuppressed", ["cadence", _source, _now, _lastUpdatedAt, _minInterval]];
    false
};

missionNamespace setVariable ["ARC_pub_state", _payload, true];
// Keep serverTime (not time): replicated server-authoritative mission clock for client change detection.
missionNamespace setVariable ["ARC_pub_stateUpdatedAt", _now, true];
missionNamespace setVariable ["ARC_pub_stateLastPublishMeta", [_source, _now]];

true
