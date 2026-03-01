#Requires AutoHotkey v2.0

/**
 * @file _ParseDocumentEndState.ahk
 * @description Represents the state of parsing the end of a YAML document.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing the end of a YAML document.
 */
class _ParseDocumentEndState extends _YamlParserStateBase {
    /**
     * Creates a new instance of _ParseDocumentEndState.
     */
    __New() {
        super.__New("_ParseDocumentEnd")
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseDocumentEndState()
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        loop {
            state_lk := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()

            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent, _YamlToken.Type.Dedent,
                _YamlToken.Type.Space, _YamlToken.Type.Tab)) {
                continue
            }

            if (t.Is(_YamlToken.Type.DocEnd)) {
                ; Validate same line content after DocEnd
                loop {
                    state_val := ctx.Processor.CaptureState()
                    tn := ctx.Processor.FetchToken()
                    if (tn.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.StreamEnd,
                        _YamlToken.Type.Comment, _YamlToken.Type.Space, _YamlToken.Type.Tab)) {
                        ctx.Processor.RestoreState(state_val)
                        break
                    }
                    if (tn.line == t.line) {
                        throw YamlError("Unexpected content after document end marker", tn.line, tn.column)
                    }
                    ctx.Processor.RestoreState(state_val)
                    break
                }

                ctx.LastDocEndedWithMarker := true
                ctx.Processor.SetDirectivesAllowed(true)
                ctx.States.Pop()
                return YamlDocumentEndEvent(true, t.line, t.column)
            }

            ; Implicit End
            ctx.LastDocEndedWithMarker := false
            ctx.Processor.SetDirectivesAllowed(true)
            ctx.Processor.RestoreState(state_lk)
            ctx.States.Pop()
            return YamlDocumentEndEvent(false, t.line, t.column)
        }
    }
}
