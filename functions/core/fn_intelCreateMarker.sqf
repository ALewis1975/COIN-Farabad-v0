/*
    Server-side: create (or update) a map marker for an intel entry.

    This is a lightweight way to give players something they can "go to" during testing
    without immediately building full physical intel props everywhere.

    Params:
        0: STRING - intelId (e.g., "INT-0007")
        1: STRING - category (e.g., "HUMINT", "SIGHTING", "ISR", "OPS")
        2: ARRAY  - position ATL

    Returns:
        STRING - marker name, or "" if skipped.
*/

if (!isServer) exitWith {""};

params [
    ["_intelId", ""],
    ["_category", "GEN"],
    ["_posATL", [0,0,0]]
];

if (_intelId isEqualTo "") exitWith {""};
if (!(_posATL isEqualType []) || { (count _posATL) < 2 }) exitWith {""};

private _catU = toUpper _category;

// OPS log items should not create intel map markers.
if (_catU in ["OPS", "DEBRIEF"]) exitWith {""};

// Ignore "zero" placeholder positions
if ((_posATL # 0) isEqualTo 0 && { (_posATL # 1) isEqualTo 0 }) exitWith {""};

private _mName = format ["ARC_intel_%1", _intelId];
private _pos2 = +_posATL; _pos2 resize 2;

if !(_mName in allMapMarkers) then
{
    createMarker [_mName, _pos2];
}
else
{
    _mName setMarkerPos _pos2;
};

// Conservative marker styling (can be tuned later)
private _color = switch (_catU) do
{
    case "HUMINT": { "ColorOrange" };
    case "SIGHTING": { "ColorBlue" };
    case "ISR": { "ColorGreen" };
    case "OPS": { "ColorYellow" };
    default { "ColorWhite" };
};

_mName setMarkerType "mil_dot";
_mName setMarkerColor _color;
_mName setMarkerText format ["%1 %2", _intelId, _catU];
_mName setMarkerAlpha 0.75;

_mName
