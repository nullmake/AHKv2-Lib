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
    * @returns {Object} Token object {type, value, line, column}
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

        ; Skip leading horizontal whitespace and comments
        this._SkipWhitespaceAndComments()

        ; Handle end of stream
        if (this._pos > this._length) {
            ; Finalize indentation before ending stream
            if (this._indentStack.Length > 1) {
                this._UnrollIndents(0)
                return this.FetchToken()
            }
            return {type: "StreamEnd", value: "", line: this._line, column: this._column}
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

        ; Quoted Scalars
        if (_char == '"' || _char == "'") {
            return this._ScanQuotedScalar(_char)
        }

        ; Sequence Indicator '-'
        if (_char == "-" && this._IsFollowedByWhitespace(this._pos + 1)) {
            _token := {type: "SequenceIndicator", value: "-", line: this._line, column: this._column}
            this._Move(1)
            return _token
        }

        ; Mapping Indicator Lookahead
        ; Captures scalar characters, allowing '#' if NOT preceded by whitespace.
        if (RegExMatch(SubStr(this._source, this._pos), "^(?<_scalar>(?:[^:#\s\n]|(?<!\s)#)+)(?<_indicator>:\s|:$|:\n)", &_match)) {
            _token := {type: "Scalar", value: _match._scalar, line: this._line, column: this._column}
            this._Move(StrLen(_match._scalar))
            return _token
        }

        ; Mapping Indicator ':'
        if (_char == ":" && this._IsFollowedByWhitespace(this._pos + 1)) {
            _token := {type: "MappingIndicator", value: ":", line: this._line, column: this._column}
            this._Move(1)
            return _token
        }

        ; Default Plain Scalar
        ; Stops at ':' followed by space, or a '#' preceded by space.
        if (RegExMatch(SubStr(this._source, this._pos), "^(?:[^:#\s\n]|(?<!\s)#)+", &_match)) {
            _val := _match[0]
            _token := {type: "Scalar", value: _val, line: this._line, column: this._column}
            this._Move(StrLen(_val))
            return _token
        }

        ; Fallback for any single character
        _val := SubStr(this._source, this._pos, 1)
        _token := {type: "Scalar", value: _val, line: this._line, column: this._column}
        this._Move(1)
        return _token
    }

    /**
    * @method _HandleLineStart
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
            this._pendingTokens.Push({type: "DocumentStart", value: "---", line: this._line, column: 1})
            this._Move(3)
            return
        }

        ; Skip empty lines or full-line comments
        _nextChar := SubStr(this._source, this._pos, 1)
        if (this._pos <= this._length && (_nextChar == "`n" || _nextChar == "#")) {
            if (_nextChar == "#") {
                this._SkipComment()
            }
            this._isAtLineStart := true
            return
        }

        ; Compare with current indentation stack
        _lastIndent := this._indentStack[this._indentStack.Length]
        if (_currentIndent > _lastIndent) {
            this._indentStack.Push(_currentIndent)
            this._pendingTokens.Push({type: "Indent", value: _currentIndent, line: this._line, column: 1})
        } else if (_currentIndent < _lastIndent) {
            this._UnrollIndents(_currentIndent)
        }
    }

    /**
    * @method _UnrollIndents
    */
    _UnrollIndents(targetIndent) {
        while (this._indentStack.Length > 1 && this._indentStack[this._indentStack.Length] > targetIndent) {
            this._indentStack.Pop()
            this._pendingTokens.Push({type: "Dedent", value: "", line: this._line, column: 1})
        }

        if (this._indentStack[this._indentStack.Length] != targetIndent) {
            throw YamlError("Indentation level mismatch", this._line, targetIndent + 1)
        }
    }

    /**
    * @method _SkipWhitespaceAndComments
    */
    _SkipWhitespaceAndComments() {
        loop {
            this._SkipWhitespace()
            ; '#' is a comment only if at line start (column 1) or preceded by space.
            if (SubStr(this._source, this._pos, 1) == "#") {
                this._SkipComment()
            } else {
                break
            }
        }
    }

    /**
    * @method _SkipWhitespace
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
    * @method _SkipComment
    * Consumes characters from '#' until the next line break.
    */
    _SkipComment() {
        while (this._pos <= this._length && SubStr(this._source, this._pos, 1) != "`n") {
            this._Move(1)
        }
    }

    /**
    * @method _ScanQuotedScalar
    * Reads a string enclosed in double or single quotes.
    * @param {String} quote - The opening quote character.
    */
    _ScanQuotedScalar(quote) {
        _startLine := this._line
        _startCol := this._column
        this._Move(1) ; Consume opening quote

        _val := ""
        while (this._pos <= this._length) {
            _char := SubStr(this._source, this._pos, 1)

            if (_char == quote) {
                this._Move(1) ; Consume closing quote
                return {type: "Scalar", value: _val, line: _startLine, column: _startCol}
            }

            if (_char == "`n") {
                this._line++
                this._column := 1
            }

            _val .= _char
            this._Move(1)
        }

        throw YamlError("Unclosed quoted scalar", _startLine, _startCol)
    }

    /**
    * @method _IsFollowedByWhitespace
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
    */
    _Move(count) {
        this._pos += count
        this._column += count
    }
}
