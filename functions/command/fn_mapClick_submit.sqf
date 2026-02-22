/*
    ARC_fnc_mapClick_submit

    Internal submit router for client map-click service.

    Params:
      0: ARRAY posATL

    Returns:
      BOOL success
*/

if (!hasInterface) exitWith {false};

params ["_pos"];

if (!(_pos isEqualType []) || {count _pos < 2}) exitWith
{
    uiNamespace setVariable ["ARC_mapClick_lastErr", "invalid_pos"];
    false
};

private _ctx = uiNamespace getVariable ["ARC_mapClick_ctx", createHashMap];
if !(_ctx isEqualType createHashMap) then { _ctx = createHashMap; };

private _type = toUpper (_ctx getOrDefault ["type", ""]);
diag_log format ["[FARABAD][MAPCLICK][SUBMIT] type=%1", _type];

switch (_type) do
{
    case "INTEL_LOG":
    {
        private _cat = _ctx getOrDefault ["category", "SIGHTING"];
        private _sum = _ctx getOrDefault ["summary", "No details provided."];
        private _det = _ctx getOrDefault ["details", ""];

        [player, name player, _cat, _pos, _sum, _det] remoteExec ["ARC_fnc_tocRequestLogIntel", 2];
        uiNamespace setVariable ["ARC_mapClick_lastErr", ""];
        true
    };

    case "LEAD_REQ":
    {
        private _leadType = _ctx getOrDefault ["leadType", "RECON"];
        private _sum = _ctx getOrDefault ["summary", "Lead: Unknown"];
        private _det = _ctx getOrDefault ["details", ""];
        private _conf = _ctx getOrDefault ["confidence", "MED"];
        private _strength = _ctx getOrDefault ["strength", 0.55];
        private _ttl = _ctx getOrDefault ["ttl", 3600];

        private _payload = [
            ["leadType", _leadType],
            ["displayName", _sum],
            ["strength", _strength],
            ["ttl", _ttl],
            ["confidence", _conf],
            ["tag", "S2_REQUEST"]
        ];

        [
            player,
            "LEAD_REQUEST",
            _payload,
            _sum,
            _det,
            _pos,
            [["source", "S2_MAPCLICK"]]
        ] remoteExec ["ARC_fnc_intelQueueSubmit", 2];

        uiNamespace setVariable ["ARC_mapClick_lastErr", ""];
        true
    };

    default
    {
        uiNamespace setVariable ["ARC_mapClick_lastErr", format ["unsupported_type:%1", _type]];
        false
    };
};
