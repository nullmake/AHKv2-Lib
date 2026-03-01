#Requires AutoHotkey v2.0

/**
 * @file _ParseFlowMappingValueState.ahk
 * @description Represents the state of parsing a value in a flow mapping.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing a value in a flow mapping.
 */
class _ParseFlowMappingValueState extends _YamlParserStateBase {
    /** @field {Boolean} _isImplicit - Whether the value is part of an implicit mapping */
    _isImplicit := false

    /**
     * @param {Boolean} [isImplicit=false]
     */
    __New(isImplicit := false) {
        c := _YamlParserStateBase.Category
        super.__New("_ParseFlowMappingValue", c.Scope.Flow | c.Type.Map | c.Role.Value)
        this._isImplicit := isImplicit
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseFlowMappingValueState(this._isImplicit)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        ctx.Processor.Hint := _YamlLayoutProcessor.Hint.FlowValue
        loop {
            state_lk := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()

            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent, _YamlToken.Type.Dedent,
                _YamlToken.Type.Space, _YamlToken.Type.Tab)) {
                continue
            }

            if (t.Is(_YamlToken.Type.ValueIndicator)) {
                ; Value indicator found.
                ctx.Processor.Hint := _YamlLayoutProcessor.Hint.None
                ctx.States.Pop()
                ; Push node state to parse the actual value content
                ctx.States.Push(_ParseFlowNodeState())
                return ""
            }

            ; Implicit null value (reached ',', '}', or boundary)
            ctx.Processor.Hint := _YamlLayoutProcessor.Hint.None
            ctx.Processor.RestoreState(state_lk)
            ctx.States.Pop()

            ; Emit Null scalar for the value
            return YamlScalarEvent("", "", "", ":", t.line, t.column)
        }
    }
}
