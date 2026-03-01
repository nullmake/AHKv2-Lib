#Requires AutoHotkey v2.0

/**
 * @file _ParseBlockMappingEndState.ahk
 * @description Represents the state of ending a block mapping.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of ending a block mapping.
 */
class _ParseBlockMappingEndState extends _YamlParserStateBase {
    /**
     * Creates a new instance of _ParseBlockMappingEndState.
     */
    __New() {
        c := _YamlParserStateBase.Category
        super.__New("_ParseBlockMappingEnd", c.Scope.Block | c.Type.Map | c.Role.End)
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseBlockMappingEndState()
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        ctx.States.Pop()
        return YamlMappingEndEvent(0, 0)
    }
}
