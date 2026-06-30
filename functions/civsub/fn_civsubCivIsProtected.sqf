/*
    ARC_fnc_civsubCivIsProtected

    Returns true if a CIVSUB civilian should NOT be despawned by sampler cleanup/cap enforcement.

    Rules:
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

// Explicit pin (CIVSUB-owned)
if (_u getVariable ["civsub_v1_pinned", false]) exitWith {true};

// Active interaction session marker. The Interact action sets this via OrderStop before opening the dialog.
private _stopped = _u getVariable ["civsub_v1_stopped", false];
if (_stopped isEqualType true && {_stopped}) then {
    private _ownerUid = _u getVariable ["civsub_v1_stopOwnerUid", ""];
    private _stopTs = _u getVariable ["civsub_v1_stopTs", 0];
    private _ttl = missionNamespace getVariable ["civsub_v1_interactionProtectionTtl_s", 900];
    if (!(_ownerUid isEqualType "")) then { _ownerUid = ""; };
    if (!(_stopTs isEqualType 0)) then { _stopTs = 0; };
    if (!(_ttl isEqualType 0)) then { _ttl = 900; };
    _ttl = (_ttl max 60) min 3600;

    if (!(_ownerUid isEqualTo "") && {_stopTs > 0} && {(serverTime - _stopTs) <= _ttl}) exitWith {true};
};

// Engine captive
if (captive _u) exitWith {true};

// ACE captives (best-effort, do not hard-require ACE)
if (_u getVariable ["ace_captives_isHandcuffed", false]) exitWith {true};

// Identity-based (best-effort). Only exists for touched civs.
private _civUid = _u getVariable ["civ_uid", ""]; 
if !(_civUid isEqualTo "") then {
    private _rec = [_civUid] call ARC_fnc_civsubIdentityGet;
    if (_rec isEqualType createHashMap) then {
        if (_rec getOrDefault ["status_detained", false]) exitWith {true};
        if (_rec getOrDefault ["status_handedOff", false]) exitWith {true};
    };
};

false