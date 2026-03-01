#Requires AutoHotkey v2.0

/**
 * @file _ParseFlowMappingStartState.ahk
 * @description Represents the state of starting a flow mapping.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of starting a flow mapping.
 */
class _ParseFlowMappingStartState extends _YamlParserNodeStateBase {
    /**
     * @param {String} [anchor=""]
     * @param {String} [tag=""]
     */
    __New(anchor := "", tag := "") {
        c := _YamlParserStateBase.Category
        super.__New("_ParseFlowMappingStart", c.Scope.Flow | c.Type.Map | c.Role.Start, -1, anchor, tag)
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseFlowMappingStartState(this.anchor, this.tag)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        t := ctx.Processor.FetchToken() ; Consume '{'

        ctx.States.Pop()

        ; Push states to handle the mapping content and closure
        ctx.States.Push(_ParseFlowMappingEndState())
        ctx.States.Push(_ParseFlowMappingEntryState(true))

        anchor := this.anchor, tag := this.tag
        this.anchor := "", this.tag := ""
        return YamlMappingStartEvent(tag, anchor, true, t.line, t.column)
    }
}
