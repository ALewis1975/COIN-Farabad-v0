/*
    ARC_fnc_civsubBubbleGetPlayers

    Returns a filtered list of players to consider for "bubble" evaluation.
*/

if (!isServer) exitWith {[]};

(allPlayers select { alive _x })
