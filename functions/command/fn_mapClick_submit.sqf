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

// sqflint-compat helpers
private _hg         = compile "params ['_h','_k','_d']; (_h) getOrDefault [_k, _d]";

if (!(_pos isEqualType []) || {count _pos < 2}) exitWith
{
    uiNamespace setVariable ["ARC_mapClick_lastErr", "invalid_pos"];
    false
};

private _ctx = uiNamespace getVariable ["ARC_mapClick_ctx", createHashMap];
if !(_ctx isEqualType createHashMap) then { _ctx = createHashMap; };

private _type = toUpper ([_ctx, "type", ""] call _hg);
diag_log format ["[FARABAD][MAPCLICK][SUBMIT] type=%1", _type];

switch (_type) do
{
    case "INTEL_LOG":
    {
        private _cat = [_ctx, "category", "SIGHTING"] call _hg;
        private _sum = [_ctx, "summary", "No details provided."] call _hg;
        private _det = [_ctx, "details", ""] call _hg;

        [player, name player, _cat, _pos, _sum, _det] remoteExec ["ARC_fnc_tocRequestLogIntel", 2];
        uiNamespace setVariable ["ARC_mapClick_lastErr", ""];
        true
    };

    case "LEAD_REQ":
    {
        private _leadType = [_ctx, "leadType", "RECON"] call _hg;
        private _sum = [_ctx, "summary", "Lead: Unknown"] call _hg;
        private _det = [_ctx, "details", ""] call _hg;
        private _conf = [_ctx, "confidence", "MED"] call _hg;
        private _strength = [_ctx, "strength", 0.55] call _hg;
        private _ttl = [_ctx, "ttl", 3600] call _hg;

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
