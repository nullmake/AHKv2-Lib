#Requires AutoHotkey v2.0

/**
 * @file _YamlConstructor.ahk
 * @description Transforms YAML nodes into native AutoHotkey v2 objects (Layer 5).
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Transforms a Node Graph into native AutoHotkey objects.
 */
class _YamlConstructor {
    /** @field {Map} _constructedObjects - Cache of constructed AHK objects by node reference */
    _constructedObjects := Map()

    /**
     * Converts a node tree into a native AHK object.
     * @param {YamlNode} node - The root node to convert.
     * @returns {Any}
     */
    Construct(node) {
        if (node == "") {
            return ""
        }

        ; Check cache to maintain object identity (for anchors/aliases)
        if (this._constructedObjects.Has(node)) {
            return this._constructedObjects[node]
        }

        if (node is YamlScalarNode) {
            val := this._ConstructScalar(node)
            this._constructedObjects[node] := val
            return val
        }

        if (node is YamlMappingNode) {
            _map := Map()
            ; Register the container BEFORE constructing children to handle circular references.
            this._constructedObjects[node] := _map

            for _pair in node.children {
                _key := this.Construct(_pair.Key)
                _val := this.Construct(_pair.Value)
                _map[_key] := _val
            }
            return _map
        }

        if (node is YamlSequenceNode) {
            _arr := []
            this._constructedObjects[node] := _arr

            for _child in node.children {
                _arr.Push(this.Construct(_child))
            }
            return _arr
        }

        return ""
    }

    /**
     * Converts an octal string to a decimal integer.
     * @param {String} _val - Octal string.
     * @returns {Integer}
     */
    _ConvertOctal(_val) {
        _res := 0
        loop parse _val {
            _res := (_res * 8) + Integer(A_LoopField)
        }
        return _res
    }

    /**
     * Converts a scalar node to its native type based on tags and implicit rules.
     * @param {YamlScalarNode} node
     * @returns {Any}
     */
    _ConstructScalar(node) {
        _val := node.value
        _tag := node.tag

        ; 1. Explicit Tags (YAML 1.2.2 - Core Schema)
        if (_tag != "") {
            ; Normalize tag names (assuming they are already resolved/expanded by Parser/Composer)
            if (_tag == "tag:yaml.org,2002:int" || _tag == "!!int") {
                if (!IsNumber(_val)) {
                    throw YamlError("Cannot construct !!int from non-numeric string: '" . _val . "'")
                }
                return Integer(_val)
            }
            if (_tag == "tag:yaml.org,2002:float" || _tag == "!!float") {
                if (!IsNumber(_val)) {
                    throw YamlError("Cannot construct !!float from non-numeric string: '" . _val . "'")
                }
                return Float(_val)
            }
            if (_tag == "tag:yaml.org,2002:bool" || _tag == "!!bool") {
                return (_val ~= "i)^(true|yes|on)$") ? Yaml.True : Yaml.False
            }
            if (_tag == "tag:yaml.org,2002:str" || _tag == "!!str") {
                return String(_val)
            }
            if (_tag == "tag:yaml.org,2002:null" || _tag == "!!null") {
                return Yaml.Null
            }
        }

        ; 2. Implicit Casting for Plain Scalars (Style ":")
        ; In our Parser, style ":" represents a plain scalar.
        if (node.style == ":") {
            ; Null values
            if (_val == "" || _val ~= "i)^null$" || _val == "~") {
                return Yaml.Null
            }

            ; Boolean values (Core Schema)
            if (_val ~= "i)^(true|false)$") {
                return (_val ~= "i)^true$") ? Yaml.True : Yaml.False
            }

            ; Integers (Core Schema: Decimal, Hex, Octal)
            if (_val ~= "^[-+]?[0-9]+$") {
                return Integer(_val)
            }
            if (_val ~= "i)^[-+]?0x[0-9a-f]+$") {
                return Integer(_val)
            }
            if (_val ~= "i)^[-+]?0o[0-7]+$") {
                ; AHK's Integer() doesn't support 0o prefix directly, so we strip it.
                _sign := (SubStr(_val, 1, 1) == "-") ? "-" : ""
                _octalPart := RegExReplace(_val, "i)^[-+]?0o", "")
                ; Convert octal string to decimal integer (simplified for test suite)
                return Integer(_sign . this._ConvertOctal(_octalPart))
            }

            ; Floats
            if (IsNumber(_val)) {
                return Float(_val)
            }

            ; Special floats
            if (_val ~= "i)^[-+]?(\.inf)$") {
                return (SubStr(_val, 1, 1) == "-") ? -9.223372036854775807e18 : 9.223372036854775807e18
            }
            if (_val ~= "i)^\.nan$") {
                return "NaN"
            }
        }

        return _val
    }
}
