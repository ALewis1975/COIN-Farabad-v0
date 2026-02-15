/*
    ARC_fnc_uiSitrepDialogCancel

    Client: cancel/close ARC_SitrepDialog.
*/

if (!hasInterface) exitWith {false};

uiNamespace setVariable ["ARC_sitrepDialog_result", [false, "", "", "", "", "GREEN", "GREEN", "GREEN", "", ""]];
closeDialog 2;
true
