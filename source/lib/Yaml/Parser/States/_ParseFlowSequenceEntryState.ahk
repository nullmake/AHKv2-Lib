#Requires AutoHotkey v2.0

/**
 * @file _ParseFlowSequenceEntryState.ahk
 * @description Represents the state of parsing an entry in a flow sequence.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing an entry in a flow sequence.
 */
class _ParseFlowSequenceEntryState extends _YamlParserStateBase {
    /** @field {Boolean} isFirst - Whether this is the first entry in the sequence */
    isFirst := false

    /**
     * @param {Boolean} [isFirst=false]
     */
    __New(isFirst := false) {
        c := _YamlParserStateBase.Category
        super.__New("_ParseFlowSequenceEntry", c.Scope.Flow | c.Type.Seq)
        this.isFirst := isFirst
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseFlowSequenceEntryState(this.isFirst)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        c := _YamlParserStateBase.Category
        foundComma := false
        loop {
            state_lk := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()

            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent, _YamlToken.Type.Dedent,
                _YamlToken.Type.Space, _YamlToken.Type.Tab)) {
                continue
            }

            if (t.Is(_YamlToken.Type.Punctuator) && t.value == ",") {
                if (this.isFirst || foundComma) {
                    throw YamlError("Unexpected comma in flow collection", t.line, t.column)
                }
                foundComma := true
                continue
            }

            if (t.Is(_YamlToken.Type.Punctuator) && t.value == "]") {
                ctx.Processor.RestoreState(state_lk)
                ctx.States.Pop()
                return ""
            }

            if (t.IsAnyOf(_YamlToken.Type.StreamEnd, _YamlToken.Type.DocStart, _YamlToken.Type.DocEnd)) {
                ctx.Processor.RestoreState(state_lk)
                ctx.States.Pop()
                return ""
            }

            ; START ELEMENT: Must have comma if not first
            if (!this.isFirst && !foundComma) {
                throw YamlError("Flow sequence entries must be separated by commas", t.line, t.column)
            }

            ; START ELEMENT
            ctx.Processor.RestoreState(state_lk)
            ctx.States.Pop()
            ctx.States.Push(_ParseFlowSequenceEntryState(false)) ; Not first anymore

            if (this._IsMappingStart(ctx)) {
                ctx.States.Push(_ParseFlowImplicitMappingState())
            } else {
                ctx.States.Push(_ParseFlowNodeState())
            }
            return ""
        }
    }

    /**
     * Determines if the next sequence of tokens starts an implicit mapping.
     * @param {Object} ctx
     * @returns {Boolean}
     */
    _IsMappingStart(ctx) {
        state_save := ctx.Processor.CaptureState()
        try {
            loop {
                state_pre_prop := ctx.Processor.CaptureState()
                t := ctx.Processor.FetchToken()
                if (t.IsAnyOf(_YamlToken.Type.Anchor, _YamlToken.Type.Tag)) {
                    continue
                }
                ; Found the first significant token of the potential key.
                ; Restore to just before this token so Speculate can see it.
                ctx.Processor.RestoreState(state_pre_prop)
                break
            }
            if (t.IsAnyOf(_YamlToken.Type.KeyIndicator, _YamlToken.Type.ValueIndicator)) {
                ctx.Processor.RestoreState(state_save)
                return true
            }
            result := ctx.Speculate("FlowSeqEntryMapping", () => this._CheckForColon(ctx))
            ctx.Processor.RestoreState(state_save)
            return result
        } catch Any {
            ctx.Processor.RestoreState(state_save)
            return false
        }
    }

    /**
     * Internal implementation of the flow mapping key check.
     * @param {Object} ctx
     */
    _CheckForColon(ctx) {
        loop {
            t := ctx.Processor.FetchToken()
            if (t.IsAnyOf(_YamlToken.Type.Anchor, _YamlToken.Type.Tag)) {
                continue
            }
            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent, _YamlToken.Type.Dedent)) {
                throw _YamlSpeculativeParseError("Newline before flow key.")
            }
            break
        }
        startLine := t.line
        flowLevel := 0
        if (t.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol,
            _YamlToken.Type.ValueIndicator, _YamlToken.Type.KeyIndicator)) {
            if (InStr("[{", t.value)) {
                flowLevel++
            } else if (InStr("]}", t.value) || t.value == ",") {
                throw _YamlSpeculativeParseError("Boundary.")
            }
        } else if (!t.IsScalar && !t.IsAnyOf(_YamlToken.Type.Alias)) {
            throw _YamlSpeculativeParseError("Not a key.")
        }

        loop {
            t_curr := ctx.Processor.FetchToken()
            if (t_curr.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent, _YamlToken.Type.Dedent)) {
                throw _YamlSpeculativeParseError("Multi-line flow implicit key.")
            }
            if (t_curr.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol,
                _YamlToken.Type.ValueIndicator, _YamlToken.Type.KeyIndicator)) {
                if (InStr("[{", t_curr.value)) {
                    flowLevel++
                } else if (InStr("]}", t_curr.value)) {
                    if (flowLevel == 0) {
                        throw _YamlSpeculativeParseError("Boundary.")
                    }
                    flowLevel--
                } else if (t_curr.value == "," && flowLevel == 0) {
                    throw _YamlSpeculativeParseError("Boundary.")
                }
            }
            if (flowLevel == 0 && t_curr.Is(_YamlToken.Type.ValueIndicator)) {
                return
            }
            if (t_curr.IsAnyOf(_YamlToken.Type.DocStart, _YamlToken.Type.DocEnd, _YamlToken.Type.StreamEnd)) {
                throw _YamlSpeculativeParseError("End.")
            }
            if (A_Index > 500) {
                throw _YamlSpeculativeParseError("Limit.")
            }
        }
    }
}
