#Requires AutoHotkey v2.0

/**
 * @file _ParseBlockMappingKeyState.ahk
 * @description Represents the state of parsing a key in a block mapping.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing a key in a block mapping.
 */
class _ParseBlockMappingKeyState extends _YamlParserStateBase {
    /** @field {String} _anchor - Anchor intended for the key */
    _anchor := ""

    /** @field {String} _tag - Tag intended for the key */
    _tag := ""

    /**
     * @param {Integer} [indent=-1]
     * @param {String} [anchor=""]
     * @param {String} [tag=""]
     */
    __New(indent := -1, anchor := "", tag := "") {
        c := _YamlParserStateBase.Category
        super.__New("_ParseBlockMappingKey", c.Scope.Block | c.Type.Map | c.Role.Key, indent)
        this._anchor := anchor
        this._tag := tag
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseBlockMappingKeyState(this.indent, this._anchor, this._tag)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        loop {
            state_lk := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()

            ; 1. Dedent/Indentation handling
            if (t.Is(_YamlToken.Type.Dedent)) {
                if (t.value < this.indent) {
                    ; This dedent belongs to a parent container.
                    ctx.Processor.RestoreState(state_lk)
                    ctx.States.Pop()
                    return ""
                }
                ; Consumption: this dedent brings us back to our own level or is noise.
                continue
            }

            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent)) {
                continue
            }

            if (t.column != -1 && t.column < this.indent) {
                ; Current token is less indented than this mapping.
                ctx.Processor.RestoreState(state_lk)
                ctx.States.Pop()
                return ""
            }

            if (t.IsAnyOf(_YamlToken.Type.StreamEnd, _YamlToken.Type.DocStart, _YamlToken.Type.DocEnd)) {
                ctx.Processor.RestoreState(state_lk)
                ctx.States.Pop()
                return ""
            }

            ; 2. Start parsing a new entry
            if (t.column != -1 && t.column > this.indent) {
                ; If we already have properties, this token IS the key content, which can be more indented.
                if (this._anchor != "" || this._tag != ""
                    || t.IsAnyOf(_YamlToken.Type.Anchor, _YamlToken.Type.Tag, _YamlToken.Type.KeyIndicator)) {
                    ctx.Processor.RestoreState(state_lk)
                    ctx.States.Pop()
                    ctx.States.Push(_ParseBlockMappingKeyState(this.indent))
                    ctx.States.Push(_ParseBlockMappingValueState(this.indent, _YamlParserStateBase.Category.Key.Simple))
                    ctx.States.Push(_ParseBlockNodeState(this._anchor, this._tag, -1,
                        _YamlParserStateBase.Category.Key.Simple | _YamlParserStateBase.Category.Role.Key))
                    return ""
                }
                throw YamlError("Block mapping entry is over-indented", t.line, t.column)
            }

            c := _YamlParserStateBase.Category
            keyType := t.Is(_YamlToken.Type.KeyIndicator) ? c.Key.Explicit : c.Key.Simple

            ctx.States.Pop()
            ctx.States.Push(_ParseBlockMappingKeyState(this.indent))
            ctx.States.Push(_ParseBlockMappingValueState(this.indent, keyType))

            if (keyType == c.Key.Explicit) {
                ctx.States.Push(_ParseBlockNodeState("", "", -1, c.Key.Explicit | c.Role.Key))
                return ""
            }

            if (t.Is(_YamlToken.Type.ValueIndicator)) {
                ; Implicit null key
                ctx.Processor.RestoreState(state_lk)
                return YamlScalarEvent("", this._tag, this._anchor, ":", t.line, t.column)
            }

            ctx.Processor.RestoreState(state_lk)
            ctx.States.Push(_ParseBlockNodeState(this._anchor, this._tag, -1, c.Key.Simple | c.Role.Key))
            return ""
        }
    }
}
