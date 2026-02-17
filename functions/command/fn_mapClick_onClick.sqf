/*
    ARC_fnc_mapClick_onClick

    Internal onMapSingleClick handler.

    Extracts _pos from _this event payload, then delegates to submit/disarm.
*/

if (!hasInterface) exitWith {false};

private _evt = _this;
private _pos = [];
if ((_evt isEqualType []) && {count _evt > 1}) then
{
    _pos = _evt select 1;
};

if (!(_pos isEqualType []) || {count _pos < 2}) exitWith
{
    hint "Map click failed: invalid position.";
    ["invalid_pos"] call ARC_fnc_mapClick_disarm;
    false
};

uiNamespace setVariable ["ARC_mapClick_lastPos", _pos];

private _ok = [_pos] call ARC_fnc_mapClick_submit;
private _ctx = uiNamespace getVariable ["ARC_mapClick_ctx", createHashMap];
private _type = toUpper (_ctx getOrDefault ["type", ""]);

if (_ok) then
{
    switch (_type) do
    {
        case "INTEL_LOG":
        {
            private _cat = _ctx getOrDefault ["category", "SIGHTING"];
            hint format ["Submitted intel (%1) at %2.", _cat, mapGridPosition _pos];
        };

        case "LEAD_REQ":
        {
            hint "Lead request submitted to TOC queue.";
        };

        default
        {
            hint "Map click submitted.";
        };
    };

    ["submitted"] call ARC_fnc_mapClick_disarm;
    true
}
else
{
    hint "Map click submit failed.";
    ["submit_failed"] call ARC_fnc_mapClick_disarm;
    false
};
