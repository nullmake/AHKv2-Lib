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
    * Converts a scalar node to its native type based on JSON Schema and tags.
    */
    _ConstructScalar(node) {
        _val := node.value
        _tag := node.tag

        ; 1. Explicit Tags (YAML 1.2.2 - 10.2.1)
        if (_tag != "") {
            if (_tag == "!!int") {
                return Integer(_val)
            }
            if (_tag == "!!float") {
                return Float(_val)
            }
            if (_tag == "!!bool") {
                return (_val ~= "i)^true$") ? true : false
            }
            if (_tag == "!!str") {
                return String(_val)
            }
            if (_tag == "!!null") {
                return ""
            }
        }

        ; 2. Implicit Casting for Plain Scalars (Style 0)
        if (node.style == 0) {
            ; Null values (case-insensitive)
            if (_val == "" || _val ~= "i)^null$" || _val == "~") {
                return ""
            }

            ; Boolean values (case-insensitive)
            if (_val ~= "i)^true$") {
                return true
            }
            if (_val ~= "i)^false$") {
                return false
            }

            ; Numbers
            if (IsNumber(_val)) {
                if (_val ~= "i)^0x[0-9a-f]+$") {
                    return Integer(_val)
                }
                return _val + 0
            }

            ; Special floats
            if (_val ~= "i)^\.inf$") {
                return 9.223372036854775807e18
            }
            if (_val ~= "i)^\.nan$") {
                return "NaN"
            }
        }

        return _val
    }
}
