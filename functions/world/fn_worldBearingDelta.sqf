/*
    ARC_fnc_worldBearingDelta

    Return the absolute shortest angular difference between two bearings.

    Params:
      0: bearingA degrees
      1: bearingB degrees

    Returns:
      Number in range 0..180
*/

params [
    ["_bearingA", 0, [0]],
    ["_bearingB", 0, [0]]
];

if (!(_bearingA isEqualType 0)) then { _bearingA = 0; };
if (!(_bearingB isEqualType 0)) then { _bearingB = 0; };

// Add 540 before modulo so negative bearing differences wrap into a positive
// range, then subtract 180 and abs it to get unsigned delta in 0..180.
abs (((_bearingA - _bearingB + 540) % 360) - 180)
