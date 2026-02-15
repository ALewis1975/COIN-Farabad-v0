/*
    ARC_fnc_uiFollowOnDialogCancel

    Client: cancel Follow-on dialog. Stores [false] result and closes.
*/

if (!hasInterface) exitWith {false};

uiNamespace setVariable ["ARC_followOn_result", [false]];
closeDialog 2;
true
