#Requires AutoHotkey v2.0

/**
 * @file _ParseBlockSequenceEntryState.ahk
 * @description Represents the state of parsing an entry in a block sequence.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing an entry in a block sequence.
 */
class _ParseBlockSequenceEntryState extends _YamlParserStateBase {
    /**
     * @param {Integer} [indent=-1] - The indentation level of the sequence start.
     */
    __New(indent := -1) {
        c := _YamlParserStateBase.Category
        super.__New("_ParseBlockSequenceEntry", c.Scope.Block | c.Type.Seq | c.Role.Key, indent)
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseBlockSequenceEntryState(this.indent)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        c := _YamlParserStateBase.Category
        loop {
            state_lk := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()

            ; 1. Dedent/Indentation handling
            if (t.Is(_YamlToken.Type.Dedent)) {
                if (t.value < this.indent) {
                    ctx.Processor.RestoreState(state_lk)
                    ctx.States.Pop()
                    return ""
                }
                continue
            }

            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent)) {
                continue
            }

            ; 2. Boundary detection
            if (t.column != -1 && t.column < this.indent) {
                ctx.Processor.RestoreState(state_lk)
                ctx.States.Pop()
                return ""
            }

            ; 3. Sequence Entry Consumption
            if (t.Is(_YamlToken.Type.BlockEntry)) {
                if (t.column == this.indent) {
                    state_next := ctx.Processor.CaptureState()
                    tNext := ctx.Processor.FetchToken()

                    if (tNext.Is(_YamlToken.Type.Tab)) {
                        tAfterTab := ctx.Processor.FetchToken()
                        if (!tAfterTab.Is(_YamlToken.Type.Scalar)) {
                            throw YamlError("Tabs are not allowed after block entry indicator",
                                tNext.line, tNext.column)
                        }
                    }

                    ctx.Processor.RestoreState(state_next)
                    ctx.States.Pop()
                    ctx.States.Push(_ParseBlockNodeState("", "", -1, c.Role.Value))
                    return ""
                }
            }

            if (t.IsAnyOf(_YamlToken.Type.StreamEnd, _YamlToken.Type.DocStart, _YamlToken.Type.DocEnd)) {
                ctx.Processor.RestoreState(state_lk)
                ctx.States.Pop()
                return ""
            }

            ; If we reach here, it's not our entry
            ctx.Processor.RestoreState(state_lk)
            ctx.States.Pop()
            return ""
        }
    }
}
