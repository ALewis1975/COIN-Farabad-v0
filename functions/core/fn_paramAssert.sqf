/*
    ARC_fnc_paramAssert

    Common assertion helper for SQF params/type validation.

    Return tuple format:
      [BOOL ok, ANY normalizedValue, STRING code, STRING message]

    Supported rule kinds:
      - "ARRAY_SHAPE": options [defaultArray, minCount, maxCount, requirePairEntries]
      - "SCALAR_BOUNDS": options [defaultNumber, minValue, maxValue]
      - "NON_EMPTY_STRING": options [defaultString]
      - "OBJECT_NOT_NULL": options [defaultObject]
*/

params [
    ["_value", nil],
    ["_rule", "", [""]],
    ["_label", "value", [""]],
    ["_options", []]
];

private _ok = true;
private _norm = _value;
private _code = "ARC_ASSERT_OK";
private _msg = format ["%1 passed %2", _label, _rule];

switch (toUpper _rule) do
{
    case "ARRAY_SHAPE": {
        _options params [
            ["_def", [], [[]]],
            ["_minCount", 0, [0]],
            ["_maxCount", -1, [0]],
            ["_requirePairEntries", false, [true]]
        ];

        if !(_value isEqualType []) then {
            _ok = false;
            _norm = _def;
            _code = "ARC_ASSERT_TYPE_MISMATCH";
            _msg = format ["%1 must be ARRAY", _label];
        } else {
            private _n = count _value;
            if ((_n < _minCount) || {(_maxCount >= 0) && {_n > _maxCount}}) then {
                _ok = false;
                _norm = _def;
                _code = "ARC_ASSERT_ARRAY_SHAPE";
                _msg = format ["%1 count %2 out of bounds [%3,%4]", _label, _n, _minCount, _maxCount];
            } else {
                if (_requirePairEntries) then {
                    private _badIdx = _value findIf { !(_x isEqualType []) || { (count _x) < 2 } };
                    if (_badIdx >= 0) then {
                        _ok = false;
                        _norm = _def;
                        _code = "ARC_ASSERT_ARRAY_SHAPE";
                        _msg = format ["%1 contains non-pair entry at index %2", _label, _badIdx];
                    };
                };
            };
        };
    };

    case "SCALAR_BOUNDS": {
        _options params [
            ["_def", 0, [0]],
            ["_min", -1e12, [0]],
            ["_max", 1e12, [0]]
        ];

        if !(_value isEqualType 0) then {
            _ok = false;
            _norm = _def;
            _code = "ARC_ASSERT_TYPE_MISMATCH";
            _msg = format ["%1 must be SCALAR", _label];
        } else {
            if (_value < _min) then {
                _ok = false;
                _norm = _min;
                _code = "ARC_ASSERT_SCALAR_BOUNDS";
                _msg = format ["%1 below minimum %2", _label, _min];
            } else {
                if (_value > _max) then {
                    _ok = false;
                    _norm = _max;
                    _code = "ARC_ASSERT_SCALAR_BOUNDS";
                    _msg = format ["%1 above maximum %2", _label, _max];
                };
            };
        };
    };

    case "NON_EMPTY_STRING": {
        _options params [["_def", "", [""]]];
        if !(_value isEqualType "") then {
            _ok = false;
            _norm = _def;
            _code = "ARC_ASSERT_TYPE_MISMATCH";
            _msg = format ["%1 must be STRING", _label];
        } else {
            _norm = trim _value;
            if (_norm isEqualTo "") then {
                _ok = false;
                _norm = _def;
                _code = "ARC_ASSERT_EMPTY_STRING";
                _msg = format ["%1 must be non-empty STRING", _label];
            };
        };
    };

    case "OBJECT_NOT_NULL": {
        _options params [["_def", objNull, [objNull]]];
        if !(_value isEqualType objNull) then {
            _ok = false;
            _norm = _def;
            _code = "ARC_ASSERT_TYPE_MISMATCH";
            _msg = format ["%1 must be OBJECT", _label];
        } else {
            if (isNull _value) then {
                _ok = false;
                _norm = _def;
                _code = "ARC_ASSERT_OBJECT_NULL";
                _msg = format ["%1 must not be objNull", _label];
            };
        };
    };

    default {
        _ok = false;
        _code = "ARC_ASSERT_RULE_UNKNOWN";
        _msg = format ["Unknown assertion rule: %1", _rule];
    };
};

[_ok, _norm, _code, _msg]
