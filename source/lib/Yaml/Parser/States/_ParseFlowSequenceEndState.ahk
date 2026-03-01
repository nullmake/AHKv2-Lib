#Requires AutoHotkey v2.0

/**
 * @file _ParseFlowSequenceEndState.ahk
 * @description Represents the state of ending a flow sequence.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of ending a flow sequence.
 */
class _ParseFlowSequenceEndState extends _YamlParserStateBase {
    /**
     * Creates a new instance of _ParseFlowSequenceEndState.
     */
    __New() {
        c := _YamlParserStateBase.Category
        super.__New("_ParseFlowSequenceEnd", c.Scope.Flow | c.Type.Seq | c.Role.End)
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseFlowSequenceEndState()
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        t := ctx.Processor.FetchToken()
        if (!(t.Is(_YamlToken.Type.Punctuator) && t.value == "]")) {
            throw YamlError("Expected flow sequence end ']', but got " . t.name
                . (t.HasProp("value") ? " '" . t.value . "'" : ""),
                t.line, t.column)
        }
        ctx.States.Pop()
        return YamlSequenceEndEvent(t.line, t.column)
    }
}
