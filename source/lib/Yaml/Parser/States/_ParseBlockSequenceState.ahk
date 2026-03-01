#Requires AutoHotkey v2.0

/**
 * @file _ParseBlockSequenceState.ahk
 * @description Represents the state of managing a block sequence.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of managing a block sequence.
 */
class _ParseBlockSequenceState extends _YamlParserNodeStateBase {
    /** @field {Boolean} _isStarted - Whether the SequenceStartEvent has been emitted */
    _isStarted := false

    /** @field {Integer} parentLine - The line number of the parent node/indicator */
    parentLine := -1

    /**
     * @param {Integer} [indent=-1] - The indentation level.
     * @param {String} [anchor=""]
     * @param {String} [tag=""]
     * @param {Integer} [parentLine=-1] - The line number of the parent node.
     */
    __New(indent := -1, anchor := "", tag := "", parentLine := -1) {
        c := _YamlParserStateBase.Category
        super.__New("_ParseBlockSequence", c.Scope.Block | c.Type.Seq | c.Role.Start, indent, anchor, tag)
        this._isStarted := false
        this.parentLine := parentLine
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        clone := _ParseBlockSequenceState(this.indent, this.anchor, this.tag, this.parentLine)
        clone._isStarted := this._isStarted
        return clone
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        state_start := ctx.Processor.CaptureState()
        t := ctx.Processor.FetchToken()

        ; 1. Initialization
        if (!this._isStarted) {
            this._isStarted := true

            ctx.States.Push(_ParseBlockSequenceEntryState(this.indent))
            anchor := this.anchor, tag := this.tag
            this.anchor := "", this.tag := ""
            isFlow := ctx.States.Has(_YamlParserStateBase.Category.Scope.Flow)

            ctx.Processor.RestoreState(state_start) ; Put it back for the entry state
            return YamlSequenceStartEvent(tag, anchor, isFlow, t.line, t.column)
        }

        ; 2. Skip noise
        ctx.Processor.RestoreState(state_start)
        loop {
            state_lk := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()

            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent)) {
                continue
            }
            if (t.Is(_YamlToken.Type.Tab)) {
                throw YamlError("Unexpected tab character", t.line, t.column)
            }
            if (t.Is(_YamlToken.Type.Dedent)) {
                if (t.value >= this.indent) {
                    continue
                }
            }

            ; Not noise, put it back
            ctx.Processor.RestoreState(state_lk)
            break
        }

        state_check := ctx.Processor.CaptureState()
        t := ctx.Processor.FetchToken()

        if (t.IsAnyOf(_YamlToken.Type.StreamEnd, _YamlToken.Type.DocStart, _YamlToken.Type.DocEnd)) {
            ctx.Processor.RestoreState(state_check)
            ctx.States.Pop()
            return YamlSequenceEndEvent(t.line, t.column)
        }

        ; 3. Continuation Check
        ; Sequence continues if next token is a BlockEntry (-) at exactly our level
        if (t.column == this.indent && t.Is(_YamlToken.Type.BlockEntry)) {
            ctx.Processor.RestoreState(state_check) ; Back up for EntryState
            ctx.States.Push(_ParseBlockSequenceEntryState(this.indent))
            return ""
        }

        ; 4. Termination
        ctx.Processor.RestoreState(state_check)
        ctx.States.Pop()
        return YamlSequenceEndEvent(t.line, t.column)
    }
}
