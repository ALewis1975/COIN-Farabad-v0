/*
    CfgRemoteExec — Whitelist-only RemoteExec policy.

    mode = 1: whitelist only (deny by default).
    jip  = 0: deny JIP replay by default; override per entry.

    Ref: https://community.bistudio.com/wiki/Arma_3:CfgRemoteExec
    Plan: docs/security/RemoteExec_Hardening_Plan.md
*/

class CfgRemoteExec
{
    class Functions
    {
        mode = 1;
        jip  = 0;

        // ── Client → Server (target=2) ──────────────────────────────────

        // CIVSUB contact/interact RPCs
        class ARC_fnc_civsubContactReqAction       { allowedTargets = 2; };
        class ARC_fnc_civsubContactReqSnapshot      { allowedTargets = 2; };
        class ARC_fnc_civsubInteractCheckPapers     { allowedTargets = 2; };
        class ARC_fnc_civsubInteractDetain          { allowedTargets = 2; };
        class ARC_fnc_civsubInteractEndSession      { allowedTargets = 2; };
        class ARC_fnc_civsubInteractHandoffSheriff  { allowedTargets = 2; };
        class ARC_fnc_civsubInteractOrderStop       { allowedTargets = 2; };
        class ARC_fnc_civsubInteractRelease         { allowedTargets = 2; };
        class ARC_fnc_civsubInteractShowPapers      { allowedTargets = 2; };
        class ARC_fnc_civsubRunMdtByNetId           { allowedTargets = 2; };

        // Command/intel RPCs
        class ARC_fnc_intelOrderAccept              { allowedTargets = 2; };
        class ARC_fnc_intelOrderCompleteRtbEpw      { allowedTargets = 2; };
        class ARC_fnc_intelOrderCompleteRtbIntel    { allowedTargets = 2; };
        class ARC_fnc_intelQueueDecide              { allowedTargets = 2; };
        class ARC_fnc_intelQueueSubmit              { allowedTargets = 2; };
        class ARC_fnc_intelTocIssueOrder            { allowedTargets = 2; };

        // Core / TOC RPCs
        class ARC_fnc_execObjectiveComplete         { allowedTargets = 2; };
        class ARC_fnc_publicBroadcastState          { allowedTargets = 2; };
        class ARC_fnc_tocReceiveSitrep              { allowedTargets = 2; };
        class ARC_fnc_tocRequestAcceptIncident      { allowedTargets = 2; };
        class ARC_fnc_tocRequestCivsubReset         { allowedTargets = 2; };
        class ARC_fnc_tocRequestCivsubSave          { allowedTargets = 2; };
        class ARC_fnc_tocRequestCloseIncident       { allowedTargets = 2; };
        class ARC_fnc_tocRequestCloseoutAndOrder    { allowedTargets = 2; };
        class ARC_fnc_tocRequestForceIncident       { allowedTargets = 2; };
        class ARC_fnc_tocRequestLogIntel            { allowedTargets = 2; };
        class ARC_fnc_tocRequestNextIncident        { allowedTargets = 2; };
        class ARC_fnc_tocRequestRebuildActive       { allowedTargets = 2; };
        class ARC_fnc_tocRequestRefreshIntel        { allowedTargets = 2; };
        class ARC_fnc_tocRequestResetAll            { allowedTargets = 2; };
        class ARC_fnc_tocRequestSave                { allowedTargets = 2; };

        // IED / VBIED RPCs
        class ARC_fnc_iedCollectEvidence            { allowedTargets = 2; };
        class ARC_fnc_iedServerDetonate             { allowedTargets = 2; };
        class ARC_fnc_vbiedServerDetonate           { allowedTargets = 2; };

        // CASREQ RPCs
        class ARC_fnc_casreqOpen                    { allowedTargets = 2; };
        class ARC_fnc_casreqDecide                  { allowedTargets = 2; };
        class ARC_fnc_casreqExecute                 { allowedTargets = 2; };
        class ARC_fnc_casreqClose                   { allowedTargets = 2; };

        // Dev / admin RPCs
        class ARC_fnc_devCompileAuditServer         { allowedTargets = 2; };
        class ARC_fnc_devDiagnosticsSnapshot        { allowedTargets = 2; };
        class ARC_fnc_devToggleDebugMode            { allowedTargets = 2; };
        class ARC_fnc_uiConsoleQAAuditServer        { allowedTargets = 2; };
        class ARC_fnc_uiCoverageAuditServer         { allowedTargets = 2; };

        // ── Server → Client ─────────────────────────────────────────────

        // Ephemeral / targeted (non-JIP)
        class ARC_fnc_airbaseDiaryUpdate                   { allowedTargets = 0; };
        class ARC_fnc_briefingHardResetClient              { allowedTargets = 0; };
        class ARC_fnc_civsubClientMessage                  { allowedTargets = 0; };
        class ARC_fnc_civsubClientShowIdCard                { allowedTargets = 0; };
        class ARC_fnc_civsubContactClientReceiveResult     { allowedTargets = 0; };
        class ARC_fnc_civsubContactClientReceiveSnapshot   { allowedTargets = 0; };
        class ARC_fnc_clientHint                           { allowedTargets = 0; };
        class ARC_fnc_clientPurgeArcTasks                  { allowedTargets = 0; };
        class ARC_fnc_clientSetCurrentTask                 { allowedTargets = 0; };
        class ARC_fnc_clientToast                          { allowedTargets = 0; };
        class ARC_fnc_devDiagnosticsClientReceive          { allowedTargets = 0; };
        class ARC_fnc_intelClientNotify                    { allowedTargets = 0; };
        class ARC_fnc_tocInitPlayer                        { allowedTargets = 0; };
        class ARC_fnc_uiConsoleCompileAuditClientReceive   { allowedTargets = 0; };
        class ARC_fnc_uiConsoleOpsActionStatus             { allowedTargets = 0; };
        class ARC_fnc_uiConsoleQAAuditClientReceive        { allowedTargets = 0; };

        // Persistent / JIP-critical (late joiners need these actions)
        class ARC_fnc_civsubCivAddAceActions        { allowedTargets = 0; jip = 1; };
        class ARC_fnc_civsubCivAddContactActions    { allowedTargets = 0; jip = 1; };
        class ARC_fnc_clientAddObjectiveAction      { allowedTargets = 0; jip = 1; };
        class ARC_fnc_iedClientAddEvidenceAction    { allowedTargets = 0; jip = 1; };
        class ARC_fnc_iedClientEnableEvidenceLogistics { allowedTargets = 0; jip = 1; };
    };

    class Commands
    {
        mode = 1;
        jip  = 0;

        class BIS_fnc_holdActionAdd     { allowedTargets = 0; jip = 1; };
        class BIS_fnc_holdActionRemove  { allowedTargets = 0; };
        class disableAI                 { allowedTargets = 0; };
        class enableAudioFeature        { allowedTargets = 0; };
        class forceWalk                 { allowedTargets = 0; };
        class limitSpeed                { allowedTargets = 0; };
        class playMoveNow               { allowedTargets = 0; };
        class setPhysicsCollisionFlag   { allowedTargets = 0; };
        class setPilotLight             { allowedTargets = 0; };
        class setUnitTrait              { allowedTargets = 0; };
        class switchMove                { allowedTargets = 0; };
        class systemChat                { allowedTargets = 0; };
    };
};
