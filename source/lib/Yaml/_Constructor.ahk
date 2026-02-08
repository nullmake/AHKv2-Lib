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
     */
    _ConstructScalar(node) {
        _val := node.value
        
        ; TODO: Implement full JSON Schema (YAML 1.2.2) type casting.
        ; For now, keep as string or simple numbers.
        if (IsNumber(_val)) {
            return _val + 0 ; Convert to numeric
        }
        
        if (_val == "true") {
            return true
        }
        
        if (_val == "false") {
            return false
        }
        
        if (node.value == "" && node.style == 0) {
            return "" ; Null
        }

        return _val
    }
}
