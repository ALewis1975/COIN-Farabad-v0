/*
    ARC_fnc_civsubCivIsProtected

    Returns true if a CIVSUB civilian should NOT be despawned by sampler cleanup/cap enforcement.

    Rules (delta-only, conservative):
      - civsub_v1_pinned == true (set on detention, custody handoff, scripted holds)
      - captive == true (engine captive flag)
      - ACE captives handcuffed flag if present
      - identity record says detained/handedOff (server-side truth)

    Params:
      0: civ unit (object)

    Returns: bool
*/

params [["_u", objNull, [objNull]]];
if (isNull _u) exitWith {false};

// Explicit pin (CIVSUB-owned)
if (_u getVariable ["civsub_v1_pinned", false]) exitWith {true};

// Engine captive
if (captive _u) exitWith {true};

// ACE captives (best-effort, do not hard-require ACE)
if (_u getVariable ["ace_captives_isHandcuffed", false]) exitWith {true};

// Identity-based (best-effort). Only exists for touched civs.
private _civUid = _u getVariable ["civ_uid", ""]; 
private _hg = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

if !(_civUid isEqualTo "") then {
    private _rec = [_civUid] call ARC_fnc_civsubIdentityGet;
    if (_rec isEqualType createHashMap) then {
        if ([_rec, "status_detained", false] call _hg) exitWith {true};
        if ([_rec, "status_handedOff", false] call _hg) exitWith {true};
    };
};

false
