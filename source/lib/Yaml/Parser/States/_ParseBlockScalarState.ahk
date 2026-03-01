#Requires AutoHotkey v2.0

/**
 * @file _ParseBlockScalarState.ahk
 * @description Represents the state of parsing a block scalar (Literal '|' or Folded '>').
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing a block scalar.
 */
class _ParseBlockScalarState extends _YamlParserNodeStateBase {
    /**
     * @param {String} [anchor=""]
     * @param {String} [tag=""]
     */
    __New(anchor := "", tag := "") {
        super.__New("_ParseBlockScalar", 0, -1, anchor, tag)
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseBlockScalarState(this.anchor, this.tag)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        ; Set hint BEFORE fetching the indicator token itself,
        ; so that subsequent indicators are not joined by LayoutProcessor.
        ctx.Processor.Hint := _YamlLayoutProcessor.Hint.BlockScalarIndicator

        indicatorToken := ctx.Processor.FetchToken() ; Consume '|' or '>'
        style := indicatorToken.value

        ; 1. Parse indicators on the same line (e.g., |2-, >+, |-)
        chomping := "clip" ; default
        explicitIndent := -1 ; Not set
        loop {
            state_lk := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()

            if (t.Is(_YamlToken.Type.Scalar) && IsInteger(t.value)) {
                if (explicitIndent != -1) {
                    throw YamlError("Duplicate block scalar indentation indicator", t.line, t.column)
                }
                explicitIndent := Integer(t.value)
                if (explicitIndent == 0) {
                    throw YamlError("Block scalar indentation indicator cannot be zero", t.line, t.column)
                }
                continue
            }

            if (t.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol, _YamlToken.Type.BlockEntry)) {
                if (t.value == "+") {
                    if (chomping != "clip") {
                        throw YamlError("Duplicate block scalar chomping indicator", t.line, t.column)
                    }
                    chomping := "keep"
                    continue
                } else if (t.value == "-") {
                    if (chomping != "clip") {
                        throw YamlError("Duplicate block scalar chomping indicator", t.line, t.column)
                    }
                    chomping := "strip"
                    continue
                }
            }

            ctx.Processor.RestoreState(state_lk)
            break
        }

        if (explicitIndent == -1) {
            explicitIndent := 0
        }

        ; Reset hint to default after parsing indicators
        ctx.Processor.Hint := _YamlLayoutProcessor.Hint.None

        ; Consume potential potential trailing white space and comments
        loop {
            state_nl := ctx.Processor.CaptureState()
            t_nl := ctx.Processor.FetchToken()
            if (t_nl.IsAnyOf(_YamlToken.Type.Comment, _YamlToken.Type.Space, _YamlToken.Type.Tab))
                continue
            if (t_nl.Is(_YamlToken.Type.Newline))
                break

            if (t_nl.IsAnyOf(_YamlToken.Type.StreamEnd, _YamlToken.Type.DocStart, _YamlToken.Type.DocEnd)) {
                ctx.Processor.RestoreState(state_nl)
                break
            }

            throw YamlError("Unexpected characters after block scalar indicator: '" . t_nl.value . "'", t_nl.line, t_nl
                .column)
        }

        ; 2. Determine Indentation
        c := _YamlParserStateBase.Category
        parentIndent := -1
        containerState := ctx.States.Find(c.Type.Map | c.Type.Seq)
        if (containerState != "") {
            parentIndent := containerState.indent
        }

        ; 3. Delegate collection to LayoutProcessor
        ctx.Processor.Hint := {
            style: style,
            chomping: chomping,
            indent: explicitIndent,
            parentIndent: parentIndent,
            line: indicatorToken.line,
            column: indicatorToken.column
        }

        scalarToken := ctx.Processor.FetchToken() ; This will call _CollectBlockScalar internally

        ctx.States.Pop()
        anchor := this.anchor, tag := ctx.ExpandTag(this.tag)
        this.anchor := "", this.tag := ""
        return YamlScalarEvent(scalarToken.value, tag, anchor, style, indicatorToken.line, indicatorToken.column)
    }
}
