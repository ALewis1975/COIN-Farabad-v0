/*
    ARC_fnc_uiConsoleActionCivRunLastId

    Client: "MDT Run" for the most recently shown CIV ID card.
    Uses the payload cached by ARC_fnc_civsubClientShowIdCard.

    Result handling:
      - Server calls ARC_fnc_civsubInteractCheckPapers, which already issues player-facing messages.
*/
if (!hasInterface) exitWith {false};

private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _hg      = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

private _payload = uiNamespace getVariable ["ARC_civsub_lastIdCardPayload", createHashMap];
if (_payload isEqualType []) then { _payload = [_payload] call _hmCreate; };
if !(_payload isEqualType createHashMap) exitWith {false};

private _netId = [_payload, "civ_netId", ""] call _hg;
if (!(_netId isEqualType "") || { (trim _netId) isEqualTo "" }) exitWith {
    ["S2 Ops", "No recent civilian ID on file. Use Show Papers first."] call ARC_fnc_clientToast;
    false
};

[player, _netId] remoteExecCall ["ARC_fnc_civsubRunMdtByNetId", 2];
["S2 Ops", "MDT run submitted."] call ARC_fnc_clientToast;

true
