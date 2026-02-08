#Requires AutoHotkey v2.0

/**
 * @file _Constructor.ahk
 * @description Converts YAML nodes to native AHK v2 objects.
 * @author nullmake
 * @license Apache-2.0
 *
 * Copyright 2026 nullmake
 */

/**
 * @class _YamlConstructor
 * Transforms a Node Graph into native AutoHotkey objects.
 */
class _YamlConstructor {
    /**
    * @method Construct
    * Converts a node tree into a native AHK object.
    * @param {YamlNode} node - The root node to convert.
    * @returns {Any}
    */
    Construct(node) {
        if (node is YamlScalarNode) {
            return this._ConstructScalar(node)
        }

        if (node is YamlMappingNode) {
            _map := Map()
            for _pair in node.children {
                _key := this.Construct(_pair.Key)
                _val := this.Construct(_pair.Value)
                _map[_key] := _val
            }
            return _map
        }

        if (node is YamlSequenceNode) {
            _arr := []
            for _child in node.children {
                _arr.Push(this.Construct(_child))
            }
            return _arr
        }

        return ""
    }

    /**
    * @method _ConstructScalar
    * Converts a scalar node to its native type based on JSON Schema.
    * Only plain scalars (Style 0) are subject to type casting.
    */
    _ConstructScalar(node) {
        _val := node.value

        ; 1. Quoted scalars are always strings (YAML 1.2.2 - JSON Schema)
        if (node.style != 0) {
            return _val
        }

        ; 2. Null values (case-insensitive)
        if (_val == "" || _val ~= "i)^null$" || _val == "~") {
            return ""
        }

        ; 3. Boolean values (case-insensitive)
        if (_val ~= "i)^true$") {
            return true
        }
        if (_val ~= "i)^false$") {
            return false
        }

        ; 4. Numbers (Integer and Float)
        if (IsNumber(_val)) {
            ; Hexadecimal check
            if (_val ~= "i)^0x[0-9a-f]+$") {
                return Integer(_val)
            }
            ; Return native numeric type (Integer or Float)
            return _val + 0
        }

        ; 5. Special floats
        if (_val ~= "i)^\.inf$") {
            return 9.223372036854775807e18
        }
        if (_val ~= "i)^\.nan$") {
            return "NaN"
        }

        return _val
    }
}
