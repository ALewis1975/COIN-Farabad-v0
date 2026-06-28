/*
    COIN Farabad - additive mission init.

    Keep this file minimal. Existing server/client bootstrap remains in
    initServer.sqf and initPlayerLocal.sqf; this only starts isolated systems
    that do not need to change the main bootstrap order.
*/

if (isServer) then
{
    [] execVM "scripts\uasScreen\uasScreen_serverInit.sqf";
};

if (hasInterface) then
{
    [] execVM "scripts\uasScreen\uasScreen_clientInit.sqf";
};
