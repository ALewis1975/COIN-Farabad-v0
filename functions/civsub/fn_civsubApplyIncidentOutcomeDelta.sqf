/*
    ARC_fnc_civsubApplyIncidentOutcomeDelta

    Applies CIVSUB district influence deltas based on incident type × outcome.
    Implements the 20-row permutation matrix from
    docs/architecture/CIVSUB_Incident_Lead_Permutation_Matrix.md.

    Called from fn_tocReceiveSitrep.sqf (Phase 6 extension) when a SITREP
    carries a SUCCEEDED or FAILED recommendation and CIVSUB is enabled.

    Server authoritative.

    Params:
      0: STRING - districtId (e.g. "D01")
      1: STRING - incidentType (e.g. "IED", "PATROL", "CIVIL")
      2: STRING - result ("SUCCEEDED" or "FAILED")
      3: STRING - zone (optional, e.g. "Airbase", "GreenZone", "")

    Returns:
      BOOL — true if delta was applied, false if no-op or error.

    Matrix rows implemented:
      Row  1: LOGISTICS/SUCCEEDED — YES (Guarded)  small legitimacy/trust lift
      Row  2: LOGISTICS/FAILED   — YES (Guarded)   fear spike + slight trust loss
      Row  3: ESCORT/SUCCEEDED   — YES (Guarded)   micro trust gain
      Row  4: ESCORT/FAILED      — YES (Guarded)   fear index + mild R pressure
      Row  5: IED/SUCCEEDED      — YES (Now)        clean interdiction: W↑ R↓ G↑
      Row  6: IED/FAILED         — YES (Now)        detonation trauma: W↓ R↑ G↓
      Row  7: RAID/SUCCEEDED     — YES (Guarded)    lawful clean raid: W↑ R↓ G↑
      Row  8: RAID/FAILED        — YES (Now)        fear pressure + anti-coop penalty
      Row  9: DEFEND/SUCCEEDED   — LATER            no-op
      Row 10: DEFEND/FAILED      — YES (Now)        security sentiment loss + fear spike
      Row 11: QRF/SUCCEEDED      — LATER            no-op
      Row 12: QRF/FAILED         — YES (Now)        trust/legitimacy loss + fear
      Row 13: PATROL/SUCCEEDED   — YES (Now)        civ-interaction quality → W/G drift
      Row 14: PATROL/FAILED      — YES (Guarded)    small W/G penalty
      Row 15: RECON/SUCCEEDED    — YES (Now)        district confidence boost
      Row 16: RECON/FAILED       — YES (Now)        cooperation loss + fear
      Row 17: CIVIL/SUCCEEDED    — YES (Now)        full CIVSUB delta: W↑ R↓ G↑
      Row 18: CIVIL/FAILED       — YES (Now)        strong W/G penalty + R pressure
      Row 19: CHECKPOINT/SUCCEEDED — YES (Now)      fairness dividend: W↑ G↑
      Row 20: CHECKPOINT/FAILED  — YES (Now)        fear increase + trust reduction
*/

if (!isServer) exitWith { false };
if !(missionNamespace getVariable ["civsub_v1_enabled", false]) exitWith { false };

params [
    ["_districtId",   "", [""]],
    ["_incidentType", "", [""]],
    ["_result",       "", [""]],
    ["_zone",         "", [""]]
];

private _trimFn = compile "params ['_s']; trim _s";
_districtId   = toUpper ([_districtId]   call _trimFn);
_incidentType = toUpper ([_incidentType] call _trimFn);
_result       = toUpper ([_result]       call _trimFn);
_zone         = toUpper ([_zone]         call _trimFn);

if (_districtId isEqualTo "") exitWith { false };
if !(_result in ["SUCCEEDED", "FAILED"]) exitWith { false };

// Influence deltas (W = civilian trust/cooperation, R = insurgent influence, G = governance legitimacy)
private _dW = 0;
private _dR = 0;
private _dG = 0;

switch (_incidentType) do
{
    case "LOGISTICS":
    {
        switch (_result) do
        {
            // Row 1: LOGISTICS/SUCCEEDED — small district legitimacy/trust lift
            case "SUCCEEDED": { _dW = 1.5; _dG = 1.0; };
            // Row 2: LOGISTICS/FAILED   — fear spike + slight trust loss in district
            case "FAILED":    { _dW = -2.0; _dR = 2.0; };
        };
    };

    case "ESCORT":
    {
        switch (_result) do
        {
            // Row 3: ESCORT/SUCCEEDED — micro trust gain where route is safe
            case "SUCCEEDED": { _dW = 1.0; };
            // Row 4: ESCORT/FAILED   — fear index and mild R pressure in impacted district
            case "FAILED":    { _dR = 2.0; _dW = -1.0; };
        };
    };

    case "IED":
    {
        switch (_result) do
        {
            // Row 5: IED/SUCCEEDED — clean interdiction: security restored, trust rebuilt
            case "SUCCEEDED": { _dW = 2.0; _dR = -2.0; _dG = 1.5; };
            // Row 6: IED/FAILED   — detonation: civilian trauma, fear spike, governance hit
            case "FAILED":    { _dW = -3.0; _dR = 3.0; _dG = -1.5; };
        };
    };

    case "RAID":
    {
        switch (_result) do
        {
            // Row 7: RAID/SUCCEEDED — lawful clean raid: positive if detention handled correctly
            case "SUCCEEDED": { _dW = 2.0; _dR = -1.5; _dG = 1.5; };
            // Row 8: RAID/FAILED   — fear pressure and anti-cooperation penalty
            case "FAILED":    { _dW = -3.0; _dR = 2.5; };
        };
    };

    case "DEFEND":
    {
        switch (_result) do
        {
            // Row 9: DEFEND/SUCCEEDED — LATER: no delta yet (deferred until telemetry added)
            case "SUCCEEDED": {};
            // Row 10: DEFEND/FAILED  — negative security sentiment delta + fear spike
            case "FAILED":    { _dW = -2.5; _dR = 3.0; _dG = -1.0; };
        };
    };

    case "QRF":
    {
        switch (_result) do
        {
            // Row 11: QRF/SUCCEEDED — LATER: no delta yet (deferred until objective telemetry added)
            case "SUCCEEDED": {};
            // Row 12: QRF/FAILED   — trust/legitimacy loss + fear increase in primary district
            case "FAILED":    { _dW = -2.5; _dG = -1.5; _dR = 2.5; };
        };
    };

    case "PATROL":
    {
        switch (_result) do
        {
            // Row 13: PATROL/SUCCEEDED — civ-interaction quality into W/G drift
            case "SUCCEEDED": { _dW = 1.5; _dG = 1.0; };
            // Row 14: PATROL/FAILED   — small W/G penalty; avoid punitive cascade
            case "FAILED":    { _dW = -1.0; _dG = -0.5; };
        };
    };

    case "RECON":
    {
        switch (_result) do
        {
            // Row 15: RECON/SUCCEEDED — district confidence + cooperation boost
            case "SUCCEEDED": { _dW = 1.0; _dG = 0.5; };
            // Row 16: RECON/FAILED   — cooperation score loss + fear increase
            case "FAILED":    { _dW = -2.0; _dR = 1.5; };
        };
    };

    case "CIVIL":
    {
        switch (_result) do
        {
            // Row 17: CIVIL/SUCCEEDED — full CIVSUB delta: trust and legitimacy gains, R reduction
            case "SUCCEEDED": { _dW = 2.0; _dR = -1.0; _dG = 1.5; };
            // Row 18: CIVIL/FAILED   — strong W/G penalties; legitimacy damage with population
            case "FAILED":    { _dW = -4.0; _dG = -2.5; _dR = 2.0; };
        };
    };

    case "CHECKPOINT":
    {
        switch (_result) do
        {
            // Row 19: CHECKPOINT/SUCCEEDED — checkpoint fairness dividend: trust and legitimacy
            case "SUCCEEDED": { _dW = 1.5; _dG = 1.0; };
            // Row 20: CHECKPOINT/FAILED   — fear increase + trust reduction; attach mitigation hint
            case "FAILED":    { _dW = -2.0; _dR = 2.5; };
        };
    };

    default {};
};

// LATER rows (and unrecognized types) produce zero deltas — log and exit without applying
if (_dW == 0 && { _dR == 0 } && { _dG == 0 }) exitWith
{
    diag_log format ["[CIVSUB][INCIDENT] ApplyOutcomeDelta no-op did=%1 type=%2 result=%3 zone=%4",
        _districtId, _incidentType, _result, _zone];
    false
};

// Build the influence delta map
private _hmCreate = compile "params ['_a']; createHashMapFromArray _a";
private _influenceDelta = [[["W", _dW], ["R", _dR], ["G", _dG]]] call _hmCreate;

// Build the full delta bundle via civsubBundleMake for contract compliance
private _bundle = [_districtId, [], "INCIDENT", format ["INCIDENT_%1_%2", _incidentType, _result],
    createHashMap, [], _influenceDelta] call ARC_fnc_civsubBundleMake;

if (!(_bundle isEqualType createHashMap) || { count _bundle == 0 }) exitWith
{
    diag_log format ["[CIVSUB][WARN] ApplyOutcomeDelta bundle build failed did=%1 type=%2 result=%3",
        _districtId, _incidentType, _result];
    false
};

// Apply the influence deltas to the district
[_bundle] call ARC_fnc_civsubDeltaApplyToDistrict;

diag_log format ["[CIVSUB][INCIDENT] ApplyOutcomeDelta applied did=%1 type=%2 result=%3 dW=%4 dR=%5 dG=%6 zone=%7",
    _districtId, _incidentType, _result, _dW, _dR, _dG, _zone];

true
