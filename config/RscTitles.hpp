/* ARC RscTitles (HUD + lightweight overlays)
   NOTE: Do NOT use `import` here. Base UI classes are already available in mission config.
*/

class RscTitles
{
    class ARC_TaskTimerHUD
    {
        idd = -1;
        duration = 1e+011;
        fadein = 0;
        fadeout = 0;
        onLoad = "uiNamespace setVariable ['ARC_TaskTimerHUD_display', _this # 0];";
        onUnload = "uiNamespace setVariable ['ARC_TaskTimerHUD_display', displayNull];";

        class controls
        {
            class ARC_TaskTimerHUD_Text: RscStructuredText
            {
                idc = 86001;
                x = safeZoneX + safeZoneW - 0.34;
                y = safeZoneY + 0.02;
                w = 0.33;
                h = 0.18;
                size = 0.032;
                colorBackground[] = {0,0,0,0.35};
            };
        };
    };

    class ARC_CivIdCard
    {
        idd = -1;
        duration = 10;
        fadein = 0.08;
        fadeout = 0.25;
        onLoad = "uiNamespace setVariable ['ARC_CivIdCard_display', _this # 0];";
        onUnload = "uiNamespace setVariable ['ARC_CivIdCard_display', displayNull];";

        class controls
        {
            class ARC_CivIdCard_Border: RscText
            {
                idc = 86198;
                x = safeZoneX + safeZoneW * 0.33;
                y = safeZoneY + safeZoneH * 0.16;
                w = safeZoneW * 0.34;
                h = safeZoneH * 0.40;
                colorBackground[] = {0.12,0.18,0.12,0.95};
            };

            class ARC_CivIdCard_BG: RscText
            {
                idc = 86100;
                x = safeZoneX + safeZoneW * 0.332;
                y = safeZoneY + safeZoneH * 0.162;
                w = safeZoneW * 0.336;
                h = safeZoneH * 0.396;
                colorBackground[] = {0.92,0.90,0.82,0.96};
            };

            class ARC_CivIdCard_Header: RscText
            {
                idc = 86197;
                x = safeZoneX + safeZoneW * 0.332;
                y = safeZoneY + safeZoneH * 0.162;
                w = safeZoneW * 0.336;
                h = safeZoneH * 0.055;
                colorBackground[] = {0.85,0.84,0.76,0.95};
            };

            class ARC_CivIdCard_Photo: RscText
            {
                idc = 86196;
                x = safeZoneX + safeZoneW * 0.336;
                y = safeZoneY + safeZoneH * 0.225;
                w = safeZoneW * 0.08;
                h = safeZoneH * 0.11;
                colorBackground[] = {0.25,0.30,0.25,0.40};
            };

            class ARC_CivIdCard_Stamp: RscText
            {
                idc = 86195;
                x = safeZoneX + safeZoneW * 0.57;
                y = safeZoneY + safeZoneH * 0.42;
                w = safeZoneW * 0.09;
                h = safeZoneH * 0.09;
                colorBackground[] = {0.55,0.12,0.12,0.10};
            };

            class ARC_CivIdCard_Text: RscStructuredText
            {
                idc = 86101;
                x = safeZoneX + safeZoneW * 0.425;
                y = safeZoneY + safeZoneH * 0.205;
                w = safeZoneW * 0.235;
                h = safeZoneH * 0.335;
                size = 0.032;
                colorBackground[] = {0,0,0,0};
            };
        };
    };
};
