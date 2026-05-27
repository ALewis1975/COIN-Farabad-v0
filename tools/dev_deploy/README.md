# tools/dev_deploy

Helpers for iterating against the Armahosts Windows dedicated server without
hand-copying files. All scripts assume:

* The repo is cloned somewhere on the VPS (e.g. `C:\farabad\repo`).
* The dedicated profile mpmissions folder is e.g.
  `C:\Users\<svc>\Documents\Arma 3 - Other Profiles\Arma3Server\mpmissions\COIN_Farabad_v0.Farabad`.
* PowerShell 5+.

## One-time

```powershell
.\clone.ps1 -RepoUrl https://github.com/ALewis1975/COIN-Farabad-v0.git `
            -RepoPath C:\farabad\repo
```

## Per-iteration

```powershell
.\deploy.ps1 -RepoPath        C:\farabad\repo `
             -ArmaMissionPath "C:\Users\svc\Documents\Arma 3 - Other Profiles\Arma3Server\mpmissions\COIN_Farabad_v0.Farabad" `
             -Branch          dev
```

`deploy.ps1` runs `git pull` then `tools/sync_mission_to_arma_profile.ps1`
which SHA-256-verifies the security-critical files
(see `tools/sync_mission_to_arma_profile.ps1` for the verified-files list).

## Live tail

```powershell
.\tail.ps1 -RptPath "C:\Users\svc\AppData\Local\Arma 3\ArmA3Server_x64_*.rpt"
```

Pre-filters to lines that matter on dedicated:
`[ARC][SEC]`, `MISSING_REMOTE_CONTEXT`, `Error in expression`, `Generic error`,
`SCRIPT`, and any `event=*_SECURITY_DENIED`.

## Enable dual-write logging

Paste `enable_dual_write.sqf` into the server admin debug console (`#login`,
debug exec) to set the FARABAD logger sink at runtime. See
`docs/qa/FARABAD_Logger_Dual_Write_Runbook.md` for full doctrine.
