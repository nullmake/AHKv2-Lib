#Requires AutoHotkey v2.0

/**
 * @file _YamlParserNodeStateBase.ahk
 * @description Intermediate base class for Parser State Objects that manage YAML nodes.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Intermediate base class for Parser State Objects that manage YAML nodes.
 */
class _YamlParserNodeStateBase extends _YamlParserStateBase {
    /** @field {String} anchor - Anchor name for the current node */
    anchor := ""

    /** @field {String} tag - Tag name for the current node */
    tag := ""

    /** @field {Integer} _anchorLine - Line number where the anchor was defined */
    _anchorLine := -1

    /** @field {Integer} _tagLine - Line number where the tag was defined */
    _tagLine := -1

    /**
     * @param {String} state - The name of the state
     * @param {Integer} [category=0] - Bitmask category
     * @param {Integer} [indent=-1] - The indentation level
     * @param {String} [anchor=""]
     * @param {String} [tag=""]
     */
    __New(state, category := 0, indent := -1, anchor := "", tag := "") {
        super.__New(state, category, indent)
        this.anchor := anchor
        this.tag := tag
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        clone := _YamlParserNodeStateBase(this.state, this.category, this.indent, this.anchor, this.tag)
        clone._anchorLine := this._anchorLine
        clone._tagLine := this._tagLine
        return clone
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
    }
}
