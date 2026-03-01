#Requires AutoHotkey v2.0

/**
 * @file _BlockScalarContext.ahk
 * @description Concrete class for block scalar collection context.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Concrete class for block scalar collection.
 */
class _BlockScalarContext extends _YamlContext {
    /** @field {Integer} _blockIndent - Established block indentation */
    _blockIndent := 0

    /**
     * Processes the start of a line in block scalar context.
     * @param {Object} ctx
     * @param {Integer} indent
     * @param {Object} nextToken
     * @param {Integer} contextIndent
     * @returns {Boolean}
     */
    ProcessLineStart(ctx, indent, nextToken, contextIndent) {
        parentIndent := ctx.IndentStack.Current
        if (indent <= parentIndent) {
            ctx.ContextStack.Pop()
            ctx.BlockScalarIndent := -1
            return true
        }
        if (ctx.BlockScalarIndent == -1) {
            ctx.BlockScalarIndent := indent
        }
        return false
    }

    /**
     * @inheritdoc
     */
    OnToken(ctx, token) => false

    /**
     * Collects a block scalar value.
     * @param {Object} ctx
     * @param {Object} scanner
     * @param {Object} hint
     * @returns {Object} Scalar token
     */
    CollectScalar(ctx, scanner, hint) {
        parentIndent := (hint.HasProp("parentIndent")) ? hint.parentIndent : ctx.IndentStack.Current
        this._blockIndent := hint.indent ; Explicit indent indicator (e.g., |2)
        if (this._blockIndent > 0) {
            this._blockIndent += parentIndent
        }

        builder := _YamlBlockScalarBuilder(hint.style, hint.chomping)
        leadingEmptyLines := []

        origScanningMode := scanner.ScanningMode
        scanner.ScanningMode := _YamlRawScanner.Mode.BlockScalar

        try {
            loop {
                state_line := scanner.CaptureState()

                ; 1. Calculate line indentation (Spaces ONLY)
                lineIndent := 0
                loop {
                    state_sp := scanner.CaptureState()
                    t := scanner.Next()
                    if (t.Is(_YamlToken.Type.Space)) {
                        lineIndent += 1
                        continue
                    }
                    scanner.RestoreState(state_sp)
                    break
                }

                ; 2. Peek at the first significant character of the line
                t := scanner.Next()
                hasTabAtLineStart := t.Is(_YamlToken.Type.Tab)
                if (hasTabAtLineStart && lineIndent <= parentIndent) {
                    ; A tab is only an error if it's in the indentation area.
                    ; If it's already past the indentation area, it's content.
                    ; Wait! In block scalars, any tab at the start of a line
                    ; (after leading spaces) is considered part of the indentation area
                    ; if the indent is not yet established.
                    if (this._blockIndent == 0 || lineIndent < this._blockIndent) {
                        throw YamlError("Tabs are not allowed for indentation", t.line, t.column)
                    }
                }

                if (t.IsAnyOf(_YamlToken.Type.DocStart, _YamlToken.Type.DocEnd)) {
                    this._FlushLeading(builder, leadingEmptyLines, parentIndent)
                    scanner.RestoreState(state_line)
                    break
                }

                if (t.Is(_YamlToken.Type.StreamEnd)) {
                    this._HandleStreamEnd(builder, leadingEmptyLines, lineIndent, parentIndent)
                    scanner.RestoreState(state_line)
                    break
                }

                isEmpty := t.Is(_YamlToken.Type.Newline)
                ; A line is considered content if it's not a newline, OR if it's a newline but more indented than block
                isContent := !isEmpty || (this._blockIndent > 0 && lineIndent > this._blockIndent)

                ; 3. Indentation Logic (Structure-based)
                if (this._blockIndent == 0) {
                    if (!isContent && !hasTabAtLineStart) {
                        ; Leading empty line: keep track of it
                        leadingEmptyLines.Push({ indent: lineIndent, line: t.line })
                        continue ; Newline already consumed
                    } else {
                        ; First content line determines the block indent
                        if (lineIndent <= parentIndent && !hasTabAtLineStart) {
                            ; Content at or before parent indent ends the scalar
                            this._FlushLeading(builder, leadingEmptyLines, parentIndent)
                            scanner.RestoreState(state_line)
                            break
                        }
                        this._blockIndent := lineIndent

                        ; Flush buffered leading lines, adjusting their relative indentation.
                        ; VALIDATION: Leading empty lines must not be more indented than the block scalar.
                        for item in leadingEmptyLines {
                            if (item.indent > this._blockIndent) {
                                throw YamlError(
                                    "Leading empty lines in block scalar cannot be more indented than the first content line",
                                    item.line, item.indent)
                            }
                            builder.AddEmptyLine(this._RepeatStr(" ", Max(0, item.indent - this._blockIndent)))
                        }
                        leadingEmptyLines := []
                    }
                } else if (!isEmpty && lineIndent < this._blockIndent && !hasTabAtLineStart) {
                    ; Non-empty line with insufficient indentation ends the scalar.
                    ; Pure empty lines (isEmpty=true) NEVER end a block scalar regardless of indentation.
                    scanner.RestoreState(state_line)
                    break
                }

                ; 4. Content Gathering
                if (isContent) {
                    text := ""
                    ; Any spaces BEYOND _blockIndent are part of the content.
                    if (lineIndent > this._blockIndent) {
                        text .= this._RepeatStr(" ", lineIndent - this._blockIndent)
                    }

                    if (!isEmpty) {
                        ; Add the first token found after leading spaces
                        if (t.Is(_YamlToken.Type.Tab)) {
                            text .= this._RepeatStr("`t", t.value)
                        } else if (t.HasProp("value")) {
                            text .= t.value
                        }

                        ; Consume the rest of the line until Newline
                        loop {
                            state_char := scanner.CaptureState()
                            tn := scanner.Next()
                            if (tn.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.StreamEnd, _YamlToken.Type.DocStart,
                                _YamlToken.Type.DocEnd)) {
                                scanner.RestoreState(state_char)
                                break
                            }
                            if (tn.Is(_YamlToken.Type.Space)) {
                                text .= this._RepeatStr(" ", tn.value)
                            } else if (tn.Is(_YamlToken.Type.Tab)) {
                                text .= this._RepeatStr("`t", tn.value)
                            } else if (tn.HasProp("value")) {
                                text .= tn.value
                            }
                        }

                        ; Consume the ending newline
                        state_pre_nl := scanner.CaptureState()
                        if (!scanner.Next().Is(_YamlToken.Type.Newline)) {
                            scanner.RestoreState(state_pre_nl)
                        }
                    }

                    ; Pass isMoreIndented and hasTab flag to builder
                    builder.AddContentLine(text, lineIndent > this._blockIndent, hasTabAtLineStart)
                } else {
                    ; Empty line (already determined blockIndent)
                    builder.AddEmptyLine(this._RepeatStr(" ", Max(0, lineIndent - this._blockIndent)))
                }
            }
        } finally {
            scanner.ScanningMode := origScanningMode
        }

        result := builder.ToString()
        return _YamlToken.Scalar(result, hint.line, hint.column, 0, hint.style)
    }

    /**
     * Handles the end of the stream within a block scalar.
     * @param {Object} builder
     * @param {Array} leadingEmptyLines
     * @param {Integer} lineIndent
     * @param {Integer} parentIndent
     */
    _HandleStreamEnd(builder, leadingEmptyLines, lineIndent, parentIndent) {
        if (this._blockIndent == 0) {
            ; Try to establish indent from leading lines
            for item in leadingEmptyLines {
                if (item.indent > parentIndent) {
                    this._blockIndent := item.indent
                    break
                }
            }
            ; Also check the current space-only line
            if (this._blockIndent == 0 && lineIndent > parentIndent) {
                this._blockIndent := lineIndent
            }
        }

        if (this._blockIndent > 0) {
            if (lineIndent > this._blockIndent) {
                ; More indented than block: Treat as a content line.
                this._FlushLeading(builder, leadingEmptyLines, parentIndent)
                builder.AddContentLine(this._RepeatStr(" ", lineIndent - this._blockIndent), true, false)
            } else if (lineIndent == this._blockIndent) {
                ; Exactly at block indent: Treat as an empty content line.
                this._FlushLeading(builder, leadingEmptyLines, parentIndent)
                builder.AddEmptyLine("")
            } else {
                ; Less indented: Just flush leading lines.
                this._FlushLeading(builder, leadingEmptyLines, parentIndent)
            }
        } else {
            this._FlushLeading(builder, leadingEmptyLines, parentIndent)
        }
    }

    /**
     * Flushes buffered leading empty lines to the builder.
     * @param {Object} builder
     * @param {Array} leadingEmptyLines
     * @param {Integer} [parentIndent=0]
     */
    _FlushLeading(builder, leadingEmptyLines, parentIndent := 0) {
        effectiveIndent := (this._blockIndent > 0) ? this._blockIndent : parentIndent
        for item in leadingEmptyLines {
            builder.AddEmptyLine(this._RepeatStr(" ", Max(0, item.indent - effectiveIndent)))
        }
    }

    /**
     * Repeats a string n times.
     * @param {String} s
     * @param {Integer} n
     * @returns {String}
     */
    _RepeatStr(s, n) {
        r := ""
        loop n {
            r .= s
        }
        return r
    }
}
