#Requires AutoHotkey v2.0

/**
 * @file _YamlBlockScalarBuilder.ahk
 * @description Helper class to build block scalar content with Literal/Folded and Chomping rules.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Helper class to build block scalar content.
 */
class _YamlBlockScalarBuilder {
    /** @field {String} _style - Scalar style ('|' or '>') */
    _style := ""

    /** @field {String} _chomping - Chomping rule ('strip', 'clip', 'keep') */
    _chomping := ""

    /** @field {String} _content - Accumulated content */
    _content := ""

    /** @field {Array} _pendingEmptyLines - Array of extra spaces for each empty line */
    _pendingEmptyLines := []

    /** @field {Boolean} _isFirstLine - Whether we are processing the first line of content */
    _isFirstLine := true

    /** @field {Boolean} _lastLineWasNormal - Whether the last line was a standard content line */
    _lastLineWasNormal := false

    /**
     * @param {String} style
     * @param {String} chomping
     */
    __New(style, chomping) {
        this._style := style
        this._chomping := chomping
    }

    /**
     * Adds an empty line (or a line containing only spaces beyond block indent).
     * @param {String} extraSpaces - Spaces that are part of the content.
     */
    AddEmptyLine(extraSpaces := "") {
        this._pendingEmptyLines.Push(extraSpaces)
    }

    /**
     * Adds a non-empty content line.
     * @param {String} text - The text content of the line.
     * @param {Boolean} isMoreIndented - Whether this line is more indented than the block.
     * @param {Boolean} hasTab - Whether this line starts with a tab.
     */
    AddContentLine(text, isMoreIndented, hasTab) {
        if (this._isFirstLine) {
            this._isFirstLine := false
            ; Leading empty lines are always preserved as-is
            for spaces in this._pendingEmptyLines {
                this._content .= spaces . "`n"
            }
        }
        else {
            numNewlines := this._pendingEmptyLines.Length + 1

            if (this._style == "|") {
                ; Literal: All newlines and spaces are preserved
                this._content .= "`n"
                for spaces in this._pendingEmptyLines {
                    this._content .= spaces . "`n"
                }
            }
            else { ; Folded ">"
                ; Folding rules:
                ; 1. If the previous or current line is special, preserve all newlines.
                ; 2. If n > 1 newlines exist, result is n-1 newlines.
                ; 3. If exactly 1 newline exists, result is a space.
                if (isMoreIndented || hasTab || !this._lastLineWasNormal) {
                    this._content .= "`n"
                    for spaces in this._pendingEmptyLines {
                        this._content .= spaces . "`n"
                    }
                }
                else if (numNewlines > 1) {
                    loop (numNewlines - 1) {
                        this._content .= "`n"
                        if (A_Index <= this._pendingEmptyLines.Length) {
                            this._content .= this._pendingEmptyLines[A_Index]
                        }
                    }
                }
                else {
                    this._content .= " "
                }
            }
        }

        this._content .= text
        this._pendingEmptyLines := []
        this._lastLineWasNormal := (!isMoreIndented && !hasTab)
    }

    /**
     * Finalizes the content according to chomping rules.
     * @returns {String} The finalized scalar content.
     */
    ToString() {
        result := this._content

        if (this._chomping == "keep") {
            if (result != "" || !this._isFirstLine) {
                result .= "`n"
            }
            for spaces in this._pendingEmptyLines {
                result .= spaces . "`n"
            }
        }
        else if (this._chomping == "strip") {
            ; Trailing empty lines are discarded.
            ; No terminal newline is added.
        }
        else { ; clip
            if (result != "" || !this._isFirstLine) {
                result .= "`n"
            }
        }
        return result
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
