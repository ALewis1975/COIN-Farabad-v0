# intelBroadcast sync check (repo -> Arma profile mission)

Use this before launching Arma when debugging `fn_intelBroadcast.sqf` runtime errors.

## 1) Sync mission folder into Arma profile path

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\sync_mission_to_arma_profile.ps1 `
  -RepoMissionPath "C:\path\to\COIN-Farabad-v0" `
  -ArmaMissionPath "C:\Users\<user>\OneDrive\Documents\Arma 3 - Other Profiles\<profile>\missions\COIN_Farabad_v0.Farabad"
```

The script mirrors the repo mission tree into the Arma profile mission directory and then verifies SHA256 parity of:

- `functions/core/fn_intelBroadcast.sqf`

## 2) Launch mission and verify stamp in RPT

Search RPT for:

- `[ARC][intelBroadcast] build=`

This line comes from `functions/core/fn_intelBroadcast.sqf` and confirms the running mission copy includes the current build stamp path.

## 3) Validate `_v` error is gone

Search RPT for:

- `Undefined variable in expression: _v`
- `fn_intelBroadcast.sqf`

Expected result after sync and run: **zero occurrences** of `Undefined variable in expression: _v` tied to `fn_intelBroadcast.sqf`.
