#Requires AutoHotkey v2.0

/**
 * @file _YamlNodes.ahk
 * @description Definition of YAML Representation Nodes (Layer 4).
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Base class for all nodes in the representation graph.
 */
class YamlNode {
    /** @field {String} tag - The YAML tag (if any) */
    tag := ""

    /** @field {String} anchor - The anchor name (if any) */
    anchor := ""

    /**
     * @param {String} [tag=""]
     * @param {String} [anchor=""]
     */
    __New(tag := "", anchor := "") {
        this.tag := tag
        this.anchor := anchor
    }
}

/**
 * Represents a scalar node.
 */
class YamlScalarNode extends YamlNode {
    /** @field {String} value - The scalar content */
    value := ""

    /** @field {String} style - Scalar style (':', "'", '"', '|', '>') */
    style := ":"

    /** @field {Boolean} isMultiline - Whether the scalar spans multiple lines */
    isMultiline := false

    /** @field {String} chomping - Chomping rule for block scalars ('strip', 'clip', 'keep') */
    chomping := "clip"

    /**
     * @param {String} value
     * @param {String} [tag=""]
     * @param {String} [anchor=""]
     * @param {String} [style=":"]
     */
    __New(value, tag := "", anchor := "", style := ":") {
        super.__New(tag, anchor)
        this.value := value
        this.style := style
    }
}

/**
 * Represents a sequence node.
 */
class YamlSequenceNode extends YamlNode {
    /** @field {Array} children - List of YamlNode children */
    children := []

    /**
     * @param {String} [tag=""]
     * @param {String} [anchor=""]
     */
    __New(tag := "", anchor := "") {
        super.__New(tag, anchor)
        this.children := []
    }
}

/**
 * Represents a mapping node.
 */
class YamlMappingNode extends YamlNode {
    /** @field {Array} children - List of {Key: YamlNode, Value: YamlNode} pairs */
    children := []

    /**
     * @param {String} [tag=""]
     * @param {String} [anchor=""]
     */
    __New(tag := "", anchor := "") {
        super.__New(tag, anchor)
        this.children := []
    }

    /**
     * Adds a key-value pair to the mapping.
     * @param {YamlNode} keyNode
     * @param {YamlNode} valueNode
     */
    Add(keyNode, valueNode) {
        this.children.Push({ Key: keyNode, Value: valueNode })
    }
}
