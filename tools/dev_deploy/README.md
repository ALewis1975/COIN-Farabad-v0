# tools/dev_deploy

Deployment helpers for the Armahosts Windows dedicated server. They require a
clean Git clone, an unpacked Arma mission destination, PowerShell 5+, and Git.

> **OneDrive warning:** pause or disable OneDrive sync for both the repository
> and mission runtime folders. OneDrive can restore stale mission files after a
> successful Git merge or deployment.

## Clone once

```powershell
.\clone.ps1 -RepoUrl https://github.com/ALewis1975/COIN-Farabad-v0.git `
             -RepoPath C:\farabad\repo -Branch main
```

## Deploy an exact candidate

```powershell
.\deploy.ps1 -RepoPath C:\farabad\repo `
              -ArmaMissionPath "C:\Users\svc\Documents\Arma 3 - Other Profiles\Arma3Server\mpmissions\COIN_Farabad_v0.Farabad" `
              -Branch main -ModPresetId "BlackRock_Mods_2026_June"
```

Deployment refuses a dirty repository, mirrors the mission, SHA-256 verifies
all copied mission files, and then stamps only the **deployed copy** of
`initServer.sqf`. The repository file is not modified. It writes
`ARC_DeploymentManifest.json` with the full commit SHA, branch, UTC deployment
time, mod-preset ID, source remote, clean-state flag, and source/deployed
`initServer.sqf` hashes. A final full-tree verification allows only the stamped
`initServer.sqf` and deployment manifest to differ from the repository.

Expected RPT breadcrumb:

```text
[ARC][BUILD] COIN_Farabad_v0.Farabad|branch=main|builtUtc=...|sha=...|mod=BlackRock_Mods_2026_June
```

## Verify without copying

Run before each playtest, after unexplained behavior, and before trusting an RPT:

```powershell
.\verify.ps1 -RepoPath C:\farabad\repo `
              -ArmaMissionPath "C:\Users\svc\Documents\Arma 3 - Other Profiles\Arma3Server\mpmissions\COIN_Farabad_v0.Farabad"
```

Verification fails if repository HEAD/branch differs from the manifest, the
repository is dirty, any mission file is missing/changed/unexpected, or the
build stamp and stamped `initServer.sqf` hash no longer match. Restore the
candidate, redeploy, and verify again before investigating gameplay code.

## Ten-minute smoke check

1. Deploy and confirm `DEPLOY OK`.
2. Run `verify.ps1` and confirm `VERIFY OK`.
3. Start the dedicated server and confirm the first `[ARC][BUILD]` line matches
   the manifest SHA, branch, UTC timestamp, and mod-preset ID.
4. Stop the server and rerun `verify.ps1` to detect runtime-folder drift.

## Live RPT tail

```powershell
.\tail.ps1 -RptPath "C:\Users\svc\AppData\Local\Arma 3\ArmA3Server_x64_*.rpt"
```

The tail helper filters security denials, script errors, and generic errors.
Use `enable_dual_write.sqf` for the FARABAD logger sink; see
`docs/qa/FARABAD_Logger_Dual_Write_Runbook.md`.
