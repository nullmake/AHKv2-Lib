#Requires AutoHotkey v2.0

/**
 * @file _Scanner.ahk
 * @description Tokenizes YAML character stream and manages indentation.
 * @author nullmake
 * @license Apache-2.0
 * 
 * Copyright 2026 nullmake
 */

class _YamlScanner {
    /**
     * @field {String} _source - Normalized source text.
     */
    _source := ""

    /**
     * @field {Integer} _pos - Current character position (1-based).
     */
    _pos := 1

    /**
     * @field {Integer} _line - Current line number (1-based).
     */
    _line := 1

    /**
     * @field {Integer} _column - Current column number (1-based).
     */
    _column := 1

    /**
     * @field {Integer} _length - Total length of the source.
     */
    _length := 0

    /**
     * @field {Array} _indentStack - Stack of indentation levels (absolute columns).
     */
    _indentStack := [0]

    /**
     * @field {Array} _pendingTokens - Queue for Indent/Dedent/Document tokens.
     */
    _pendingTokens := []

    /**
     * @field {Boolean} _isAtLineStart - Flag to trigger indentation check.
     */
    _isAtLineStart := true

    /**
     * @constructor
     * @param {String} input - Raw YAML string.
     */
    __New(input) {
        ; Normalize line breaks to \n (YAML 1.2.2 - 5.4)
        _source := StrReplace(input, "`r`n", "`n")
        this._source := StrReplace(_source, "`r", "`n")
        this._length := StrLen(this._source)
    }

    /**
     * @method FetchToken
     * Advances and returns the next token from the stream.
     * @returns {Object} Token object {Type, Value, Line, Column}
     */
    FetchToken() {
        ; Return queued tokens first (virtual Indent/Dedent)
        if (this._pendingTokens.Length > 0) {
            return this._pendingTokens.RemoveAt(1)
        }

        ; Handle beginning of line (Indentation / Document Boundary)
        if (this._isAtLineStart) {
            this._HandleLineStart()
            if (this._pendingTokens.Length > 0) {
                return this._pendingTokens.RemoveAt(1)
            }
        }

        ; Skip leading horizontal whitespace (spaces)
        this._SkipWhitespace()

        ; Handle end of stream
        if (this._pos > this._length) {
            ; Finalize indentation before ending stream
            if (this._indentStack.Length > 1) {
                this._UnrollIndents(0)
                return this.FetchToken()
            }
            return {Type: "StreamEnd", Value: "", Line: this._line, Column: this._column}
        }

        _char := SubStr(this._source, this._pos, 1)

        ; Line Break
        if (_char == "`n") {
            this._Move(1)
            this._line++
            this._column := 1
            this._isAtLineStart := true
            return this.FetchToken()
        }

        ; Sequence Indicator '-'
        if (_char == "-" && this._IsFollowedByWhitespace(this._pos + 1)) {
            _token := {Type: "SequenceIndicator", Value: "-", Line: this._line, Column: this._column}
            this._Move(1)
            return _token
        }

        ; Mapping Indicator Lookahead
        if (RegExMatch(SubStr(this._source, this._pos), "^(?<_scalar>[^:#\s\n]+)(?<_indicator>:\s|:$|:\n)", &_match)) {
            _token := {Type: "Scalar", Value: _match._scalar, Line: this._line, Column: this._column}
            this._Move(StrLen(_match._scalar))
            return _token
        }

        ; Mapping Indicator ':'
        if (_char == ":" && this._IsFollowedByWhitespace(this._pos + 1)) {
            _token := {Type: "MappingIndicator", Value: ":", Line: this._line, Column: this._column}
            this._Move(1)
            return _token
        }

        ; Default Plain Scalar
        if (RegExMatch(SubStr(this._source, this._pos), "^[^:\s#\n]+", &_match)) {
            _val := _match[0]
            _token := {Type: "Scalar", Value: _val, Line: this._line, Column: this._column}
            this._Move(StrLen(_val))
            return _token
        }

        ; Fallback for any single character
        _val := SubStr(this._source, this._pos, 1)
        _token := {Type: "Scalar", Value: _val, Line: this._line, Column: this._column}
        this._Move(1)
        return _token
    }

    /**
     * @method _HandleLineStart
     * Manages indentation levels and document boundaries at the start of a line.
     */
    _HandleLineStart() {
        this._isAtLineStart := false
        _currentIndent := 0

        ; Count leading spaces and check for illegal tabs
        while (this._pos <= this._length) {
            _char := SubStr(this._source, this._pos, 1)
            if (_char == " ") {
                _currentIndent++
                this._Move(1)
            } else if (_char == "`t") {
                throw YamlError("Tab characters are not allowed for indentation", this._line, this._column)
            } else {
                break
            }
        }

        ; Check for Document Boundary (---)
        if (_currentIndent == 0 && RegExMatch(SubStr(this._source, this._pos), "^---(\s|\n|$)")) {
            this._UnrollIndents(0)
            this._pendingTokens.Push({Type: "DocumentStart", Value: "---", Line: this._line, Column: 1})
            this._Move(3)
            return
        }

        ; Skip empty lines
        if (this._pos <= this._length && SubStr(this._source, this._pos, 1) == "`n") {
            this._isAtLineStart := true
            return
        }

        ; Compare with current indentation stack
        _lastIndent := this._indentStack[this._indentStack.Length]
        if (_currentIndent > _lastIndent) {
            this._indentStack.Push(_currentIndent)
            this._pendingTokens.Push({Type: "Indent", Value: _currentIndent, Line: this._line, Column: 1})
        } else if (_currentIndent < _lastIndent) {
            this._UnrollIndents(_currentIndent)
        }
    }

    /**
     * @method _UnrollIndents
     * Generates Dedent tokens until the current indentation level is matched.
     * @param {Integer} targetIndent - The indentation level to match.
     */
    _UnrollIndents(targetIndent) {
        while (this._indentStack.Length > 1 && this._indentStack[this._indentStack.Length] > targetIndent) {
            this._indentStack.Pop()
            this._pendingTokens.Push({Type: "Dedent", Value: "", Line: this._line, Column: 1})
        }
        
        ; Optional: Validate that targetIndent matches a previous level (YAML 1.2.2 - 6.1)
        if (this._indentStack[this._indentStack.Length] != targetIndent) {
             throw YamlError("Indentation level mismatch", this._line, targetIndent + 1)
        }
    }

    /**
     * @method _SkipWhitespace
     * Consumes horizontal spaces at the current position.
     */
    _SkipWhitespace() {
        while (this._pos <= this._length) {
            _char := SubStr(this._source, this._pos, 1)
            if (_char == " ") {
                this._Move(1)
            } else {
                break
            }
        }
    }

    /**
     * @method _IsFollowedByWhitespace
     * Checks if the character at the given position is whitespace or end of stream.
     * @param {Integer} pos - Position to check.
     * @returns {Boolean}
     */
    _IsFollowedByWhitespace(pos) {
        if (pos > this._length) {
            return true
        }
        _next := SubStr(this._source, pos, 1)
        return (_next == " " || _next == "`n")
    }

    /**
     * @method _Move
     * Updates the position and column counters.
     * @param {Integer} count - Number of characters moved.
     */
    _Move(count) {
        this._pos += count
        this._column += count
    }
}
