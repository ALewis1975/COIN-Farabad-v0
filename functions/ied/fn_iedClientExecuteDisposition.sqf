/*
    ARC_fnc_iedClientExecuteDisposition

    Client: execute an approved EOD disposition action.

    Phase 4:
      - DET_IN_PLACE: server detonation for active IED device / VBIED vehicle.
      - RTB_IED / TOW_VBIED: placeholder (Phase 5 will implement).

    Params:
      0: STRING requestType (DET_IN_PLACE|RTB_IED|TOW_VBIED)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_req", "DET_IN_PLACE", [""]]
];

private _trimFn = compile "params ['_s']; trim _s";

_req = toUpper ([_req] call _trimFn);
if !(_req in ["DET_IN_PLACE","RTB_IED","TOW_VBIED"]) then { _req = "DET_IN_PLACE"; };

if (!([_req] call ARC_fnc_iedClientHasEodApproval)) exitWith
{
    ["EOD", "No TOC approval for this disposition."] call ARC_fnc_clientToast;
    false
};

private _kind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
if (!(_kind isEqualType "")) then { _kind = ""; };
_kind = toUpper ([_kind] call _trimFn);

switch (_req) do
{
    case "DET_IN_PLACE":
    {
        if (_kind isEqualTo "IED_DEVICE") then
        {
            private _did = ["activeIedDeviceId", ""] call ARC_fnc_stateGet;
            if (!(_did isEqualType "")) then { _did = ""; };
            _did = [_did] call _trimFn;
            if (_did isEqualTo "") exitWith { ["EOD", "No active IED device."] call ARC_fnc_clientToast; false };
            [_did] remoteExec ["ARC_fnc_iedServerDetonate", 2];
            ["EOD", "Detonation requested (TOC approved)."] call ARC_fnc_clientToast;
            true
        }
        else
        if (_kind isEqualTo "VBIED_VEHICLE") then
        {
            private _did = ["activeVbiedDeviceId", ""] call ARC_fnc_stateGet;
            if (!(_did isEqualType "")) then { _did = ""; };
            _did = [_did] call _trimFn;
            if (_did isEqualTo "") exitWith { ["EOD", "No active VBIED vehicle."] call ARC_fnc_clientToast; false };
            [_did] remoteExec ["ARC_fnc_vbiedServerDetonate", 2];
            ["EOD", "Detonation requested (TOC approved)."] call ARC_fnc_clientToast;
            true
        }
        else
        {
            ["EOD", "No supported EOD objective active."] call ARC_fnc_clientToast;
            false
        };
    };

    case "RTB_IED":
    {
        ["EOD", "RTB evidence approved. Transport evidence to the EOD site."] call ARC_fnc_clientToast;
        true
    };

    case "TOW_VBIED":
    {
        ["EOD", "Tow disposition approved. Move the VBIED to the EOD site, then dispose."] call ARC_fnc_clientToast;
        true
    };
};

false
