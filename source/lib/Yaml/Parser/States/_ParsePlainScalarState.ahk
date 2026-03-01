#Requires AutoHotkey v2.0

/**
 * @file _ParsePlainScalarState.ahk
 * @description Represents the state of parsing a plain scalar.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing a plain scalar.
 */
class _ParsePlainScalarState extends _YamlParserNodeStateBase {
    /**
     * @param {Integer} [indent=-1]
     * @param {String} [anchor=""]
     * @param {String} [tag=""]
     */
    __New(indent := -1, anchor := "", tag := "") {
        c := _YamlParserStateBase.Category
        super.__New("_ParsePlainScalar", c.None, indent, anchor, tag)
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParsePlainScalarState(this.indent, this.anchor, this.tag)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        if (ctx.Tracer) {
            ctx.Tracer.Trace("Entering _ParsePlainScalarState.Handle")
        }
        state_start := ctx.Processor.CaptureState()
        t_first := ctx.Processor.FetchToken()
        ctx.Processor.RestoreState(state_start)

        ; VALIDATION: A plain scalar cannot start with a quote.
        ; If we are here and the first token is a quoted scalar, something is wrong.
        if (t_first.IsAnyOf(_YamlToken.Type.ScalarSQ, _YamlToken.Type.ScalarDQ)) {
            throw YamlError("A quoted scalar cannot be parsed as a plain scalar",
                t_first.line, t_first.column)
        }

        ; VALIDATION: A plain scalar must not start with reserved indicators
        if (InStr("%@``", SubStr(String(t_first.value), 1, 1))) {
            throw YamlError("Plain scalars must not begin with reserved indicators (@, %, `)",
                t_first.line, t_first.column)
        }

        content := ""
        consumedAny := false
        lastEndPos := -1
        pendingSeparator := ""
        hasCommentOnLine := false

        c := _YamlParserStateBase.Category
        isSimpleKey := (this.category & c.Key.Simple)
        isFlow := ctx.States.Has(c.Scope.Flow)

        ctx.Processor.Hint := _YamlLayoutProcessor.Hint.PlainScalar
        origSkipComments := ctx.Processor.SkipComments
        ctx.Processor.SkipComments := false
        try {
            loop {
                state_lk := ctx.Processor.CaptureState()
                t := ctx.Processor.FetchToken()

                if (t.IsAnyOf(_YamlToken.Type.StreamEnd, _YamlToken.Type.DocStart, _YamlToken.Type.DocEnd)) {
                    ctx.Processor.RestoreState(state_lk)
                    break
                }

                if (t.Is(_YamlToken.Type.ValueIndicator)) {
                    ctx.Processor.RestoreState(state_lk)
                    break
                }

                if (t.IsAnyOf(_YamlToken.Type.Indent, _YamlToken.Type.Dedent)) {
                    if (t.Is(_YamlToken.Type.Dedent) && t.value < this.indent) {
                        ctx.Processor.RestoreState(state_lk)
                        break
                    }
                    continue
                }

                if (isFlow && (t.Is(_YamlToken.Type.Punctuator) || t.Is(_YamlToken.Type.Symbol))
                && InStr("[]{},", t.value)) {
                    ctx.Processor.RestoreState(state_lk)
                    break
                }

                ; Simple key specific boundary: colon must not be joined if it's an indicator
                if (isSimpleKey && t.Is(_YamlToken.Type.Punctuator) && t.value == ":") {
                    ; (Indicator check is already done by LayoutProcessor)
                    ctx.Processor.RestoreState(state_lk)
                    break
                }

                if (t.Is(_YamlToken.Type.Comment)) {
                    hasCommentOnLine := true
                    continue
                }

                ; 1. Content tokens
                if (t.IsScalar || t.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol,
                    _YamlToken.Type.BlockEntry, _YamlToken.Type.Anchor, _YamlToken.Type.Tag)) {
                    ; VALIDATION: '#' is not allowed in flow plain scalars.
                    if (isFlow && t.value == "#") {
                        ctx.Processor.RestoreState(state_lk)
                        break
                    }

                    ; Indentation check
                    if (!isFlow && t.column < this.indent) {
                        ctx.Processor.RestoreState(state_lk)
                        break
                    }

                    if (t.Is(_YamlToken.Type.BlockEntry) && !isFlow) {
                        parentCollection := ctx.States.Find(
                            _YamlParserStateBase.Category.Type.Map | _YamlParserStateBase.Category.Type.Seq)
                        pIndent := (parentCollection != "") ? parentCollection.indent : 0
                        if (t.column <= pIndent) {
                            ctx.Processor.RestoreState(state_lk)
                            break
                        }
                    }

                    val := String(t.value)
                    if (t.Is(_YamlToken.Type.Anchor)) {
                        val := "&" . val
                    }

                    if (consumedAny) {
                        if (pendingSeparator != "") {
                            content .= pendingSeparator
                            pendingSeparator := ""
                        } else if (lastEndPos != -1 && t.pos > lastEndPos) {
                            content .= " "
                        }
                        content .= val
                    } else {
                        content := val
                    }

                    consumedAny := true
                    lastEndPos := t.pos + t.len
                    continue
                }

                ; 2. Newline / Continuation
                if (t.Is(_YamlToken.Type.Newline)) {
                    if (isSimpleKey && !isFlow) {
                        ctx.Processor.RestoreState(state_lk)
                        break
                    }

                    ; Rule: Cannot continue after a comment
                    if (hasCommentOnLine) {
                        ctx.Processor.RestoreState(state_lk)
                        break
                    }

                    continuation := { newlines: 1 }
                    if (ctx.Speculate("PlainScalarContinuation",
                        () => this._CheckContinuationAfterNewline(ctx, continuation))) {
                        if (consumedAny) {
                            if (continuation.newlines > 1) {
                                pendingSeparator := ""
                                loop (continuation.newlines - 1) {
                                    pendingSeparator .= "`n"
                                }
                            } else {
                                pendingSeparator := " "
                            }
                        }
                        lastEndPos := -1
                        continue
                    } else {
                        ctx.Processor.RestoreState(state_lk)
                        break
                    }
                }

                ctx.Processor.RestoreState(state_lk)
                break
            }
        } finally {
            ctx.Processor.Hint := _YamlLayoutProcessor.Hint.None
            ctx.Processor.SkipComments := origSkipComments
        }

        ctx.States.Pop()
        anchor := this.anchor, tag := this.tag
        this.anchor := "", this.tag := ""

        if (ctx.Tracer) {
            ctx.Tracer.Trace("PlainScalar Content: '" . content . "'")
        }

        ; VALIDATION: A plain scalar must not be just a block indicator character
        ; if it's not followed by content that makes it a valid scalar.
        if (StrLen(content) == 1 && InStr("-?:", content)) {
            ; Check if it was scanned as a punctuator (meaning it was followed by a separator)
            if (t_first.Is(_YamlToken.Type.Punctuator)) {
                throw YamlError("A block indicator character cannot be a plain scalar by itself",
                    t_first.line, t_first.column)
            }
        }

        return YamlScalarEvent(content, ctx.ExpandTag(tag), anchor, ":", t_first.line, t_first.column)
    }

    /**
     * Checks if a plain scalar can continue on the next line.
     * @param {Object} ctx
     * @param {Object} info - {newlines: Integer}
     * @returns {Boolean}
     */
    _CheckContinuationAfterNewline(ctx, info) {
        c := _YamlParserStateBase.Category
        isSimpleKey := ctx.States.Has(c.Key.Simple)
        isFlow := ctx.States.Has(c.Scope.Flow)

        origSkipComments := ctx.Processor.SkipComments
        ctx.Processor.SkipComments := false
        try {
            loop {
                state_lk := ctx.Processor.CaptureState()
                t := ctx.Processor.FetchToken()
                if (ctx.Tracer) {
                    ctx.Tracer.Trace("Continuation Loop: token=" . t.name . " val=" . t.value . " col=" . t.column)
                }

                if (t.Is(_YamlToken.Type.Newline)) {
                    info.newlines++
                    continue
                }
                if (t.Is(_YamlToken.Type.Comment)) {
                    if (ctx.Tracer) {
                        ctx.Tracer.Trace("Continuation Break: Comment line")
                    }
                    throw _YamlSpeculativeParseError("Comment")
                }
                if (t.IsAnyOf(_YamlToken.Type.Indent, _YamlToken.Type.Dedent)) {
                    if (t.Is(_YamlToken.Type.Dedent) && t.value < this.indent) {
                        if (ctx.Tracer) {
                            ctx.Tracer.Trace("Continuation Break: Dedent below indent")
                        }
                        throw _YamlSpeculativeParseError("Indent")
                    }
                    continue
                }

                ; In flow context, we are much more lenient about newlines
                if (isFlow) {
                    if (t.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol,
                        _YamlToken.Type.ValueIndicator, _YamlToken.Type.KeyIndicator)) {
                        if (InStr("[]{},", t.value)) {
                            if (ctx.Tracer) {
                                ctx.Tracer.Trace("Continuation Break: Flow boundary")
                            }
                            throw _YamlSpeculativeParseError("Boundary")
                        }
                        if (t.value == ":") {
                            if (ctx.Tracer) {
                                ctx.Tracer.Trace("Continuation Break: Flow mapping indicator on new line")
                            }
                            throw _YamlSpeculativeParseError("MappingIndicator")
                        }
                    }
                    if (ctx.Tracer) {
                        ctx.Tracer.Trace("Continuation Success: Flow mode")
                    }
                    ctx.Processor.RestoreState(state_lk)
                    return true
                }

                ; Check if this line starts a mapping key
                if (!isSimpleKey && this._IsMappingStart(ctx, t)) {
                    if (ctx.Tracer) {
                        ctx.Tracer.Trace("Continuation Break: Mapping start")
                    }
                    throw _YamlSpeculativeParseError("Mapping")
                }

                ; Block sequence entry at the same indentation is a boundary, not a continuation
                if (t.Is(_YamlToken.Type.BlockEntry)) {
                    parentCollection := ctx.States.Find(c.Type.Map | c.Type.Seq)
                    pIndent := (parentCollection != "") ? parentCollection.indent : 0
                    if (t.column <= pIndent) {
                        if (ctx.Tracer) {
                            ctx.Tracer.Trace("Continuation Break: BlockEntry at parent indent")
                        }
                        throw _YamlSpeculativeParseError("Boundary")
                    }
                }

                if (t.IsScalar || t.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol,
                    _YamlToken.Type.BlockEntry, _YamlToken.Type.Anchor, _YamlToken.Type.Tag)) {
                    ; Indentation check: subsequent lines must be at least as indented as the scalar started.
                    if (!isFlow && t.column < this.indent) {
                        if (ctx.Tracer) {
                            ctx.Tracer.Trace("Continuation Break: Insufficient indentation")
                        }
                        throw _YamlSpeculativeParseError("Indent")
                    }
                    if (ctx.Tracer) {
                        ctx.Tracer.Trace("Continuation Success: Content found")
                    }
                    ctx.Processor.RestoreState(state_lk)
                    return true
                }
                if (ctx.Tracer) {
                    ctx.Tracer.Trace("Continuation Break: Unknown token " . t.name)
                }
                throw _YamlSpeculativeParseError("Unknown")
            }
        } finally {
            ctx.Processor.SkipComments := origSkipComments
        }
    }

    /**
     * Determines if the current token sequence starts a mapping.
     * @param {Object} ctx
     * @param {Object} firstToken
     * @returns {Boolean}
     */
    _IsMappingStart(ctx, firstToken) {
        state_save := ctx.Processor.CaptureState()
        try {
            if (firstToken.Is(_YamlToken.Type.KeyIndicator) || firstToken.Is(_YamlToken.Type.ValueIndicator)) {
                return true
            }
            ; We need a simplified version of _CheckForValueIndicator here
            ; or just use the one from _ParseBlockNodeState if accessible.
            ; For now, let's do a quick check.
            t := firstToken
            if (!t.IsScalar && !t.IsAnyOf(_YamlToken.Type.Alias, _YamlToken.Type.Anchor, _YamlToken.Type.Tag)) {
                return false
            }

            ; Look for ':' on the same line
            loop {
                tn := ctx.Processor.FetchToken()
                if (tn.line != t.line) {
                    break
                }
                if (tn.Is(_YamlToken.Type.ValueIndicator)) {
                    ctx.Processor.RestoreState(state_save)
                    return true
                }
            }
            ctx.Processor.RestoreState(state_save)
            return false
        } catch Any {
            ctx.Processor.RestoreState(state_save)
            return false
        }
    }
}
