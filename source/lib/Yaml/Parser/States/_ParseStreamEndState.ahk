#Requires AutoHotkey v2.0

/**
 * @file _ParseStreamEndState.ahk
 * @description Represents the state of parsing the end of a YAML stream.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing the end of a YAML stream.
 */
class _ParseStreamEndState extends _YamlParserStateBase {
    /**
     * Creates a new instance of _ParseStreamEndState.
     */
    __New() {
        super.__New("_ParseStreamEnd")
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseStreamEndState()
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        t := ctx.Processor.FetchToken()
        if (!t.Is(_YamlToken.Type.StreamEnd)) {
            throw YamlError("Expected StreamEnd, but got " . t.name, t.line, t.column)
        }
        ctx.States.Pop()
        return YamlStreamEndEvent(t.line, t.column)
    }
}
