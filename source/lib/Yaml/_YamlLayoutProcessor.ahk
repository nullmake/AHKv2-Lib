#Requires AutoHotkey v2.0

/**
 * @file _YamlLayoutProcessor.ahk
 * @description Layer 2: Handles indentation and layout-dependent token generation.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * LayoutProcessor for YAML.
 */
class _YamlLayoutProcessor {
    /** @field {Object} _scanner - The raw scanner instance */
    _scanner := unset

    /** @field {Object} _ctx - Layout processor context */
    _ctx := unset

    /** @field {Boolean} _isAtLineStart - Whether we are currently at the start of a line */
    _isAtLineStart := true

    /** @field {Boolean} _hasSentStreamStart - Whether STREAM_START has been emitted */
    _hasSentStreamStart := false

    /** @field {Boolean} _hasSentContent - Whether any document content has been emitted */
    _hasSentContent := false

    /** @field {Object|Integer} _hint - Current processing hint */
    _hint := 0

    /** @field {Object} _lastToken - The last token emitted */
    _lastToken := ""

    /** @field {Integer} _contextIndentOverride - Manual override for context indentation */
    _contextIndentOverride := -2

    /** @field {Boolean} _skipComments - Whether to ignore comment tokens */
    _skipComments := true

    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /**
     * Processing hints for the layout processor and scanner.
     */
    static Hint := {
        None: 0,
        BlockKey: 1,
        FlowKey: 2,
        BlockScalarIndicator: 3,
        FlowValue: 4,
        PlainScalar: 5,
        BlockScalar: { style: "|", chomping: "clip", indent: 0 }
    }

    /** @field {Map} _ctxStates - Mapping of context types to their handlers */
    _ctxStates := Map()

    /**
     * @param {Object} scanner - Raw scanner instance
     * @param {YamlOptions} [options] - Configuration options
     */
    __New(scanner, options := "") {
        this._scanner := scanner
        this._ctx := _YamlLayoutProcessorContext(options)
        _opts := (options is YamlOptions) ? options : YamlOptions(options)
        this._tracer := _opts.CreateTracer("LayoutProcessor")
        this._lastToken := ""
        this._hasSentContent := false
        blockHandler := _BlockContext()
        this._ctxStates := Map(
            _YamlContext.Type.Streamstart, _StreamStartContext(),
            _YamlContext.Type.Root, blockHandler,
            _YamlContext.Type.BlockMap, blockHandler,
            _YamlContext.Type.BlockSeq, blockHandler,
            _YamlContext.Type.NodeProps, _NodePropsContext(),
            _YamlContext.Type.BlockScalar, _BlockScalarContext(),
            _YamlContext.Type.Flow, _FlowContext()
        )
        this._ctx.ContextStack.Push(_YamlContext.Type.Streamstart)
        ; Default to ignoring directives. Only allowed via SetDirectivesAllowed.
        this._scanner.IgnoreDirectives := true
    }

    /**
     * Current processing hint.
     */
    Hint {
        get {
            return this._hint
        }
        set {
            this._hint := value
            if (value == _YamlLayoutProcessor.Hint.None) {
                this._scanner.ScanningMode := _YamlRawScanner.Mode.None
            } else if (value == _YamlLayoutProcessor.Hint.FlowValue) {
                this._scanner.ScanningMode := _YamlRawScanner.Mode.FlowValue
            } else if (value == _YamlLayoutProcessor.Hint.PlainScalar) {
                this._scanner.ScanningMode := _YamlRawScanner.Mode.PlainScalar
            } else if (value == _YamlLayoutProcessor.Hint.BlockScalarIndicator) {
                this._scanner.ScanningMode := _YamlRawScanner.Mode.BlockScalar
            } else if (IsObject(value) && value.HasProp("style")) {
                this._scanner.ScanningMode := _YamlRawScanner.Mode.BlockScalar
            }
        }
    }

    /**
     * Manual override for the indentation level used by the scanner.
     */
    ContextIndentOverride {
        get => this._contextIndentOverride
        set => this._contextIndentOverride := value
    }

    /**
     * Whether to ignore comment tokens.
     */
    SkipComments {
        get => this._skipComments
        set => this._skipComments := value
    }

    /**
     * Pushes an indentation level to the stack without generating an INDENT token.
     * @param {Integer} indent
     */
    PushIndentOnly(indent) {
        this._ctx.PushIndentOnly(indent)
    }

    /**
     * Controls whether the scanner should process directives.
     * @param {Boolean} allowed
     */
    SetDirectivesAllowed(allowed) {
        if (this._tracer) {
            this._tracer.Trace("SetDirectivesAllowed: " . (allowed ? "ON" : "OFF"))
        }
        this._scanner.IgnoreDirectives := !allowed
        if (allowed) {
            this._hasSentContent := false ; Reset content flag when starting a new directive block
        }
    }

    /**
     * Resets the processor state.
     */
    SyncAndReset() {
        this._ctx.TokenQueue := _YamlTokenQueue(this._ctx._tracer)
        this._ctx.IndentStack := _YamlIndentStack(this._ctx._tracer)
        this._ctx.ContextStack := _YamlContextStack(this._ctx._tracer)
        this._ctx.ContextStack.Push(_YamlContext.Type.Root)
        this._hasSentStreamStart := false
        this._hasSentContent := false
        this.SetDirectivesAllowed(true)
    }

    /**
     * Captures the current state of the processor.
     * @returns {Object}
     */
    CaptureState() {
        return {
            ctxState: this._ctx.CaptureState(),
            scannerState: this._scanner.CaptureState(),
            isAtLineStart: this._isAtLineStart,
            hasSentStreamStart: this._hasSentStreamStart,
            hasSentContent: this._hasSentContent,
            hint: this._hint,
            lastToken: this._lastToken,
            contextIndentOverride: this._contextIndentOverride,
            skipComments: this._skipComments
        }
    }

    /**
     * Restores the processor to a previously captured state.
     * @param {Object} state
     */
    RestoreState(state) {
        this._ctx.RestoreState(state.ctxState)
        this._scanner.RestoreState(state.scannerState)
        this._isAtLineStart := state.isAtLineStart
        this._hasSentStreamStart := state.hasSentStreamStart
        this._hasSentContent := state.hasSentContent
        this._hint := state.hint
        this._lastToken := state.lastToken
        this._contextIndentOverride := state.contextIndentOverride
        this._skipComments := state.skipComments
    }

    /**
     * Fetches the next layout-aware token.
     * @returns {Object}
     */
    FetchToken() {
        ; Ensure GrammarScope is synced before any scan
        isInFlow := this._ctx.ContextStack.Has(_YamlContext.Type.Flow)
        this._scanner.GrammarScope := isInFlow ? _YamlRawScanner.Scope.Flow : _YamlRawScanner.Scope.Block

        ; Update ContextIndent for the scanner
        if (this._contextIndentOverride != -2) {
            this._scanner.ContextIndent := this._contextIndentOverride
        } else {
            this._scanner.ContextIndent := this._ctx.IndentStack.Current
        }

        if (IsObject(this._hint) && this._hint.HasProp("style")) {
            hint := this._hint
            this.Hint := _YamlLayoutProcessor.Hint.None
            stateHandler := this._ctxStates[_YamlContext.Type.BlockScalar]
            t := stateHandler.CollectScalar(this._ctx, this._scanner, hint)
            this._hasSentContent := true
            return this._lastToken := t
        }
        return this._InternalFetch()
    }

    /**
     * Internal implementation of token fetching.
     * @returns {Object}
     */
    _InternalFetch() {
        if (!this._hasSentStreamStart) {
            this._hasSentStreamStart := true
            state := this._scanner.CaptureState()
            t := this._scanner.Next()
            this._scanner.RestoreState(state)
            return this._lastToken := _YamlToken.StreamStart("", t.line, t.column, t.pos)
        }
        loop {
            ; Sync scanner state with current layout context
            isInFlow := this._ctx.ContextStack.Has(_YamlContext.Type.Flow)
            this._scanner.GrammarScope := isInFlow ? _YamlRawScanner.Scope.Flow : _YamlRawScanner.Scope.Block

            ; Directives are controlled externally by Parser States.
            ; No automatic switching here.

            if (this._isAtLineStart) {
                this._ProcessLineStart()
            }
            if (this._ctx.TokenQueue.Length > 0) {
                return this._lastToken := this._ctx.TokenQueue.Pop()
            }
            t := this._scanner.Next()
            if (t.IsAnyOf(_YamlToken.Type.Space, _YamlToken.Type.Tab)) {
                continue
            }
            if (t.Is(_YamlToken.Type.Comment) && this._skipComments) {
                continue
            }

            if (t.Is(_YamlToken.Type.Text)) {
                t := _YamlToken.Scalar(t.value, t.line, t.column, t.pos, ":", t.len)
                if (t.value == ":" && this._IsValueIndicator(t)) {
                    t := _YamlToken.ValueIndicator(t.value, t.line, t.column, t.pos, t.len)
                }
            } else if (t.Is(_YamlToken.Type.Directive)) {
                if (this._hasSentContent) {
                    throw YamlError("Directives are not allowed after document content", t.line, t.column)
                }
            } else if (t.Is(_YamlToken.Type.Symbol) || t.Is(_YamlToken.Type.Punctuator)) {
                isBlockIndicator := false
                if (t.value == "-") {
                    if (this._IsBlockEntryIndicator(t)) {
                        t := _YamlToken.BlockEntry(t.value, t.line, t.column, t.pos, t.len)
                        isBlockIndicator := true
                    } else {
                        t := _YamlToken.Punctuator(t.value, t.line, t.column, t.pos, t.len)
                    }
                } else if (t.value == "?") {
                    if (this._IsKeyIndicator(t)) {
                        t := _YamlToken.KeyIndicator(t.value, t.line, t.column, t.pos, t.len)
                        isBlockIndicator := true
                    } else {
                        t := _YamlToken.Punctuator(t.value, t.line, t.column, t.pos, t.len)
                    }
                } else if (t.value == ":") {
                    if (this._IsValueIndicator(t)) {
                        t := _YamlToken.ValueIndicator(t.value, t.line, t.column, t.pos, t.len)
                        isBlockIndicator := true
                    } else if (this._ctx.ContextStack.Has(_YamlContext.Type.Flow)) {
                        ; In flow context, a non-indicator colon remains Text
                        ; so it can be joined into a plain scalar (e.g. in URLs).
                        t := _YamlToken.Text(t.value, t.line, t.column, t.pos, t.len)
                    } else {
                        t := _YamlToken.Punctuator(t.value, t.line, t.column, t.pos, t.len)
                    }
                } else {
                    t := _YamlToken.Punctuator(t.value, t.line, t.column, t.pos, t.len)
                }

                if (isBlockIndicator && t.value != ":" && !this._ctx.ContextStack.Has(_YamlContext.Type.Flow)) {
                    this._ctx.PushIndentOnly(t.column)
                }
            }

            if (t.Is(_YamlToken.Type.Newline)) {
                this._isAtLineStart := true
                return this._lastToken := t
            }

            ; If we are emitting a token that counts as document content, set the flag
            if (!t.IsAnyOf(_YamlToken.Type.DocEnd, _YamlToken.Type.Directive, _YamlToken.Type.Comment, _YamlToken.Type.Newline
            )) {
                this._hasSentContent := true
            }

            this._isAtLineStart := false
            stateHandler := this._ctxStates[this._ctx.ContextStack.Current]
            stateHandler.OnToken(this._ctx, t)
            return this._lastToken := t
        }
    }

    /**
     * Determines if a colon is a value indicator.
     * @param {Object} token
     * @returns {Boolean}
     */
    _IsValueIndicator(token) {
        if (this._hint == _YamlLayoutProcessor.Hint.FlowValue) {
            return true
        }

        state := this.CaptureState()
        p1 := this._scanner.Next()

        ; Must be followed by whitespace or end of stream
        if (!p1.IsAnyOf(_YamlToken.Type.Space, _YamlToken.Type.Tab, _YamlToken.Type.Newline, _YamlToken.Type.StreamEnd)) {
            if (this._ctx.ContextStack.Has(_YamlContext.Type.Flow)) {
                ; Check for flow indicators (adjacent colon allowed)
                if (p1.Is(_YamlToken.Type.Punctuator) && InStr("[]{},", p1.value)) {
                    this.RestoreState(state)
                    return true
                }
                ; JSON-like adjacent colon
                if (IsObject(this._lastToken) && !this._lastToken.IsAnyOf(_YamlToken.Type.ValueIndicator, _YamlToken.Type
                    .KeyIndicator)) {
                    isPrecededByNode := this._lastToken.IsAnyOf(_YamlToken.Type.ScalarSQ, _YamlToken.Type.ScalarDQ,
                        _YamlToken.Type.Alias)
                    || (this._lastToken.Is(_YamlToken.Type.Punctuator) && InStr("]}", this._lastToken.value))
                    if (isPrecededByNode && p1.value != ":") {
                        this.RestoreState(state)
                        return true
                    }
                }
            }
            this.RestoreState(state)
            return false
        }

        ; It is an indicator. Now check for illegal tabs in block context.
        this._ValidateIllegalTabs(p1, state)

        this.RestoreState(state)
        return true
    }

    /**
     * Determines if a hyphen is a block entry indicator.
     * @param {Object} token
     * @returns {Boolean}
     */
    _IsBlockEntryIndicator(token) {
        if (this._hint == _YamlLayoutProcessor.Hint.BlockScalarIndicator) {
            return false
        }
        if (this._ctx.ContextStack.Current == _YamlContext.Type.Flow) {
            return false
        }
        state := this.CaptureState()
        p1 := this._scanner.Next()

        ; Must be followed by whitespace or end of stream
        if (!p1.IsAnyOf(_YamlToken.Type.Space, _YamlToken.Type.Tab, _YamlToken.Type.Newline, _YamlToken.Type.StreamEnd)) {
            this.RestoreState(state)
            return false
        }

        ; Check for illegal tabs
        this._ValidateIllegalTabs(p1, state)

        this.RestoreState(state)
        return true
    }

    /**
     * Determines if a question mark is a key indicator.
     * @param {Object} token
     * @returns {Boolean}
     */
    _IsKeyIndicator(token) {
        state := this.CaptureState()
        p1 := this._scanner.Next()

        ; Must be followed by whitespace or end of stream
        if (!p1.IsAnyOf(_YamlToken.Type.Space, _YamlToken.Type.Tab, _YamlToken.Type.Newline, _YamlToken.Type.StreamEnd)) {
            this.RestoreState(state)
            return false
        }

        ; Check for illegal tabs in block context
        this._ValidateIllegalTabs(p1, state)

        this.RestoreState(state)
        return true
    }

    /**
     * Validates that tabs are not used illegally before block collections.
     * @param {Object} p1 - The token immediately following the indicator.
     * @param {Object} state - The captured state to restore if validation fails.
     */
    _ValidateIllegalTabs(p1, state) {
        if (!p1.IsAnyOf(_YamlToken.Type.Tab, _YamlToken.Type.Space)) {
            return
        }
        if (this._ctx.ContextStack.Has(_YamlContext.Type.Flow)) {
            return
        }

        hasTab := p1.Is(_YamlToken.Type.Tab)
        loop {
            pNext := this._scanner.Next()
            if (pNext.Is(_YamlToken.Type.Space)) {
                continue
            }
            if (pNext.Is(_YamlToken.Type.Tab)) {
                hasTab := true
                continue
            }
            if (hasTab) {
                if (pNext.IsAnyOf(_YamlToken.Type.Symbol, _YamlToken.Type.Punctuator) && InStr("-?:", pNext.value)) {
                    this.RestoreState(state)
                    throw YamlError("Tabs are not allowed before block collections", p1.line, p1.column)
                }
                ; Detect implicit mapping
                if (pNext.IsScalar) {
                    state_scalar := this.CaptureState()
                    loop {
                        pAfter := this._scanner.Next()
                        if (pAfter.IsAnyOf(_YamlToken.Type.Space, _YamlToken.Type.Tab)) {
                            continue
                        }
                        if (pAfter.Is(_YamlToken.Type.Symbol) && pAfter.value == ":") {
                            ; It's a mapping key! Check if it's followed by a separator.
                            pAfterColon := this._scanner.Next()
                            if (pAfterColon.IsAnyOf(_YamlToken.Type.Space, _YamlToken.Type.Tab,
                                _YamlToken.Type.Newline, _YamlToken.Type.StreamEnd)) {
                                this.RestoreState(state)
                                throw YamlError("Tabs are not allowed before block collections", p1.line, p1.column)
                            }
                        }
                        break
                    }
                    this.RestoreState(state_scalar)
                }
            }
            break
        }
    }

    /**
     * Processes the start of a new line, handling indentation.
     */
    _ProcessLineStart() {
        this._isAtLineStart := false
        indent := 0
        state_line := this._scanner.CaptureState()

        ; 1. Collect only SPACES for indentation.
        ; The first tab encountered marks the end of indentation and the start of separation/content.
        nextToken := ""
        loop {
            state_lk := this._scanner.CaptureState()
            t := this._scanner.Next()
            if (t.Is(_YamlToken.Type.Space)) {
                indent += t.value
                continue
            }

            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Comment, _YamlToken.Type.StreamEnd)) {
                this._scanner.RestoreState(state_lk)
                return
            }

            ; Special case: If we find a tab, check if it's just trailing whitespace
            if (t.Is(_YamlToken.Type.Tab)) {
                state_peek_tab := this._scanner.CaptureState()
                loop {
                    tn := this._scanner.Next()
                    if (tn.IsAnyOf(_YamlToken.Type.Space, _YamlToken.Type.Tab)) {
                        continue
                    }
                    if (tn.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Comment, _YamlToken.Type.StreamEnd)) {
                        ; The rest of the line is just whitespace/comments.
                        ; This whole line should be ignored for indentation.
                        this._scanner.RestoreState(state_lk)
                        return
                    }
                    ; Real content follows the tab.
                    break
                }
                this._scanner.RestoreState(state_peek_tab)
            }

            ; Found a tab or other token that is NOT trailing whitespace
            nextToken := t
            this._scanner.RestoreState(state_lk)
            break
        }

        ; 2. Validate the next token if it's a tab
        state_peek := this._scanner.CaptureState()
        t_peek := this._scanner.Next()
        if (t_peek.Is(_YamlToken.Type.Tab)) {
            ; A tab is allowed if it's separation (after valid indentation).
            ; However, it's NOT allowed for indenting block collections on a new line.
            isAllowed := this._ctx.ContextStack.Has(_YamlContext.Type.Flow)
            || this._hint == _YamlLayoutProcessor.Hint.PlainScalar
            || this._hint == _YamlLayoutProcessor.Hint.BlockScalarIndicator
            || (IsObject(this._hint) && this._hint.HasProp("style"))

            if (!isAllowed) {
                ; Check if the NEXT-NEXT token is a flow indicator
                state_next := this._scanner.CaptureState()
                loop {
                    tn := this._scanner.Next()
                    if (tn.IsAnyOf(_YamlToken.Type.Space, _YamlToken.Type.Tab)) {
                        continue
                    }
                    if (tn.IsAnyOf(_YamlToken.Type.Symbol, _YamlToken.Type.Punctuator) && InStr("[]{},", tn.value)) {
                        isAllowed := true
                    }
                    break
                }
                this._scanner.RestoreState(state_next)
            }

            if (!isAllowed) {
                ; YAML 1.2.2: Tabs must not be used for indentation.
                ; If we are at or below context indent, it's definitely an indentation attempt.
                if (indent <= this._scanner.ContextIndent) {
                    throw YamlError("Tabs are not allowed for indentation", t_peek.line, t_peek.column)
                }
            }
        }
        this._scanner.RestoreState(state_peek)

        loop {
            stateHandler := this._ctxStates[this._ctx.ContextStack.Current]
            if (!stateHandler.ProcessLineStart(this._ctx, indent, nextToken, this._scanner.ContextIndent)) {
                break
            }
        }
    }
}
