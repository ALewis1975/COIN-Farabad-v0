/* Cancel STARTDISP dialog without accepting incident. */
if (!hasInterface) exitWith { false };
uiNamespace setVariable ["ARC_startdispDialog_result", [false]];
closeDialog 2;
true
