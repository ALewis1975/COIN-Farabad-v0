/*
    ARC_fnc_iedClientExecuteDisposition

    Client: execute an approved EOD disposition action.

    Phase 5:
      - DET_IN_PLACE: server detonation for active IED device / VBIED vehicle.
      - RTB_IED / TOW_VBIED: server-authoritative logistics lifecycle request.

    Params:
      0: STRING requestType (DET_IN_PLACE|RTB_IED|TOW_VBIED)

    Returns:
      BOOL
*/

if (!hasInterface) exitWith {false};

params [
    ["_req", "DET_IN_PLACE", [""]]
];

_req = toUpper (trim _req);
if !(_req in ["DET_IN_PLACE","RTB_IED","TOW_VBIED"]) then { _req = "DET_IN_PLACE"; };

if (!([_req] call ARC_fnc_iedClientHasEodApproval)) exitWith
{
    ["EOD", "No TOC approval for this disposition."] call ARC_fnc_clientToast;
    false
};

private _kind = ["activeObjectiveKind", ""] call ARC_fnc_stateGet;
if (!(_kind isEqualType "")) then { _kind = ""; };
_kind = toUpper (trim _kind);

switch (_req) do
{
    case "DET_IN_PLACE":
    {
        if (_kind isEqualTo "IED_DEVICE") then
        {
            private _did = ["activeIedDeviceId", ""] call ARC_fnc_stateGet;
            if (!(_did isEqualType "")) then { _did = ""; };
            _did = trim _did;
            if (_did isEqualTo "") exitWith { ["EOD", "No active IED device."] call ARC_fnc_clientToast; false };
            [_did] remoteExec ["ARC_fnc_iedServerDetonate", 2];
            ["EOD", "Detonation requested (TOC approved)."] call ARC_fnc_clientToast;
            true
        }
        else
        {
            if (_kind isEqualTo "VBIED_VEHICLE") then
            {
                private _did = ["activeVbiedDeviceId", ""] call ARC_fnc_stateGet;
                if (!(_did isEqualType "")) then { _did = ""; };
                _did = trim _did;
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
    };

    case "RTB_IED":
    {
        [_req] remoteExec ["ARC_fnc_iedServerRequestDisposition", 2];
        ["EOD", "RTB evidence approved. Server is enabling evidence transport / delivery tracking."] call ARC_fnc_clientToast;
        true
    };

    case "TOW_VBIED":
    {
        [_req] remoteExec ["ARC_fnc_iedServerRequestDisposition", 2];
        ["EOD", "Tow disposition approved. Server is enabling VBIED tow / disposal tracking."] call ARC_fnc_clientToast;
        true
    };
};

false
