# Tick Cadence Review (server systems)

This review inventories the recurring server-side tick loops that drive Farabad
gameplay and assesses their interval against server performance and gameplay
feel. It complements `docs/perf/Console_Polling_and_Cadence_Review.md`, which
covers the client-side console/UI polling loops.

## Key distinction: self-scaling vs. fixed-work loops

Before tuning any interval, classify the loop:

- **Probability-scaled loops** convert an *hourly* rate to a per-tick
  probability via `p_tick = 1 - (1 - p_hour)^(interval/3600)`
  (`functions/civsub/fn_civsubProbHourToTick.sqf`). Changing the interval does
  **not** change the long-run events-per-hour — only timing granularity and
  jitter. These are cheap and safe to relax.
- **Fixed-work / fixed-effect loops** apply a constant effect or do constant
  work each run (e.g. influence decay, civilian cap enforcement). Changing the
  interval **does** change behavior, not just CPU cost.

## Inventory and assessment

| System | Variable (default) | File | Self-scaling? | Assessment |
|---|---|---|---|---|
| CIVSUB main tick | `civsub_v1_tick_s` (60) | `functions/civsub/fn_civsubInitServer.sqf`, `fn_civsubTick.sqf` | **No** | Applies fixed-fraction district decay + republishes district UI snapshots. Cheap CPU. Raising it slows decay (decay constants are per-tick, not time-scaled) and doubles UI freshness window (`2 * civsub_v1_tick_s`). **Left at 60** to preserve balance; would require decay-constant compensation to raise. |
| CIVSUB sampler | `civsub_v1_civ_tick_s` (20 → **30**) | `fn_civsubCivSamplerInit.sqf`, `fn_civsubCivSamplerTick.sqf` | No | Heaviest of the CIVSUB loops: scans players, recomputes active districts, spawns/cleans civilians to caps. **Raised 20 → 30** for CPU headroom. Tradeoff: civilian population reacts to player movement up to ~30 s later. Do not exceed ~45 s or town population feels poppy/laggy. |
| CIVSUB scheduler | `civsub_v1_scheduler_s` (120 → **240**) | `fn_civsubSchedulerTick.sqf`, `fn_civsubProbHourToTick.sqf` | **Yes** | Drives ambient leads / rumors / reactive contacts. Self-scaling, so **240 preserves events-per-hour exactly**; only timing granularity coarsens (acceptable since leads/attacks are capped ≤1/hr). **Raised 120 → 240**, halving loop cost. Bounds assert allows `[30 .. 86400]`. |
| CIVSUB traffic | `civsub_v1_traffic_tick_s` (5) | `fn_civsubTrafficTick.sqf` | Yes (per-tick spawn budget) | Already relaxed 2 → 5 in a prior pass (the 498-line tick was too aggressive at 2 s). 5 s is acceptable; 8–10 s is a future option if more headroom is needed. **Left at 5.** |
| CIVSUB locnpc | `civsub_v1_locnpc_tick_s` (10) | `fn_civsubLocNpcTick.sqf` | Partial | Modest cost. **Left at 10.** |
| Airbase | `airbase_v1_tick_s` (2) | `functions/ambiance/fn_airbaseTick.sqf` | **Yes** (departure/arrival probabilities scale with `_tickS`) | ⚠️ Intentionally **left at 2**. Per the prior tick audit, changing this alters expected flight cadence because per-tick probabilities are derived from `_tickS`. Do not raise without re-deriving flight-probability constants. |
| Site population | `ARC_sitePopTickIntervalSec` (30, clamped 10..120) | `functions/sitepop/fn_sitePopTick.sqf` | n/a | Already coarse and tunable. **Left at 30.** |
| Company command | `ARC_companyCommandTickIntervalSec` (120) | `fn_companyCommandTick.sqf` | n/a | Coarse already. **Left at 120.** |
| Company virtual ops | `ARC_companyVirtualOpsTickIntervalSec` (150) | `fn_companyCommandVirtualOpsTick.sqf` | n/a | Coarse already. **Left at 150.** |
| Incident loop | `sleep 60` (10 during pause) | `fn_incidentLoop.sqf` | Adaptive | Low risk. **Unchanged.** |
| Exec loop | `sleep 5` | `fn_execLoop.sqf` | No | Drives active-incident responsiveness; cadence doc suggests future adaptive 5 s active / 10–15 s idle. **Unchanged.** |
| Incident watchdog | `ARC_wd_tickSeconds` (30) | `fn_incidentWatchdogLoop.sqf` | No | Safety net. **Unchanged.** |
| IED civ snapshot | `ARC_iedCivSnapshotIntervalSec` (10) | `fn_execTickActive.sqf` | No | Fine. **Unchanged.** |
| Intel metrics | `ARC_metricsIntervalSec` (900) | `fn_intelMetricsTick.sqf` | No | Already very coarse. **Unchanged.** |
| World-time broadcast | `ARC_worldTime_broadcastIntervalSec` (30) | `initServer.sqf`, `fn_govStatsScheduler.sqf` | No | Network publish cadence; fine. **Unchanged.** |

## Changes applied in this pass

1. `civsub_v1_scheduler_s`: **120 → 240** (`initServer.sqf`). Self-scaling loop;
   no change to events-per-hour, halves scheduler loop cost.
2. `civsub_v1_civ_tick_s`: **20 → 30** (`initServer.sqf`). Reduces the heaviest
   CIVSUB loop's frequency for CPU headroom; mild increase in civilian
   population reaction latency.

## Explicitly NOT changed (and why)

- **`civsub_v1_tick_s` (main tick, 60 s):** decay is applied as a fixed fraction
  per tick (`fn_civsubDistrictsApplyDecay.sqf`), so raising the interval changes
  balance. Would require doubling decay constants to keep current pacing.
- **`airbase_v1_tick_s` (2 s):** departure/arrival probabilities are derived
  from the tick length; raising it changes flight cadence.

## Validation

Static only in this environment (Arma 3 runtime unavailable). Runtime cadence
behavior (scheduler emission rate, civilian population responsiveness) must be
confirmed on a dedicated-server smoke test. See `tests/TEST-LOG.md`.
