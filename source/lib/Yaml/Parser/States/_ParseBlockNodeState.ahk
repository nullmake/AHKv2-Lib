#Requires AutoHotkey v2.0

/**
 * @file _ParseBlockNodeState.ahk
 * @description Represents the state of parsing a block node.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing a block node.
 */
class _ParseBlockNodeState extends _YamlParserNodeStateBase {
    /** @field {Integer} parentLine - The line number of the parent node/indicator */
    parentLine := -1

    /**
     * @param {String} [anchor=""]
     * @param {String} [tag=""]
     * @param {Integer} [parentLine=-1] - The line number of the parent node/indicator.
     * @param {Integer} [category=0] - Initial category flags.
     */
    __New(anchor := "", tag := "", parentLine := -1, category := 0) {
        c := _YamlParserStateBase.Category
        super.__New("_ParseBlockNode", c.Scope.Block | category, -1, anchor, tag)
        this.parentLine := parentLine
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseBlockNodeState(this.anchor, this.tag, this.parentLine, this.category)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        c := _YamlParserStateBase.Category
        nodeStartCol := -1
        nodeStartLine := -1
        layoutIndent := -1

        isSimpleKey := (this.category & c.Role.Key) && (this.category & c.Key.Simple)
        isExplicitKey := (this.category & c.Role.Key) && (this.category & c.Key.Explicit)
        isAfterSimpleKey := (this.category & c.Role.Value) && (this.category & c.Key.Simple)

        ; 0. Determine Indentation requirements early
        parentIndent := -1
        containerState := ctx.States.Find(c.Type.Map | c.Type.Seq)
        if (containerState != "") {
            parentIndent := containerState.indent
        }
        ctx.Processor.ContextIndentOverride := parentIndent

        minIndent := 0
        ; If no block container, we are at the top level.
        isTopLevel := (containerState == "")
        if (containerState != "") {
            minIndent := parentIndent
            ; Explicit keys and all values must be indented more than the parent.
            if ((this.category & c.Role.Value) || ((this.category & c.Role.Key) && !(this.category & c.Key.Simple))) {
                minIndent := parentIndent + 1
            }
        }

        ; 1. Node content has started, so disable directive scanning.
        ctx.Processor.SetDirectivesAllowed(false)

        ; 2. Collect Properties (Anchor, Tag) and determine initial Indentation
        loop {
            state := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()

            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent, _YamlToken.Type.Dedent)) {
                if (t.IsAnyOf(_YamlToken.Type.Indent, _YamlToken.Type.Dedent)) {
                    layoutIndent := t.value
                }
                continue
            }

            if (nodeStartCol == -1) {
                nodeStartCol := (layoutIndent != -1) ? layoutIndent : t.column
                nodeStartLine := t.line
            }

            if (t.IsAnyOf(_YamlToken.Type.Anchor, _YamlToken.Type.Tag)) {
                if (this.parentLine != -1 && t.line > this.parentLine && t.column < minIndent) {
                    ctx.Processor.RestoreState(state)
                    break
                }
                if (t.Is(_YamlToken.Type.Anchor)) {
                    if (this.anchor != "") {
                        ctx.Processor.RestoreState(state)
                        break
                    }
                    this.anchor := t.value
                    this._anchorLine := t.line
                } else {
                    if (this.tag != "") {
                        ctx.Processor.RestoreState(state)
                        break
                    }
                    this.tag := t.value
                    this._tagLine := t.line
                }
                continue
            }
            ; Not a property, put it back
            ctx.Processor.RestoreState(state)
            break
        }

        ; 3. Peek first significant content token
        state_content := ctx.Processor.CaptureState()
        t := ctx.Processor.FetchToken()

        ; Skip noise, preserving/updating layoutIndent
        while (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent, _YamlToken.Type.Dedent)) {
            if (t.IsAnyOf(_YamlToken.Type.Indent, _YamlToken.Type.Dedent)) {
                layoutIndent := t.value
            }
            state_content := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()
        }
        ctx.Processor.ContextIndentOverride := -2 ; Reset after finding content

        ; Recalculate start info if not already set (should be set by props, but just in case)
        if (nodeStartCol == -1) {
            nodeStartCol := (layoutIndent != -1) ? layoutIndent : t.column
            nodeStartLine := t.line
        }

        ; Final indentation level for this node
        ; colIndent := (layoutIndent != -1) ... (context for replacement)
        colIndent := (layoutIndent != -1) ? layoutIndent : ((t.line == nodeStartLine) ? nodeStartCol : t.column)

        ; --- Indentation Check ---
        isIndented := (t.column == -1 || colIndent >= minIndent)

        ; Special Top-Level Protection (e.g. for test case 2SXE)
        if (!isIndented && isTopLevel && colIndent == 0) {
            isIndented := true
        }

        ; Compact notation / Sequence entries
        if (!isIndented && colIndent == parentIndent && t.Is(_YamlToken.Type.BlockEntry)) {
            parentIsMap := (containerState != "" && (containerState.category & c.Type.Map))
            if (parentIsMap) {
                isIndented := true
            }
        }

        ; W42U fix: '-' at parent indent on a new line is the NEXT entry, not content.
        if (isIndented && t.Is(_YamlToken.Type.BlockEntry) && t.column == parentIndent) {
            parentIsSeq := (containerState != "" && (containerState.category & c.Type.Seq))
            if (parentIsSeq && t.line != nodeStartLine) {
                isIndented := false
            }
        }

        if (ctx.Tracer) {
            ctx.Tracer.Trace(Format(
                "Node content token: {} (type:{}) at L:{} C:{} -> isIndented:{} (colIndent:{}, min:{}, parent:{}, topLevel:{})",
                t.value, t.name, t.line, t.column, isIndented, colIndent, minIndent, parentIndent, isTopLevel))
        }

        if (!isIndented || t.IsAnyOf(_YamlToken.Type.StreamEnd, _YamlToken.Type.DocStart, _YamlToken.Type.DocEnd)) {
            if (ctx.Tracer) {
                ctx.Tracer.Trace("Node end detected due to indentation or markers")
            }
            ctx.Processor.RestoreState(state_content)
            ctx.States.Pop()
            return YamlScalarEvent("", ctx.ExpandTag(this.tag), this.anchor, ":", nodeStartLine, nodeStartCol)
        }

        ; 4. Dispatch based on token type and context

        ; VALIDATION: A simple key cannot span multiple lines in block context.
        if (isSimpleKey && t.endLine > nodeStartLine && !ctx.States.Has(c.Scope.Flow)) {
            throw YamlError("A simple key cannot span multiple lines", t.line, t.column)
        }

        ; VALIDATION: Block collections cannot start on the same line as '---'
        if (isTopLevel && ctx.CurrentDocStartedWithMarker && this.parentLine != -1 && t.line == this.parentLine) {
            if (t.IsAnyOf(_YamlToken.Type.BlockEntry, _YamlToken.Type.KeyIndicator) || this._IsMappingKey(ctx, t, -1)) {
                throw YamlError("Block collection cannot start on the same line as document start marker",
                    t.line, t.column)
            }
        }

        isMapping := (t.Is(_YamlToken.Type.KeyIndicator) || this._IsMappingKey(ctx, t, isSimpleKey ? nodeStartLine : -1
        ))
        if (!isSimpleKey && isMapping) {
            ; VALIDATION: A block mapping cannot start on the same line as a simple key.
            if (this.parentLine != -1 && t.line == this.parentLine && isAfterSimpleKey) {
                throw YamlError("A block mapping cannot start on the same line as a simple key", t.line, t.column)
            }

            if (ctx.Tracer) {
                ctx.Tracer.Trace("Transition to MappingState")
            }
            mapAnchor := this.anchor, mapTag := this.tag
            keyAnchor := "", keyTag := ""

            if (this.anchor != "" && this._anchorLine == t.line && !t.Is(_YamlToken.Type.KeyIndicator)) {
                keyAnchor := this.anchor
                mapAnchor := ""
            }
            if (this.tag != "" && this._tagLine == t.line && !t.Is(_YamlToken.Type.KeyIndicator)) {
                keyTag := this.tag
                mapTag := ""
            }

            ctx.Processor.RestoreState(state_content)
            ctx.States.Pop()
            ctx.Processor.PushIndentOnly(colIndent)
            ctx.States.Push(_ParseBlockMappingState(colIndent, mapAnchor, ctx.ExpandTag(mapTag),
            keyAnchor, ctx.ExpandTag(keyTag)))
            this.anchor := "", this.tag := ""
            return ""
        }

        if (t.Is(_YamlToken.Type.Alias)) {
            if (ctx.Tracer) {
                ctx.Tracer.Trace("Found Alias")
            }
            ; VALIDATION: Properties (anchor/tag) cannot be applied to an alias.
            if (this.anchor != "" || this.tag != "") {
                throw YamlError("Properties cannot be applied to an alias", t.line, t.column)
            }
            ctx.States.Pop()
            return YamlAliasEvent(t.value, t.line, t.column)
        }

        if (t.Is(_YamlToken.Type.Punctuator) && (t.value == "|" || t.value == ">")) {
            if (ctx.Tracer) {
                ctx.Tracer.Trace("Transition to BlockScalarState")
            }
            ctx.Processor.RestoreState(state_content)
            ctx.States.Pop()
            ctx.Processor.PushIndentOnly(colIndent)
            ctx.States.Push(_ParseBlockScalarState(this.anchor, ctx.ExpandTag(this.tag)))
            this.anchor := "", this.tag := ""
            return ""
        }

        if (t.Is(_YamlToken.Type.BlockEntry)) {
            if (isSimpleKey) {
                throw YamlError("A block sequence cannot be used as a simple key", t.line, t.column)
            }
            ; VALIDATION: A block sequence cannot start on the same line as a simple key.
            if (this.parentLine != -1 && t.line == this.parentLine && isAfterSimpleKey) {
                throw YamlError("A block sequence cannot start on the same line as a simple key", t.line, t.column)
            }
            if (ctx.Tracer) {
                ctx.Tracer.Trace("Transition to BlockSequenceState")
            }
            ctx.Processor.RestoreState(state_content)
            ctx.States.Pop()
            ctx.Processor.PushIndentOnly(colIndent)
            ctx.States.Push(_ParseBlockSequenceState(colIndent, this.anchor, ctx.ExpandTag(this.tag), this.parentLine))
            this.anchor := "", this.tag := ""
            return ""
        }

        if (t.IsScalar || t.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol)) {
            if (t.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol)) {
                if (InStr(",]}", t.value)) {
                    throw YamlError("Unexpected flow indicator '" . t.value . "' in block context", t.line, t.column)
                }
            }
            if (ctx.Tracer) {
                ctx.Tracer.Trace("Fall through to PlainScalarState")
            }
            if (t.IsAnyOf(_YamlToken.Type.ScalarSQ, _YamlToken.Type.ScalarDQ)) {
                ctx.States.Pop()
                anchor := this.anchor, tag := ctx.ExpandTag(this.tag)
                this.anchor := "", this.tag := ""
                return YamlScalarEvent(t.value, tag, anchor, t.style, t.line, t.column)
            }

            if (t.Is(_YamlToken.Type.Punctuator) || t.Is(_YamlToken.Type.Symbol)) {
                if (t.value == "[") {
                    ctx.Processor.RestoreState(state_content)
                    ctx.States.Pop()
                    ctx.States.Push(_ParseFlowSequenceStartState(this.anchor, ctx.ExpandTag(this.tag)))
                    this.anchor := "", this.tag := ""
                    return ""
                }
                if (t.value == "{") {
                    ctx.Processor.RestoreState(state_content)
                    ctx.States.Pop()
                    ctx.States.Push(_ParseFlowMappingStartState(this.anchor, ctx.ExpandTag(this.tag)))
                    this.anchor := "", this.tag := ""
                    return ""
                }
            }

            ctx.Processor.RestoreState(state_content)
            ctx.States.Pop()
            newState := _ParsePlainScalarState(minIndent, this.anchor, ctx.ExpandTag(this.tag))
            if (isSimpleKey) {
                newState.category |= c.Key.Simple
            }
            ctx.States.Push(newState)
            this.anchor := "", this.tag := ""
            return ""
        }

        ctx.Processor.RestoreState(state_content)
        ctx.States.Pop()
        return YamlScalarEvent("", ctx.ExpandTag(this.tag), this.anchor, ":", t.line, t.column)
    }

    /**
     * Determines if the next sequence of tokens constitutes a mapping key.
     * @param {Object} ctx
     * @param {Object} firstToken
     * @param {Integer} [startLine=-1]
     * @returns {Boolean}
     */
    _IsMappingKey(ctx, firstToken, startLine := -1) {
        state_save := ctx.Processor.CaptureState()
        try {
            if (firstToken.Is(_YamlToken.Type.KeyIndicator) || firstToken.Is(_YamlToken.Type.ValueIndicator)) {
                return true
            }
            result := ctx.Speculate("IsMappingKey", () => this._CheckForValueIndicator(ctx, firstToken, startLine))
            ctx.Processor.RestoreState(state_save)
            return result
        } catch Any {
            ctx.Processor.RestoreState(state_save)
            return false
        }
    }

    /**
     * Internal implementation of the mapping key check (looking for ':').
     * @param {Object} ctx
     * @param {Object} firstToken
     * @param {Integer} [startLine=-1]
     */
    _CheckForValueIndicator(ctx, firstToken, startLine := -1) {
        t := firstToken
        isFlow := ctx.States.Has(_YamlParserStateBase.Category.Scope.Flow)
        if (startLine == -1) {
            startLine := t.line
        }
        flowLevel := 0

        ; VALIDATION: A simple key cannot span multiple lines.
        ; Check if the first token itself is multi-line (e.g. quoted scalar with literal newline).
        if (!isFlow && t.endLine > t.line) {
            throw _YamlSpeculativeParseError("Multi-line token as simple key.")
        }

        if ((t.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol, _YamlToken.Type.ValueIndicator,
            _YamlToken.Type.KeyIndicator)) && InStr("[{", t.value)) {
            flowLevel++
        } else if (!t.IsScalar && !t.IsAnyOf(_YamlToken.Type.Alias, _YamlToken.Type.Anchor, _YamlToken.Type.Tag)) {
            throw _YamlSpeculativeParseError("Not a key.")
        }

        loop {
            t_curr := (A_Index == 1) ? t : ctx.Processor.FetchToken()

            if (t_curr.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent, _YamlToken.Type.Dedent)) {
                continue
            }

            if (A_Index > 1) {
                if (!isFlow && flowLevel == 0 && t_curr.line != startLine) {
                    throw _YamlSpeculativeParseError("Multi-line block simple key.")
                }
                if (t_curr.IsAnyOf(_YamlToken.Type.Punctuator, _YamlToken.Type.Symbol,
                    _YamlToken.Type.ValueIndicator, _YamlToken.Type.KeyIndicator)) {
                    if (InStr("[{", t_curr.value)) {
                        flowLevel++
                    } else if (InStr("]}", t_curr.value)) {
                        if (flowLevel == 0) {
                            if (isFlow) {
                                throw _YamlSpeculativeParseError("Boundary.")
                            }
                        } else {
                            flowLevel--
                        }
                    } else if (t_curr.value == "," && flowLevel == 0 && isFlow) {
                        throw _YamlSpeculativeParseError("Boundary.")
                    }
                }
            }

            if (flowLevel == 0) {
                state_peek := ctx.Processor.CaptureState()
                t_next := ctx.Processor.FetchToken()
                if (t_next.Is(_YamlToken.Type.ValueIndicator)) {
                    if (!isFlow && t_next.line != startLine) {
                        throw _YamlSpeculativeParseError("Value indicator on new line.")
                    }
                    return
                }
                ctx.Processor.RestoreState(state_peek)
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
