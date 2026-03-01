#Requires AutoHotkey v2.0

/**
 * @file _YamlLayoutProcessorContext.ahk
 * @description Context data used by the YAML LayoutProcessor.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Context data used by the YAML LayoutProcessor.
 */
class _YamlLayoutProcessorContext {
    /** @field {YamlOptions} _options - Configuration options */
    _options := unset

    /** @field {Object} _contextStack - Stack of layout context types */
    _contextStack := unset

    /** @field {Object} _indentStack - Stack of indentation levels */
    _indentStack := unset

    /** @field {Object} _tokenQueue - Queue of tokens to be emitted */
    _tokenQueue := unset

    /** @field {Integer} _blockScalarIndent - Current indentation of a block scalar (-1 if not established) */
    _blockScalarIndent := -1

    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /**
     * @param {YamlOptions} [options] - Configuration options
     */
    __New(options := "") {
        this._options := (options is YamlOptions) ? options : YamlOptions(options)
        this._tracer := this._options.CreateTracer("Layout")
        this._contextStack := _YamlContextStack(this._tracer)
        this._indentStack := _YamlIndentStack(this._tracer)
        this._tokenQueue := _YamlTokenQueue(this._tracer)
    }

    ;-------------------------------------
    ;               Context
    ;-------------------------------------
    /**
     * Context Stack.
     */
    ContextStack {
        get => this._contextStack
        set => this._contextStack := value
    }

    ;-------------------------------------
    ;             Token Queue
    ;-------------------------------------
    /**
     * Token Queue.
     */
    TokenQueue {
        get => this._tokenQueue
        set => this._tokenQueue := value
    }

    ;-------------------------------------
    ;                Indent
    ;-------------------------------------
    /**
     * Established block scalar indentation.
     */
    BlockScalarIndent {
        get => this._blockScalarIndent
        set => this._blockScalarIndent := value
    }

    /**
     * Indentation Stack.
     */
    IndentStack {
        get => this._indentStack
        set => this._indentStack := value
    }

    /**
     * Captures the current state of the context.
     * @returns {Object}
     */
    CaptureState() {
        return {
            contextStack: this._contextStack.Clone(),
            indentStack: this._indentStack.Clone(),
            tokenQueue: this._tokenQueue.Clone(),
            blockScalarIndent: this._blockScalarIndent
        }
    }

    /**
     * Restores the context to a previously captured state.
     * @param {Object} state
     */
    RestoreState(state) {
        this._contextStack := state.contextStack
        this._indentStack := state.indentStack
        this._tokenQueue := state.tokenQueue
        this._blockScalarIndent := state.blockScalarIndent
    }

    /**
     * Handles indentation changes and generates INDENT/DEDENT tokens.
     * @param {Integer} indent - New indentation level
     * @param {Object} nextToken - The token following the indentation
     */
    HandleIndentation(indent, nextToken) {
        lastIndent := this._indentStack[this._indentStack.Length]
        if (this._tracer) {
            this._tracer.Trace(Format("HandleIndentation: indent={} lastIndent={} stack={}",
                indent, lastIndent, this._indentStack.ToString()))
        }

        if (indent > lastIndent) {
            this._indentStack.Push(indent)
            this.TokenQueue.Push(_YamlToken.Indent(indent, nextToken.line, nextToken.column, nextToken.pos))
        }
        else if (indent < lastIndent) {
            while (this._indentStack.Length > 1 && indent < this._indentStack[this._indentStack.Length]) {
                this._indentStack.Pop()
                t := _YamlToken.Dedent(indent, nextToken.line, nextToken.column, nextToken.pos)
                this.TokenQueue.Push(t)
            }

            ; VALIDATION: After popping, the current indent MUST match the new top of stack.
            ; YAML 1.2.2 requires dedents to align with a previous indentation level.
            if (indent != this._indentStack[this._indentStack.Length]) {
                throw YamlError("Indentation level mismatch (does not align with any parent level)",
                    nextToken.line, nextToken.column)
            }
        }
    }

    /**
     * Pushes an indentation level to the stack without generating an INDENT token.
     * @param {Integer} indent
     */
    PushIndentOnly(indent) {
        lastIndent := this._indentStack[this._indentStack.Length]
        if (indent > lastIndent) {
            this._indentStack.Push(indent)
            if (this._tracer) {
                this._tracer.Trace("INDENT_PUSH_ONLY: " . indent)
            }
        }
    }

    ;-------------------------------------
    ;             Utilities
    ;-------------------------------------
    /**
     * Outputs a trace message.
     * @param {String} msg
     */
    Trace(msg) {
        if (this._tracer) {
            this._tracer.Trace(msg)
        }
    }
}
