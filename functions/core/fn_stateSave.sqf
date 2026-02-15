/*
    Saves ARC_state from missionNamespace into missionProfileNamespace.
    Call this periodically and on key events.
*/

if (!isServer) exitWith {false};

private _state = missionNamespace getVariable ["ARC_state", []];
missionProfileNamespace setVariable ["ARC_state", _state];

// Returns true/false depending on success.
saveMissionProfileNamespace
