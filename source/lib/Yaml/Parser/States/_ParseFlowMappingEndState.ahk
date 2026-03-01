#Requires AutoHotkey v2.0

/**
 * @file _ParseFlowMappingEndState.ahk
 * @description Represents the state of ending a flow mapping.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of ending a flow mapping.
 */
class _ParseFlowMappingEndState extends _YamlParserStateBase {
    /**
     * Creates a new instance of _ParseFlowMappingEndState.
     */
    __New() {
        c := _YamlParserStateBase.Category
        super.__New("_ParseFlowMappingEnd", c.Scope.Flow | c.Type.Map | c.Role.End)
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseFlowMappingEndState()
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        t := ctx.Processor.FetchToken()
        if (!(t.Is(_YamlToken.Type.Punctuator) && t.value == "}")) {
            throw YamlError("Expected flow mapping end '}', but got " . t.name
                . (t.HasProp("value") ? " '" . t.value . "'" : ""),
                t.line, t.column)
        }
        ctx.States.Pop()
        return YamlMappingEndEvent(t.line, t.column)
    }
}
