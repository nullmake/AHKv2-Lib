#Requires AutoHotkey v2.0

/**
 * @file _ParseFlowMappingEntryState.ahk
 * @description Represents the state of parsing an entry in a flow mapping.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing an entry in a flow mapping.
 */
class _ParseFlowMappingEntryState extends _YamlParserStateBase {
    /** @field {Boolean} isFirst - Whether this is the first entry in the mapping */
    isFirst := false

    /**
     * @param {Boolean} [isFirst=false]
     */
    __New(isFirst := false) {
        c := _YamlParserStateBase.Category
        super.__New("_ParseFlowMappingEntry", c.Scope.Flow | c.Type.Map | c.Role.Key)
        this.isFirst := isFirst
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseFlowMappingEntryState(this.isFirst)
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
                _YamlToken.Type.Space, _YamlToken.Type.Tab))
                continue

            if (t.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol) && t.value == "}") {
                ctx.Processor.RestoreState(state_lk)
                ctx.States.Pop()
                return ""
            }

            if (t.IsAnyOf(_YamlToken.Type.StreamEnd, _YamlToken.Type.DocStart, _YamlToken.Type.DocEnd)) {
                ctx.Processor.RestoreState(state_lk)
                ctx.States.Pop()
                return ""
            }

            if (t.Is(_YamlToken.Type.Punctuator) && t.value == ",") {
                if (foundComma || this.isFirst) {
                    throw YamlError("Unexpected comma in flow collection", t.line, t.column)
                }
                foundComma := true
                continue
            }

            ; START ELEMENT: Must have comma if not first
            if (!this.isFirst && !foundComma) {
                throw YamlError("Flow mapping entries must be separated by commas", t.line, t.column)
            }

            ; Start a mapping entry.
            ctx.States.Pop()
            ctx.States.Push(_ParseFlowMappingEntryState(false)) ; For the next element

            ; Push states for current element
            ctx.States.Push(_ParseFlowMappingValueState(false))

            if (t.Is(_YamlToken.Type.KeyIndicator)) {
                ctx.States.Push(_ParseFlowNodeState())
            } else {
                ctx.Processor.RestoreState(state_lk)
                ctx.States.Push(_ParseFlowNodeState())
                ctx.States.Current.category |= c.Key.Simple
            }
            return ""
        }
    }
}
