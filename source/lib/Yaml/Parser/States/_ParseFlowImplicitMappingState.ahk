#Requires AutoHotkey v2.0

/**
 * @file _ParseFlowImplicitMappingState.ahk
 * @description Handles an implicit mapping (key: value) inside a flow sequence.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Handles an implicit mapping (key: value) inside a flow sequence.
 */
class _ParseFlowImplicitMappingState extends _YamlParserStateBase {
    /** @field {Boolean} _started - Whether the MappingStartEvent has been emitted */
    _started := false

    /**
     * Creates a new instance of _ParseFlowImplicitMappingState.
     */
    __New() {
        c := _YamlParserStateBase.Category
        super.__New("_ParseFlowImplicitMapping", c.Scope.Flow | c.Type.Map)
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        clone := _ParseFlowImplicitMappingState()
        clone._started := this._started
        return clone
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        if (!this._started) {
            this._started := true
            state_lk := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()

            if (!t.Is(_YamlToken.Type.KeyIndicator)) {
                ctx.Processor.RestoreState(state_lk)
            }

            ; Push states for the SINGLE pair that an implicit mapping contains.
            ; Order: Node(Key) -> Value(:) -> End
            ctx.States.Push(_ParseFlowImplicitMappingEndState())
            ctx.States.Push(_ParseFlowMappingValueState(false))
            ctx.States.Push(_ParseFlowNodeState())

            return YamlMappingStartEvent("", "", true, t.line, t.column)
        }

        ctx.States.Pop()
        return ""
    }
}

/**
 * Helper state to emit MappingEnd for implicit flow mappings.
 */
class _ParseFlowImplicitMappingEndState extends _YamlParserStateBase {
    /**
     * Creates a new instance of _ParseFlowImplicitMappingEndState.
     */
    __New() {
        super.__New("_ParseFlowImplicitMappingEnd")
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseFlowImplicitMappingEndState()
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        ctx.States.Pop()
        return YamlMappingEndEvent(0, 0)
    }
}
