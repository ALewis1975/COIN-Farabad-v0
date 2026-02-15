/*
    ARC_fnc_civsubNow

    Returns serverTime when available; falls back to time.
*/

if (isServer) exitWith {serverTime};
time
