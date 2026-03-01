#Requires AutoHotkey v2.0

/**
 * @file _ParseStreamContentState.ahk
 * @description Represents the state of parsing the content of a YAML stream.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing the content of a YAML stream.
 */
class _ParseStreamContentState extends _YamlParserStateBase {
    /** @field {Integer} _lastDocPos - Position of the last document to prevent infinite loops */
    _lastDocPos := -1

    /** @field {Boolean} _hasParsedDoc - Whether at least one document has been parsed */
    _hasParsedDoc := false

    /**
     * @param {Integer} [lastDocPos=-1]
     * @param {Boolean} [hasParsedDoc=false]
     */
    __New(lastDocPos := -1, hasParsedDoc := false) {
        super.__New("_ParseStreamContent")
        this._lastDocPos := lastDocPos
        this._hasParsedDoc := hasParsedDoc
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseStreamContentState(this._lastDocPos, this._hasParsedDoc)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        ctx.Processor.ContextIndentOverride := -1
        loop {
            state_lk := ctx.Processor.CaptureState()
            currPos := state_lk.scannerState.pos
            t := ctx.Processor.FetchToken()

            if (t.Is(_YamlToken.Type.StreamEnd)) {
                ctx.States.Pop()
                return ""
            }

            if (t.Is(_YamlToken.Type.Newline)) {
                continue
            }

            ; If we are at the same position where the previous document failed to progress,
            ; we must stop to prevent infinite loops.
            if (this._lastDocPos != -1 && currPos <= this._lastDocPos) {
                ; Try to skip one token to force progress, or just end.
                ctx.Processor.RestoreState(state_lk)
                ctx.Processor.FetchToken() ; consume one token
                this._lastDocPos := ctx.Processor.CaptureState().scannerState.pos
                continue
            }

            ; Found potential document content or marker.
            ctx.Processor.RestoreState(state_lk)
            ctx.States.Pop()

            ; Setup next content search, but record the current position to prevent loops
            ctx.States.Push(_ParseStreamContentState(currPos, true))
            ctx.States.Push(_ParseDocumentStartState(this._hasParsedDoc))
            return ""
        }
    }
}
