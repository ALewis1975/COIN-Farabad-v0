/* Open STARTDISP confirmation dialog before incident acceptance. */
if (!hasInterface) exitWith { false };
if (isNull player) exitWith { false };
uiNamespace setVariable ["ARC_startdispDialog_result", nil];
createDialog "ARC_StartdispDialog";
true
