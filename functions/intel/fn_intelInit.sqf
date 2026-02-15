/*
    ARC_fnc_intelInit

    Intel layer bootstrap.

    Server:
      - Initializes intel-layer bookkeeping (TOC queue, orders, metrics sampling).
      - Publishes JIP-safe snapshots for clients.

    Client:
      - Reserved hook (client actions are added in ARC_fnc_tocInitPlayer).

    Returns:
      BOOL
*/

private _ok = true;

if (isServer) then
{
    _ok = _ok && ([] call ARC_fnc_intelInitServer);
};

if (hasInterface) then
{
    _ok = _ok && ([] call ARC_fnc_intelInitClient);
};

_ok
