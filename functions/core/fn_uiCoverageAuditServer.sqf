/*
    ARC_fnc_uiCoverageAuditServer

    Server: emits a "UI coverage map" to RPT and publishes it to clients.

    Purpose:
      - Keep a running checklist of which legacy addActions / ACE interactions
        have a Farabad Console replacement.
      - This is intentionally simple + explicit (low regression risk).

    Output:
      - missionNamespace variable ARC_uiCoverageMap (ARRAY of entries), public.
      - RPT log lines.

    Entry format:
      [
        category,            // e.g. "TOC", "S2", "FIELD", "HANDOFF"
        legacySurface,       // what used to trigger it (scroll menu / ACE / etc)
        legacyName,          // short legacy action name
        uiReplacement,       // where it lives in the console UI
        status               // "DONE" | "PARTIAL" | "TODO"
      ]
*/

if (!isServer) exitWith {false};

private _now = diag_tickTime;

private _entries =
[
    // Console entry points (we keep these on screens/vehicles by design)
    ["ENTRY", "addAction (TOC screens)", "Open Ops Screen",   "Console: Command (TOC) tab (forced open)", "DONE"],
    ["ENTRY", "addAction (TOC screens)", "Open Intel Screen", "Console: Intelligence (S2) tab (forced open)", "DONE"],
    ["ENTRY", "addAction (TOC screens)", "Open SITREP Screen","Console: Operations (S3) tab (forced open)", "DONE"],
    ["ENTRY", "keybind / tablet",        "Open Console",      "Console (role-gated tabs)", "DONE"],

    // Handoff patterns (deadlock-proofed)
    ["HANDOFF", "Console button", "Process Intel (RTB)", "Handoff tab: Process Intel", "DONE"],
    ["HANDOFF", "Console button", "Process EPW (RTB)",   "Handoff tab: Process EPW",   "DONE"],

    // Field command cycle
    ["FIELD", "scroll/ACE", "Accept Incident", "Operations tab: Incidents frame (Accept)", "DONE"],
    ["FIELD", "scroll/ACE", "Send SITREP",     "Operations tab: Incidents frame (Send SITREP)", "DONE"],
    ["FIELD", "scroll/ACE", "Request Follow-on","Operations tab: Follow-on button", "DONE"],

    // Orders
    ["TOC/FIELD", "scroll/ACE", "Accept TOC Order", "Operations tab: Orders frame (Accept)", "DONE"],
    ["TOC/FIELD", "scroll menu", "Open TOC Queue",  "Command tab / Intelligence tab: Queue Manager", "DONE"],

    // Command (TOC)
    ["TOC", "addAction (S3 screen)", "Generate Incident", "Command tab: Generate Incident", "DONE"],
    ["TOC", "addAction (S3 screen)", "Close Incident",    "Command tab: Closeout/Resolve", "DONE"],

    // S2
    ["S2", "addAction (S2 screen)", "Log Intel (Map): Sighting/HUMINT/ISR", "Intelligence tab: Intel logging tools", "DONE"],
    ["S2", "addAction (S2 screen)", "Log Cursor Sighting",                 "Intelligence tab: Cursor Sighting", "DONE"],
    ["S2", "addAction (S2 screen)", "Create Lead Request (Map)",           "Intelligence tab: Lead Request tools", "DONE"],
    ["S2", "addAction (S2 screen)", "Request Intel Refresh",               "Intelligence tab: Admin tools", "DONE"],

    // Admin tools (placeholder for next UI build)
    ["ADMIN", "debug console / scripts", "Reset/Save tools", "Headquarters tab: Admin tools", "DONE"]
];

missionNamespace setVariable ["ARC_uiCoverageMap", _entries, true];
missionNamespace setVariable ["ARC_uiCoverageMapBuiltAt", serverTime, true];

// RPT output
diag_log "============================================";
diag_log format ["[ARC][UI COVERAGE] Built at serverTime=%1 (diag=%2)", serverTime, _now];
{
    _x params ["_cat","_legacySurf","_legacy","_ui","_st"];
    diag_log format ["[ARC][UI COVERAGE] [%1] %2 :: %3 => %4 (%5)", _cat, _legacySurf, _legacy, _ui, _st];
} forEach _entries;
diag_log "============================================";

true
