#Requires AutoHotkey v2.0

/**
 * @file _ParseBlockMappingState.ahk
 * @description Represents the state of parsing a block mapping.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing a block mapping.
 */
class _ParseBlockMappingState extends _YamlParserStateBase {
    /** @field {String} _anchor - Anchor for the mapping itself */
    _anchor := ""

    /** @field {String} _tag - Tag for the mapping itself */
    _tag := ""

    /** @field {String} _keyAnchor - Anchor for the first key (carried from node state) */
    _keyAnchor := ""

    /** @field {String} _keyTag - Tag for the first key (carried from node state) */
    _keyTag := ""

    /** @field {Boolean} _started - Whether the MappingStartEvent has been emitted */
    _started := false

    /**
     * @param {Integer} indent
     * @param {String} [anchor=""]
     * @param {String} [tag=""]
     * @param {String} [keyAnchor=""]
     * @param {String} [keyTag=""]
     */
    __New(indent, anchor := "", tag := "", keyAnchor := "", keyTag := "") {
        c := _YamlParserStateBase.Category
        super.__New("_ParseBlockMapping", c.Scope.Block | c.Type.Map | c.Role.Start, indent)
        this._anchor := anchor
        this._tag := tag
        this._keyAnchor := keyAnchor
        this._keyTag := keyTag
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        clone := _ParseBlockMappingState(this.indent, this._anchor, this._tag, this._keyAnchor, this._keyTag)
        clone._started := this._started
        return clone
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        if (!this._started) {
            this._started := true
            ctx.States.Push(_ParseBlockMappingEndState())
            ; Pass properties intended for the FIRST key
            ctx.States.Push(_ParseBlockMappingKeyState(this.indent, this._keyAnchor, this._keyTag))
            return YamlMappingStartEvent(this._tag, this._anchor, false, 0, 0)
        }
        ctx.States.Pop()
        return ""
    }
}
