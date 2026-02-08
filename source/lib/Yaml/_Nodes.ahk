#Requires AutoHotkey v2.0

/**
 * @file _Nodes.ahk
 * @description Definition of YAML Representation Nodes.
 * @author nullmake
 * @license Apache-2.0
 * 
 * Copyright 2026 nullmake
 */

/**
 * @class YamlNode
 * Base class for all nodes in the representation graph.
 */
class YamlNode {
    /** @field {String} tag - Resolved YAML tag */
    tag := ""
    /** @field {String} anchor - Original anchor name (if any) */
    anchor := ""

    __New(tag := "", anchor := "") {
        this.tag := tag
        this.anchor := anchor
    }
}

class YamlScalarNode extends YamlNode {
    /** @field {String} value - Normalized scalar value */
    value := ""
    /** @field {Integer} style - Original presentation style */
    style := 0

    __New(value, tag := "", anchor := "", style := 0) {
        super.__New(tag, anchor)
        this.value := value
        this.style := style
    }
}

class YamlSequenceNode extends YamlNode {
    /** @field {Array} children - List of YamlNode objects */
    children := []

    __New(tag := "", anchor := "") {
        super.__New(tag, anchor)
        this.children := []
    }
}

class YamlMappingNode extends YamlNode {
    /** @field {Array} children - List of {KeyNode, ValueNode} pairs to maintain order */
    children := []

    __New(tag := "", anchor := "") {
        super.__New(tag, anchor)
        this.children := []
    }

    /**
     * @method Add
     * @param {YamlNode} keyNode
     * @param {YamlNode} valueNode
     */
    Add(keyNode, valueNode) {
        this.children.Push({Key: keyNode, Value: valueNode})
    }
}
