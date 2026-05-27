// tools/dev_deploy/enable_dual_write.sqf
// Paste into the dedicated server admin debug console (#login + Server Debug
// Console → Server) to enable the FARABAD dual-write logger sink at runtime.
//
// See docs/qa/FARABAD_Logger_Dual_Write_Runbook.md for the full doctrine.
//
// Intended use: temporary, during dedicated-server validation only. The flag
// is reset on mission restart.

if (!isServer) exitWith {
    diag_log "[ARC][DEV] enable_dual_write.sqf: NOT server — aborting.";
    "NOT_SERVER"
};

missionNamespace setVariable ["ARC_loggerDualWriteEnabled", true, true];
diag_log "[ARC][DEV] FARABAD logger dual-write ENABLED at runtime.";

if (!isNil "ARC_fnc_intelLog") then {
    ["OPS", "DEV: logger dual-write enabled at runtime via admin console.", [0,0,0],
        [
            ["event", "DEV_DUAL_WRITE_ENABLED"],
            ["source", "tools/dev_deploy/enable_dual_write.sqf"]
        ]
    ] call ARC_fnc_intelLog;
};

"OK_ENABLED"
