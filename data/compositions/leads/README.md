# Lead Compositions

This folder holds Eden-exported compositions that represent **lead sites** (cache, safehouse, meeting point, weapons stash, etc.).

## Recommended workflow

1. Build your micro-site in Eden.
2. Run `[[anchorObject], radius, getDir anchorObject] call BIS_fnc_objectsGrabber;` in the debug console to export the composition to your clipboard.
3. Paste the clipboard output into a new `.sqf` file in this folder.
4. Spawn the composition from server-side code:

```sqf
// Server
private _posATL = [1234, 5678, 0];
private _dir = 45;
private _spawned = ["lead_cache_01", _posATL, _dir, 0, true] call ARC_fnc_opsSpawnLeadComposition;
```

Notes:

- Keep these sites small at first: 4 to 8 OPFOR and a few props.
- Prefer data here, and logic in `functions\ops\`.
