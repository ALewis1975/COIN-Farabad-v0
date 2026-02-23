/*
    ARC_fnc_s1EchelonClassify

    Pure function: classify a group's ORBAT parentEchelon token into the S1
    echelon tree hierarchy.

    Params:
      0: STRING - parentEchelon (ORBAT left token from groupId, e.g. "B-2-325 AIR")
      1: STRING - callsign (optional context, currently unused)

    Returns:
      ARRAY - [topCategory, subCategory, echelonDepth, companyLetter, parentEchelonStr]
        topCategory    : one of "TF REDFALCON", "JTF FARABAD", "USAF / AIRBASE",
                         "SUPPORT / BSB", "BSTB", "AVIATION", "HOST NATION", "OTHER"
                         (8 top categories total)
        subCategory    : sub-unit grouping label (e.g. "CO B", "CO B PLT", "JTF", ...)
        echelonDepth   : 0 = BN/Category, 1 = Company/Sub, 2 = Platoon, 3 = Squad/Leaf
        companyLetter  : letter for REDFALCON groups ("A","B","C",...); "" otherwise
        parentEchelonStr: parentEchelon of the parent group (REDFALCON only); "" otherwise
*/

params [
    ["_parentEchelon", "", [""]]
];

private _pe = toUpper _parentEchelon;

// --- TF REDFALCON: any group whose parentEchelon contains "2-325" ---
// Naming pattern: [prefix-]2-325 AIR
// Prefix depth encodes echelon: "" = BN, "B-" = Company, "1-B-" = Platoon, "1-1-B-" = Squad
if ((_pe find "2-325") >= 0) exitWith {

    private _idx325 = _pe find "2-325";
    // Substring before "2-325": e.g. "B-" for "B-2-325 AIR"
    private _prefix = _pe select [0, _idx325];

    // Count hyphens in the prefix to determine echelon depth
    private _hyphenCount = 0;
    private _prefixLen = count _prefix;
    private _ci = 0;
    while { _ci < _prefixLen } do {
        if ((_prefix select [_ci, 1]) isEqualTo "-") then { _hyphenCount = _hyphenCount + 1; };
        _ci = _ci + 1;
    };

    // Extract company letter from prefix tokens (single alphabetic char)
    private _companyLetter = "";
    {
        if ((count _x) isEqualTo 1) then {
            private _up = toUpper _x;
            private _lo = toLower _x;
            if (!(_up isEqualTo _lo)) then { _companyLetter = _up; };
        };
    } forEach (_prefix splitString "-");

    // Build parent echelon string by dropping the first dash-segment
    private _parentPe = "";
    if (_hyphenCount > 0) then {
        private _parts = _parentEchelon splitString "-";
        if ((count _parts) > 1) then {
            private _tail = _parts select [1, (count _parts) - 1];
            _parentPe = _tail joinString "-";
        };
    };

    private _sub = "BN STAFF";
    if (_hyphenCount isEqualTo 1) then { _sub = format ["CO %1", _companyLetter]; };
    if (_hyphenCount isEqualTo 2) then { _sub = format ["CO %1 PLT", _companyLetter]; };
    if (_hyphenCount >= 3) then { _sub = format ["CO %1 SQD", _companyLetter]; };

    ["TF REDFALCON", _sub, _hyphenCount, _companyLetter, _parentPe]
};

// --- JTF FARABAD ---
if ((_pe find "JTF FARABAD") >= 0) exitWith {
    ["JTF FARABAD", "JTF", 0, "", ""]
};

// --- USAF / AIRBASE: 332 xxxx or 532 xxxx groups ---
if ((_pe find "332 ") >= 0 || { (_pe find "532 ") >= 0 }) exitWith {
    ["USAF / AIRBASE", _parentEchelon, 0, "", ""]
};

// --- SUPPORT / BSB: 407 BSB ---
if ((_pe find "407 BSB") >= 0) exitWith {
    ["SUPPORT / BSB", "BSB", 0, "", ""]
};

// --- BSTB: 2 BSTB (ABN) variants ---
if ((_pe find "2 BSTB") >= 0) exitWith {
    ["BSTB", _parentEchelon, 0, "", ""]
};

// --- AVIATION: CAB, EFS, EAS, EARS, EECS, ASOS, Air Cav ---
if (
    (_pe find "82 ARB") >= 0 || { (_pe find "82 AHB") >= 0 } || { (_pe find "82 GSAB") >= 0 } ||
    (_pe find " EFS") >= 0 || { (_pe find " EAS") >= 0 } || { (_pe find " EARS") >= 0 } ||
    (_pe find " EECS") >= 0 || { (_pe find "ASOS") >= 0 } || { (_pe find "17 CAV") >= 0 }
) exitWith {
    ["AVIATION", _parentEchelon, 0, "", ""]
};

// --- HOST NATION: Takistan units ---
if ((_pe find "TAKISTAN") >= 0) exitWith {
    ["HOST NATION", _parentEchelon, 0, "", ""]
};

// --- Fallback ---
["OTHER", _parentEchelon, 0, "", ""]
