class CfgFunctions
{
    class ARC
    {
        tag = "ARC";

        class Core
        {
            file = "functions\core";

            class bootstrapServer {};

            class log {};
            class farabadLog {};
            class farabadInfo {};
            class farabadWarn {};
            class farabadError {};

            class stateInit {};
            class stateLoad {};
            class stateSave {};
            class stateGet {};
            class stateSet {};
            class stateSetGet {};  // legacy compatibility wrapper

            class incidentLoop {};
            class incidentTick {};
            class incidentCreate {};
            class incidentClose {};
            class incidentMarkReadyToClose {};

            // Incident watchdog (stall detection / close-ready suggestions)
            class incidentWatchdog {};
            class incidentWatchdogLoop {};


            // Incident execution / end states
            class execLoop {};
            class execInitActive {};
            class execTickActive {};
            class execCleanupActive {};
            class execObjectiveComplete {};
            class iedQueueDetonationResponse {};
            class iedHandleDetonation {};
            // Convoys live under Logistics

            // Group naming / designations
            class groupSetDesignation {};

            // Roles / permissions
            class rolesHasGroupIdToken {};
            class rolesGetTag {};
            class rolesIsAuthorized {};
            class rolesFormatUnit {};
            class rolesIsTocS2 {};
            class rolesIsTocS3 {};
            class rolesIsTocCommand {};
            class rolesCanApproveQueue {};
            class rpcValidateSender {};
            class airbaseTowerAuthorize {};

            // Deferred cleanup (despawn when players leave area)
            class cleanupRegister {};
            class cleanupTick {};

            // Objective interaction helpers
            class clientAddObjectiveAction {};
            class clientObjectiveInteract {};

            class taskCreateIncident {};
            class taskRehydrateActive {};

            // User-friendly tasks + intel feed
            class publicBroadcastState {};
            class intelLog {};
            class intelCreateMarker {};
            class intelBroadcast {};

            class orbatPickTasking {};
            class taskBuildDescription {};
            class taskUpdateActiveDescription {};

            // Leads
            class leadCreate {};
            class leadPrune {};
            class leadConsumeNext {};
            class leadConsumeById {};
            class leadGenerateFromIncident {};
            class leadBroadcast {};

            // TOC backlog (approved lead triage)
            class tocBacklogEnqueue {};
            class tocBacklogPopNext {};


            // Threads / cases
            class taskEnsureThreadParent {};
            class threadFindOrCreate {};
            class threadResolveDistrictId {};
            class threadNormalizeRecord {};
            class threadOnIncidentClosed {};
            class threadTickAll {};
            class threadEmitDistrictPressure {};
            class threadMaybeCreateCommandNodeLead {};
            class threadBroadcast {};
            class threadRehydrateParents {};

            // Briefing / UI helpers
            class briefingInitClient {};
            class briefingUpdateClient {};
            class briefingHardResetClient {};
            class uiOpenOpsScreen {};
            class uiOpenIntelScreen {};
            class uiOpenSitrepScreen {};
            class uiTaskTimersInitClient {};
            class clientBeginIntelMapClick {};
            class clientIntelPrompt {};
            class clientSitrepPrompt {};
            class clientLogCursorSighting {};
            class clientHint {};
            class clientToast {};
            class clientSetCurrentTask {};

            // UI coverage audit (server)
            class uiCoverageAuditServer {};
            class uiConsoleQAAuditServer {};

            // Dev: compile audit (server) to surface SQF syntax errors early
            class devCompileAuditServer {};

            // Field SITREPs (player -> TOC)
            class clientCanSendSitrep {};
            class clientSendSitrep {};
            class tocReceiveSitrep {};

            // TOC actions
            class tocInitPlayer {};
            class tocRequestNextIncident {};
            class tocRequestAcceptIncident {};
            class tocRequestForceIncident {};
            class tocRequestRebuildActive {};
            class tocRequestCloseIncident {};
            class tocRequestCloseoutAndOrder {};
            class tocRequestSave {};

            class tocRequestCivsubSave {};
            class tocRequestCivsubReset {};
            class tocRequestLogIntel {};
            class tocRequestRefreshIntel {};
            class tocRequestShowLeads {};
            class tocShowLatestIntel {};
            class tocShowLeadPoolLocal {};
            class tocShowThreadsLocal {};
            class resetAll {};
            class tocRequestResetAll {};
            class tocRequestAirbaseResetControlState {};
            class clientPurgeArcTasks {};

            // Guardpost Script
            class guardPost {};
        };

        class World
        {
            file = "functions\world";

            class worldInit {};
            class worldResolveMarker {};

            class worldGetZoneForPos {};
            class worldGetZoneForMarker {};

            class worldPickEnterablePosNear {};
            class worldPickConvoySpawnAndLink {};
            class worldRegisterLocations {};
        };



        class IED
        {
            file = "functions\ied";

            class iedPickSite {};
            class iedSpawnTick {};
            class iedServerDetonate {};
            class iedEnsureEvidence {};
            class iedClientAddEvidenceAction {};
            class iedCollectEvidence {};

            // Phase 4: TOC permission + disposition actions
            class iedDispoBroadcast {};
            class iedClientHasEodApproval {};
            class iedClientExecuteDisposition {};
    
    		// Phase 3 (VBIED v1)
	    	class vbiedPickSite {};
		    class vbiedSpawnTick {};
		    class vbiedServerDetonate {};

            // Phase 5: disposal logistics
            class iedClientEnableEvidenceLogistics {};
            class iedServerCheckDisposal {};
            class vbiedServerOnDestroyed {};
        };

        // New: Intel layer functions live here (separate from Core/World)
        class Intel
        {
            file = "functions\intel";

            class intelInit {};
            class intelInitServer {};
            class intelInitClient {};

            class intelMetricsTick {};
        };

        class CIVSUB
        {
            file = "functions\civsub";

            // Phase 0-2: district state + decay tick + delta bundle emitter + persistence (server authoritative)
            class civsubInitServer {};
            class civsubTick {};
            class civsubEmitDelta {};

            class civsubDistrictsCreateDefaults {};
            class civsubDistrictSeedProfile {};
            class civsubDistrictsApplyDecay {};
            class civsubDistrictsClamp {};
            class civsubDistrictsGetById {};

            class civsubDeltaBuildEnvelope {};
            class civsubDeltaApplyToDistrict {};
            class civsubDeltaValidate {};

            // Phase 5.5: bundle normalization helpers
            class civsubBundleMake {};
            class civsubBundleToPairs {};

            class civsubPersistLoad {};
            class civsubPersistSave {};
            class civsubPersistMigrateIfNeeded {};
            class civsubPersistReset {};
            class civsubSitrepAnnexBuild {};

            class civsubDebugSnapshot {};
            class civsubDebugLog {};

            class civsubNow {};
            class civsubUuid {};
            class civsubMathClamp01 {};

            // Phase 3: identity layer + crime DB (touched-only)
            class civsubIdentityInit {};
            class civsubIdentityTouch {};
            class civsubIdentityGet {};
            class civsubIdentitySet {};
            class civsubIdentityEvictIfNeeded {};
            class civsubIdentityGenerateUid {};
            class civsubIdentityGenerateProfile {};

            class civsubCrimeDbInit {};
            class civsubCrimeDbSeed {};
            class civsubCrimeDbPickPoi {};
            class civsubCrimeDbPickPoiForDistrict {};
            class civsubCrimeDbGetById {};

            class civsubIdentityDebugSnapshot {};

            // Phase 4: physical civilian sampling (bounded, server-owned)
            class civsubCivSamplerInit {};
            class civsubCivSamplerTick {};
            class civsubCivSamplerStop {};

            class civsubBubbleGetPlayers {};
            class civsubBubbleGetActiveDistricts {};
            class civsubDistrictsFindByPos {};
            class civsubDistrictsFindByPosLocal {};

            class civsubCivSpawnInDistrict {};
            class civsubCivAssignIdentity {};
            class civsubRegisterEditorCivs {};

            // Phase 7.0: ALiVE-style contact actions (client + server)
            class civsubContactInitClient {};
            class civsubCivAddContactActions {};
            class civsubInteractOrderStop {};
            class civsubInteractEndSession {};
            class civsubContactDialogOpen {};
            class civsubContactDialogOnLoad {};
            class civsubContactDialogUpdateRightPane {};
            class civsubContactDialogOnActionSelChanged {};
            class civsubContactDialogOnQuestionSelChanged {};
            class civsubContactDialogOnUnload {};
            class civsubContactDialogExecute {};
            class civsubContactDialogHideIdOverlay {};
            class civsubContactReqSnapshot {};
            class civsubContactReqAction {};
            class civsubContactActionCheckId {};
            class civsubContactActionBackgroundCheck {};
            class civsubContactActionDetain {};
            class civsubContactActionRelease {};
            class civsubContactActionGiveFood {};
            class civsubContactActionGiveWater {};
            class civsubContactActionQuestion {};
            class civsubInteractUpdateHeaderStats {};
            class civsubContactClientReceiveSnapshot {};
            class civsubContactClientReceiveResult {};
            // Phase 7: ACE interactions (client + server)
            class civsubCivAddAceActions {};
            class civsubClientMessage {};
            class civsubClientShowIdCard {};
            class civsubClientGetCurrentDistrictPubSnapshot {};
            class civsubInteractShowPapers {};
            class civsubInteractCheckPapers {};
            class civsubInteractDetain {};
            class civsubInteractRelease {};
            class civsubInteractHandoffSheriff {};
            class civsubRunMdtByNetId {};
            class civsubOnCivKilled {};
            class civsubCivRegisterSpawn {};
            class civsubCivDespawnUnit {};
            class civsubCivCleanupTick {};

            class civsubCivCapsCompute {};
            class civsubCivCapsEnforce {};

            class civsubCivSamplerDebugSnapshot {};

            // Phase 5: district scheduler (leads + reactive contacts)
            class civsubSchedulerInit {};
            class civsubSchedulerTick {};
            class civsubSchedulerStop {};

            class civsubScoresCompute {};
            class civsubProbLeadHour {};
            class civsubProbAttackHour {};
            class civsubIntelConfidence {};
            class civsubProbHourToTick {};
            class civsubIsDistrictActive {};

            class civsubSchedulerEmitAmbientLead {};
            class civsubSchedulerEmitReactiveContact {};
            class civsubSchedulerEmitRumor {};

            // Patch A/B: civ class pool (3CB Takistan civs) + building-first spawn placement + exclusions
            class civsubCivBuildClassPool {};
            class civsubCivFindSpawnPos {};
            class civsubSpawnCacheEnsure {};
            class civsubCivPickSpawnPos {};
            class civsubCivIsProtected {};


            // Phase 3: CIVTRAF (ambient civilian traffic)
            class civsubTrafficInit {};
            class civsubTrafficTick {};
            class civsubTrafficBuildVehiclePool {};
            class civsubTrafficPickRoadsidePos {};
            class civsubTrafficResolveSpawnCenter {};
            class civsubTrafficSpawnParked {};
            class civsubTrafficSpawnMoving {};
            class civsubTrafficDebugSnapshot {};

            // Phase 7.2: WIA handling (server)
            class civsubOnCivWia {};







        };

        class Command
        {
            file = "functions\command";

            // Queue (requests) + Orders (TOC direction)
            class intelQueueSubmit {};
            class intelQueueDecide {};
            class intelQueueBroadcast {};
            class intelQueueShowPendingLocal {};
            class intelQueuePromptDecision {};

            class intelResolveRtbDestination {};

            class intelOrderIssue {};
            class intelOrderAccept {};
            class intelOrderBroadcast {};
            class intelOrderTick {};
            class intelTocIssueOrder {};

            // Client helpers
            class intelClientNotify {};

            class intelClientCanRequestFollowOn {};
            class intelClientRequestFollowOn {};
            class intelClientCanAcceptOrder {};
            class intelClientAcceptOrder {};

            class intelClientHasAcceptedRtbIntel {};
            class intelClientHasAcceptedRtbEpw {};
            class intelClientCanDebriefIntelHere {};
            class intelClientCanProcessEpwHere {};
            class intelClientDebriefIntel {};
            class intelClientProcessEpw {};

            class intelOrderCompleteRtbIntel {};
            class intelOrderCompleteRtbEpw {};

            class intelClientBeginLeadRequestMapClick {};

            class mapClick_arm {};
            class mapClick_disarm {};
            class mapClick_onClick {};
            class mapClick_submit {};

            class intelClientTocIssueOrderPrompt {};

            // UI helpers (TOC queue manager)
            class intelUiOpenQueueManager {};
            class intelUiQueueManagerOnLoad {};
            class intelUiQueueManagerRefresh {};
            class intelUiQueueManagerUpdateDetails {};
            class intelUiQueueManagerDecideSelected {};
        };

        // Farabad Console (tablet UI)
        class UI
        {
            file = "functions\ui";

            class uiConsoleInitClient {};
            class uiConsoleCanOpen {};
            class uiConsoleOpen {};
            class uiConsoleApplyLayout {};
            class uiConsoleOnLoad {};
            class uiConsoleOnUnload {};
            class uiConsoleSelectTab {};
            class uiConsoleRefresh {};
            class uiConsoleQAAuditClientReceive {};
            class uiConsoleCompileAuditClientReceive {};
            class uiNsWarnTypeMismatchOnce {};
            class uiNsGetString {};
            class uiNsGetArray {};
            class uiNsGetBool {};

            // UI09 tab painters
            class uiConsoleDashboardPaint {};
            class uiConsoleBoardsPaint {};
            class uiConsoleIntelPaint {};
            class uiConsoleOpsPaint {};
            class uiConsoleHandoffPaint {};
            class uiConsoleCommandPaint {};
            class uiConsoleTocQueuePaint {};
            class uiConsoleHQPaint {};
            class uiConsoleAirPaint {};
            class uiConsoleOpsSelChanged {};

            // Tab-aware button routing
            class uiConsoleClickPrimary {};
            class uiConsoleClickSecondary {};

            // Actions (invoked by router)
            class uiConsoleActionIntelDebrief {};
            class uiConsoleActionEpwProcess {};

            // Intel (feed + manual logging)
            class uiConsoleActionIntelLog {};
            class uiConsoleActionIntelRefresh {};

            // SITREP + Follow-on
            class uiConsoleActionSendSitrep {};
            class uiConsoleActionOpsPrimary {};
            class uiConsoleOpsActionStatus {};
            class uiConsoleActionRequestFollowOn {};
            class uiConsoleActionRequestEodDispo {};
            class uiFollowOnPrompt {};
            class uiEodDispoPrompt {};
            // Follow-on structured dialog (UI10)
            class uiFollowOnDialogOnLoad {};
            class uiFollowOnDialogUpdate {};
            class uiFollowOnDialogSubmit {};
            class uiFollowOnDialogCancel {};


            // TOC
            class uiConsoleActionRequestNextIncident {};
            class uiConsoleActionTocSecondary {};

            class uiConsoleActionOpenCloseout {};

            class uiConsoleActionAcceptIncident {};
            class uiConsoleActionAcceptOrder {};
            class uiConsoleActionOpenTocQueue {};
            class uiConsoleActionHQPrimary {};
            class uiConsoleActionAirPrimary {};
            class uiConsoleActionAirSecondary {};

            // Structured SITREP dialog helpers (UI09)
            class uiSitrepDialogOnLoad {};
            class uiSitrepDialogSubmit {};
            class uiSitrepDialogCancel {};

            // UI08: Workboard + S2 completeness + coverage helpers
            class uiConsoleIsAtStation {};
            class uiConsoleMainListSelChanged {};
            class uiConsoleWorkboardPaint {};
            class uiConsoleS2Paint {};
            class uiConsoleActionWorkboardPrimary {};
            class uiConsoleActionWorkboardSecondary {};
            class uiConsoleActionS2Primary {};
            class uiConsoleActionCivRunLastId {};
            class uiConsoleActionS2Secondary {};

            class uiIncidentGetNextActions {};
            class consoleThemeGet {};

        };

        class Logistics
        {
            file = "functions\logistics";
            class execSpawnConvoy {};
            class execTickConvoy {};
        };

        // Reserved layers (future expansion)
        
        class Threat
        {
            file = "functions\threat";

            class threatInit {};
            class threatCreateFromTask {};
            class threatUpdateState {};
            class threatOnAOActivated {};
            class threatOnIncidentClosed {};
            class threatDebugSnapshot {};
            class threatGetCleanupLabelForTask {};
            class threatMarkCleanedByLabel {};
        };

class Ops
        {
            file = "functions\ops";

            class opsPatrolOnActivate {};
            class opsSpawnComposition {};
            class opsSpawnLeadComposition {};
            class opsSpawnLocalSupport {};
            class opsSpawnRouteSupport {};
        };

        class Medical
        {
            file = "functions\medical";
        };

        class Ambiance
        {
            file = "functions\ambiance";

            // AIRBASESUB (Airbase ambience + schedule scaffold)
            // Server-only entrypoint; waits for ARC bootstrap/state load before starting.
            class airbasePostInit { postInit = 1; };
            class airbaseInit {};
            class airbaseTick {};

            // Fixed-wing departures / towing
            class airbasePlaneDepart {};
            class airbaseAttackTowDepart {};

            // Fixed-wing arrivals
            class airbaseSpawnArrival {};
            
            // Asset restock / return restore
            class airbaseRestoreParkedAsset {};

            // Client diary updates
            class airbaseDiaryUpdate {};

            // Ambient crew behaviors (BIS ambient anim only)
            class airbaseCrewIdleStart {};
            class airbaseCrewIdleStop {};

            // Perimeter patrol ambience
            class airbaseSecurityInit {};
            class airbaseSecurityPatrol {};

            // Airbase tower control RPCs (server authority + client wrappers)
            class airbaseRequestHoldDepartures {};
            class airbaseRequestReleaseDepartures {};
            class airbaseRequestPrioritizeFlight {};
            class airbaseRequestCancelQueuedFlight {};
            class airbaseAdminResetControlState {};

            // Queue/record mutation helpers
            class airbaseQueueMoveToFront {};
            class airbaseQueueRemoveByFid {};
            class airbaseRecordSetQueuedStatus {};

            // Runway lock helpers
            class airbaseRunwayLockSweep {};
            class airbaseRunwayLockReserve {};
            class airbaseRunwayLockOccupy {};
            class airbaseRunwayLockRelease {};

            class airbaseClientRequestHoldDepartures {};
            class airbaseClientRequestReleaseDepartures {};
            class airbaseClientRequestPrioritizeFlight {};
            class airbaseClientRequestCancelQueuedFlight {};

            // Clearance request RPCs (server authority + client wrappers)
            class airbaseSubmitClearanceRequest {};
            class airbaseCancelClearanceRequest {};
            class airbaseMarkClearanceEmergency {};
            class airbaseRequestClearanceDecision {};
            class airbaseClientSubmitClearanceRequest {};
            class airbaseClientCancelClearanceRequest {};
            class airbaseClientMarkClearanceEmergency {};
            class airbaseClientRequestClearanceDecision {};

        };
    };
};
