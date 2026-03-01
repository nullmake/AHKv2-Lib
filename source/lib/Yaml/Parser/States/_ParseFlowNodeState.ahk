#Requires AutoHotkey v2.0

/**
 * @file _ParseFlowNodeState.ahk
 * @description Represents the state of parsing a node within a flow collection.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing a node within a flow collection.
 */
class _ParseFlowNodeState extends _YamlParserNodeStateBase {
    /**
     * @param {String} [anchor=""]
     * @param {String} [tag=""]
     */
    __New(anchor := "", tag := "") {
        c := _YamlParserStateBase.Category
        super.__New("_ParseFlowNode", c.Scope.Flow, -1, anchor, tag)
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseFlowNodeState(this.anchor, this.tag)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        c := _YamlParserStateBase.Category

        ; 1. Collect Properties
        loop {
            state := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()
            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent, _YamlToken.Type.Dedent,
                _YamlToken.Type.Space, _YamlToken.Type.Tab)) {
                continue
            }
            if (t.Is(_YamlToken.Type.Anchor)) {
                this.anchor := t.value
                continue
            }
            if (t.Is(_YamlToken.Type.Tag)) {
                this.tag := t.value
                continue
            }
            ctx.Processor.RestoreState(state)
            break
        }

        state_content := ctx.Processor.CaptureState()
        t := ctx.Processor.FetchToken()

        ; 2. Dispatch by Token Type
        if (t.Is(_YamlToken.Type.Alias)) {
            ctx.States.Pop()
            return YamlAliasEvent(t.value, t.line, t.column)
        }

        if (t.IsScalar) {
            ; For Quoted Scalars (SQ/DQ), emit immediately
            if (t.IsAnyOf(_YamlToken.Type.ScalarSQ, _YamlToken.Type.ScalarDQ)) {
                ctx.States.Pop()
                anchor := this.anchor, tag := ctx.ExpandTag(this.tag)
                this.anchor := "", this.tag := ""
                return YamlScalarEvent(t.value, tag, anchor, t.style, t.line, t.column)
            }
            ; For Plain Scalars (Type 11 or Text), delegate to PlainScalarState
            ctx.Processor.RestoreState(state_content)
            ctx.States.Pop()
            ctx.States.Push(_ParsePlainScalarState(0, this.anchor, ctx.ExpandTag(this.tag)))
            return ""
        }

        if (t.Is(_YamlToken.Type.Punctuator) || t.Is(_YamlToken.Type.Symbol)) {
            if (t.value == "[") {
                ctx.Processor.RestoreState(state_content)
                ctx.States.Pop()
                ctx.States.Push(_ParseFlowSequenceStartState(this.anchor, ctx.ExpandTag(this.tag)))
                return ""
            }
            if (t.value == "{") {
                ctx.Processor.RestoreState(state_content)
                ctx.States.Pop()
                ctx.States.Push(_ParseFlowMappingStartState(this.anchor, ctx.ExpandTag(this.tag)))
                return ""
            }
            ; Boundary check: , ] }
            if (InStr(",]}", t.value)) {
                ctx.Processor.RestoreState(state_content)
                ctx.States.Pop()
                return YamlScalarEvent("", ctx.ExpandTag(this.tag), this.anchor, ":", t.line, t.column)
            }
        }

        ; Fallback for indicators acting as content (like ':')
        ctx.Processor.RestoreState(state_content)
        ctx.States.Pop()
        ctx.States.Push(_ParsePlainScalarState(0, this.anchor, ctx.ExpandTag(this.tag)))
        return ""
    }
}
