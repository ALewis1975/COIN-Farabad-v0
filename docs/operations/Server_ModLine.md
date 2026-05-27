# Server Modline — Canonical Pin

**Status:** Stub. Track 2 of `docs/architecture/Dedicated_Server_Activation_Plan_2026-05-27.md`. To be completed by the server admin once the Armahosts launch line has been reconciled with `docs/projectFiles/Ambient_Dev_Mods_2026-04-01.html`.

## Purpose

The Dedicated/JIP Validation Matrix (`docs/qa/Dedicated_JIP_Validation_Matrix.md` §2) states that **any mod-stack change invalidates prior PASS results**. This file pins the exact, byte-canonical modline the dedicated server runs so anyone can reproduce the load order and verify that test runs are against the same stack.

Until this file is populated, runtime PASS rows in `tests/TEST-LOG.md` against the dedicated server are provisional only.

## Required fields (fill in)

```
Server: <Armahosts VPS hostname / instance id>
Server build: ArmA3Server_x64 <version + build hash>
BattlEye: <on/off; filter policy>
Region: <data center / location>

-mod= (verbatim, one entry per line for diff-ability):
  @cba_a3
  @ace
  @<...>

-serverMod=
  @<...>

ACE version:    <x.y.z>
CBA version:    <x.y.z>
3CB BAF/Factions versions: <...>
RHS GREF/USAF/AFRF/SAF/etc.: <...>
CUP Terrains/Units/Weapons/Vehicles: <...>

Server keys folder hash (SHA-256 of the `keys/` dir contents):
  <hash>

Mission .pbo (if PBO-deployed):
  name: COIN_Farabad_v0.Farabad.pbo
  sha256: <hash>
  source commit: <git short SHA>
```

## Known-noise allowlist

Lines in the dedicated RPT that are expected and should not trigger Track 2 rework — see `README.md` §134-136 ("Known RPT Noise"). Any deviation from that allowlist on a fresh-start RPT means the modline is wrong.

## Update procedure

1. Pull the modline from Armahosts control panel (Server → Launch Parameters).
2. Diff against `docs/projectFiles/Ambient_Dev_Mods_2026-04-01.html`. Drop every entry whose addon shows `Skipped loading of addon '<x>' as required addon … is not present` in the most recent RPT.
3. Drop any ACE compat pack whose parent mod is no longer on the line.
4. Update this file in the same PR that updates the launch parameters.
5. Stamp `tests/TEST-LOG.md` with a fresh "Modline-pinned" entry referencing the commit SHA of the change.
