/*
    ARC_fnc_civsubPersistMigrateIfNeeded

    Ensures locked profileNamespace keys exist.

    LOCKED keys (baseline):
      FARABAD_CIVSUB_V1_STATE (string)
      FARABAD_CIVSUB_V1_VERSION (string, e.g. "1.0.0")
      FARABAD_CIVSUB_V1_CAMPAIGN_ID (string GUID)
*/

if (!isServer) exitWith {false};
if !(missionNamespace getVariable ["civsub_v1_persist", true]) exitWith {true};


private _ver = profileNamespace getVariable ["FARABAD_CIVSUB_V1_VERSION", ""];
if (_ver isEqualTo "") then
{
    profileNamespace setVariable ["FARABAD_CIVSUB_V1_VERSION", "1.0.0"];
};

private _cid = profileNamespace getVariable ["FARABAD_CIVSUB_V1_CAMPAIGN_ID", ""];
if (_cid isEqualTo "") then
{
    _cid = [] call ARC_fnc_civsubUuid;
    profileNamespace setVariable ["FARABAD_CIVSUB_V1_CAMPAIGN_ID", _cid];
};

saveProfileNamespace;
true
