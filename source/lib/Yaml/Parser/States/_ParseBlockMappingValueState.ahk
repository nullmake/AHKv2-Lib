#Requires AutoHotkey v2.0

/**
 * @file _ParseBlockMappingValueState.ahk
 * @description Represents the state of parsing a value in a block mapping.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing a value in a block mapping.
 */
class _ParseBlockMappingValueState extends _YamlParserStateBase {
    /** @field {Integer} _keyType - Type of the key (Simple or Explicit) */
    _keyType := 0

    /**
     * @param {Integer} [indent=-1]
     * @param {Integer} [keyType=0]
     */
    __New(indent := -1, keyType := 0) {
        c := _YamlParserStateBase.Category
        super.__New("_ParseBlockMappingValue", c.Scope.Block | c.Type.Map | c.Role.Value | keyType, indent)
        this._keyType := keyType
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseBlockMappingValueState(this.indent, this._keyType)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        c := _YamlParserStateBase.Category
        ; 1. Skip noise to find ValueIndicator
        state_start := ctx.Processor.CaptureState()

        loop {
            state_lk := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()
            if (ctx.Tracer) {
                ctx.Tracer.Trace(Format("ValueState Loop: token={1} (type:{2})", t.value, t.name))
            }

            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent)) {
                continue
            }
            if (t.Is(_YamlToken.Type.Tab)) {
                throw YamlError("Unexpected tab character", t.line, t.column)
            }
            if (t.Is(_YamlToken.Type.Dedent)) {
                if (t.value >= this.indent) {
                    continue
                }
            }

            ; Check if it's the ValueIndicator
            if (t.Is(_YamlToken.Type.ValueIndicator)) {
                ctx.States.Pop()
                ctx.States.Push(_ParseBlockNodeState("", "", t.line, c.Role.Value | this._keyType))
                return ""
            }

            ; Not a value indicator, put it back
            ctx.Processor.RestoreState(state_lk)
            break
        }

        c := _YamlParserStateBase.Category
        if (this._keyType == c.Key.Simple) {
            ; Re-fetch the first non-noise token for the error message
            t_err := ctx.Processor.FetchToken()
            throw YamlError("Block mapping simple keys must be followed by a value indicator ':'",
                t_err.line, t_err.column)
        }

        ; 2. If no ValueIndicator, it's an implicit null value.
        ; We MUST NOT restore to state_start if we are emitting a scalar,
        ; because the scalar's "position" is here.
        ctx.States.Pop()

        ; Use the token that failed to be a ValueIndicator as the position for the null scalar
        state_pos := ctx.Processor.CaptureState()
        t_pos := ctx.Processor.FetchToken()
        ctx.Processor.RestoreState(state_pos)

        return YamlScalarEvent("", "", "", ":", t_pos.line, t_pos.column)
    }
}
