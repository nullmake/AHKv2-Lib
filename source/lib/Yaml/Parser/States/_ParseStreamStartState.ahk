#Requires AutoHotkey v2.0

/**
 * @file _ParseStreamStartState.ahk
 * @description Represents the initial state of parsing a YAML stream.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the initial state of parsing a YAML stream.
 */
class _ParseStreamStartState extends _YamlParserStateBase {
    /**
     * Creates a new instance of _ParseStreamStartState.
     */
    __New() {
        super.__New("_ParseStreamStart")
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseStreamStartState()
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        t := ctx.Processor.FetchToken()
        if (!t.Is(_YamlToken.Type.StreamStart)) {
            throw YamlError("Expected StreamStart, but got " . t.name, t.line, t.column)
        }

        ctx.States.Pop()
        ctx.States.Push(_ParseStreamEndState())
        ctx.States.Push(_ParseStreamContentState())

        return YamlStreamStartEvent(t.line, t.column)
    }
}
