/*
    ARC_fnc_civsubCivIsProtected

    Returns true if a CIVSUB civilian should NOT be despawned by sampler cleanup/cap enforcement.

    Rules:
      - active task / deferred cleanup ownership or explicit AO persistence
      - civsub_v1_pinned == true
      - active interaction stop marker is present and fresh
      - captive == true
      - ACE captives handcuffed flag if present
      - identity record says detained/handedOff

    Params:
      0: civ unit (object)

    Returns: bool
*/

params [["_u", objNull, [objNull]]];
if (isNull _u) exitWith {false};

private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

// Identity registration does not transfer task-scene cleanup ownership to the sampler.
// Use the existing task tags and core cleanup queue; stale tags alone do not pin actors.
private _persist = _u getVariable ["ARC_persistInAO", false];
if (_persist isEqualTo true) exitWith {true};

private _taskProtected = false;
if (isServer) then {
    private _grp = group _u;
    private _taskIds = [
        _u getVariable ["ARC_localSupportTaskId", _grp getVariable ["ARC_localSupportTaskId", ""]],
        _u getVariable ["ARC_overlayTaskId", _grp getVariable ["ARC_overlayTaskId", ""]]
    ];
    _taskIds = _taskIds select { _x isEqualType "" && { !(_x isEqualTo "") } };
    if ((count _taskIds) > 0) then {
        private _activeTaskId = ["activeTaskId", ""] call ARC_fnc_stateGet;
        _taskProtected = _activeTaskId isEqualType "" && { !(_activeTaskId isEqualTo "") } && { _activeTaskId in _taskIds };
        if (!_taskProtected) then {
            private _nid = netId _u;
            private _cleanupQueue = ["cleanupQueue", []] call ARC_fnc_stateGet;
            if (!(_nid isEqualTo "") && { _cleanupQueue isEqualType [] }) then {
                {
                    if (_x isEqualType [] && { (count _x) >= 4 } && { (_x select 0) isEqualTo _nid }) exitWith {
                        _taskProtected = true;
                    };
                } forEach _cleanupQueue;
            };
        };
    };
};
if (_taskProtected) exitWith {true};

// Explicit pin (CIVSUB-owned)
if (_u getVariable ["civsub_v1_pinned", false]) exitWith {true};

// Active interaction session marker. The Interact action sets this via OrderStop before opening the dialog.
private _stopped = _u getVariable ["civsub_v1_stopped", false];
private _interactionProtected = false;
if (_stopped isEqualType true && {_stopped}) then {
    private _ownerUid = _u getVariable ["civsub_v1_stopOwnerUid", ""];
    private _stopTs = _u getVariable ["civsub_v1_stopTs", 0];
    private _ttl = missionNamespace getVariable ["civsub_v1_interactionProtectionTtl_s", 900];
    if (!(_ownerUid isEqualType "")) then { _ownerUid = ""; };
    if (!(_stopTs isEqualType 0)) then { _stopTs = 0; };
    if (!(_ttl isEqualType 0)) then { _ttl = 900; };
    _ttl = (_ttl max 60) min 3600;

    _interactionProtected = !(_ownerUid isEqualTo "") && {_stopTs > 0} && {(serverTime - _stopTs) <= _ttl};
};
if (_interactionProtected) exitWith {true};

// Engine captive
if (captive _u) exitWith {true};

// ACE captives (best-effort, do not hard-require ACE)
if (_u getVariable ["ace_captives_isHandcuffed", false]) exitWith {true};

// Identity-based (best-effort). Only exists for touched civs.
private _identityProtected = false;
private _civUid = _u getVariable ["civ_uid", ""]; 
if !(_civUid isEqualTo "") then {
    private _rec = [_civUid] call ARC_fnc_civsubIdentityGet;
    if (_rec isEqualType createHashMap) then {
        _identityProtected = (([_rec, "status_detained", false] call _hg) isEqualTo true)
            || { ([_rec, "status_handedOff", false] call _hg) isEqualTo true };
    };
};

_identityProtected
