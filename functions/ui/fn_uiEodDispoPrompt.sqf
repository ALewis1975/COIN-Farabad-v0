/*
    ARC_fnc_uiEodDispoPrompt

    Client: prompt user for an EOD disposition request.

    Returns:
      ARRAY [okBool, requestType, notes]

    requestType:
      DET_IN_PLACE | RTB_IED | TOW_VBIED
*/

if (!hasInterface) exitWith { [false] };

uiNamespace setVariable ["ARC_eodDispo_result", nil];

createDialog "ARC_EodDispoDialog";

waitUntil {
    uiSleep 0.05;
    (!isNil { uiNamespace getVariable "ARC_eodDispo_result" }) || { isNull (findDisplay 78250) }
};

private _res = uiNamespace getVariable ["ARC_eodDispo_result", [false]];
uiNamespace setVariable ["ARC_eodDispo_result", nil];

if (!(_res isEqualType [])) exitWith { [false] };
_res
