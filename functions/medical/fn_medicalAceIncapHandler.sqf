/*
    ARC_fnc_medicalAceIncapHandler

    Client-side: detect ACE3 player incapacitation and fire a server RPC to
    generate a CASEVAC lead in the TOC queue.

    Hooks the ACE3 "ace_medical_treatment_unconscious" mission event (fired by
    ACE when a unit becomes unconscious). Falls back to the standard EntityKilled
    EH already registered by ARC_fnc_medicalInit when ACE is absent.

    Call once from initPlayerLocal.sqf (client bootstrap).

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

// Guard: only register once per client session
if (missionNamespace getVariable ["ARC_medAceIncapHandlerRegistered", false]) exitWith
{
    diag_log "[ARC][MEDICAL][ACE] medicalAceIncapHandler: already registered, skipping.";
    true
};
missionNamespace setVariable ["ARC_medAceIncapHandlerRegistered", true];

// Per-player cooldown to avoid spamming the server with rapid incap events
private _cooldownKey = "ARC_medAceIncapClientLastTs";

// ACE3 unconscious event — fired on the machine where the unit is local
["ace_unconscious", {
    params ["_unit", "_isUnconscious"];

    if (!_isUnconscious) exitWith {};
    if (side (group _unit) != west) exitWith {};

    // Per-player cooldown (client-side gate)
    private _now = diag_tickTime;
    private _lastTs = uiNamespace getVariable ["ARC_medAceIncapClientLastTs", -1];
    if (!(_lastTs isEqualType 0)) then { _lastTs = -1; };
    if (_lastTs > 0 && { (_now - _lastTs) < 30 }) exitWith {};
    uiNamespace setVariable ["ARC_medAceIncapClientLastTs", _now];

    // Forward to server — server creates CASEVAC lead via medicalCasevacRequest
    [_unit, west] remoteExec ["ARC_fnc_medicalCasevacRequest", 2];

    diag_log format ["[ARC][MEDICAL][ACE] medicalAceIncapHandler: ACE unconscious event — unit=%1, RPC sent to server.", name _unit];
}] call CBA_fnc_addEventHandler;

diag_log "[ARC][MEDICAL][ACE] medicalAceIncapHandler: ace_unconscious event handler registered via CBA.";

true
