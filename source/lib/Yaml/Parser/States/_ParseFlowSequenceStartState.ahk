#Requires AutoHotkey v2.0

/**
 * @file _ParseFlowSequenceStartState.ahk
 * @description Represents the state of starting a flow sequence.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of starting a flow sequence.
 */
class _ParseFlowSequenceStartState extends _YamlParserNodeStateBase {
    /**
     * @param {String} [anchor=""]
     * @param {String} [tag=""]
     */
    __New(anchor := "", tag := "") {
        c := _YamlParserStateBase.Category
        super.__New("_ParseFlowSequenceStart", c.Scope.Flow | c.Type.Seq | c.Role.Start, -1, anchor, tag)
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseFlowSequenceStartState(this.anchor, this.tag)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        t := ctx.Processor.FetchToken() ; Consume '['
        ctx.States.Pop()
        ctx.States.Push(_ParseFlowSequenceEndState())
        ctx.States.Push(_ParseFlowSequenceEntryState(true))
        anchor := this.anchor, tag := this.tag
        this.anchor := "", this.tag := ""
        return YamlSequenceStartEvent(tag, anchor, true, t.line, t.column)
    }
}
