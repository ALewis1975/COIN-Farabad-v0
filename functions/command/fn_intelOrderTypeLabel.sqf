/*
    ARC_fnc_intelOrderTypeLabel

    Map an internal TOC order type to the operator-facing display label
    surfaced on the Farabad console and client order prompts.

    The stored order-type vocabulary (tocOrders field 3, ARC_pub_orders field 3)
    keeps "LEAD" as the internal kind for what operators issue as a PROCEED
    frago (see ARC_fnc_intelOrderIssue, which normalises PROCEED -> LEAD). This
    helper centralises the display wording so the console reads PROCEED without
    changing the internal type used by order logic.

    Params:
      0: STRING orderType (internal kind, e.g. RTB|HOLD|LEAD|STANDBY)

    Returns:
      STRING operator-facing display label (upper-cased; LEAD -> PROCEED).
*/

params [["_orderType", ""]];
if (!(_orderType isEqualType "")) then { _orderType = ""; };
_orderType = toUpper _orderType;

switch (_orderType) do
{
    case "LEAD": { "PROCEED" };
    default { _orderType };
};
