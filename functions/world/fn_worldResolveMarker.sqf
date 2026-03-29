/*
    Resolve a marker name to an existing marker.

    This supports legacy Eden markers (e.g., marker_2...) by mapping them to
    runtime reference markers (ARC_loc_*).

    Params:
        0: STRING - marker name

    Returns:
        STRING - resolved marker name (may be unchanged). If resolution fails,
                 the returned marker may still not exist.
*/

params ["_markerName"];

if (_markerName isEqualTo "") exitWith {""};

private _aliases = missionNamespace getVariable ["ARC_markerAliases", createHashMap];
if (_aliases isEqualType createHashMap) then
{
    private _alt = _aliases getOrDefault [_markerName, ""];
	if ((_alt isNotEqualTo "") && { _alt in allMapMarkers }) exitWith { _alt };
};

if (_markerName in allMapMarkers) exitWith {_markerName};

_markerName
