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
    _sourceLength := 0

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
    * @field {Integer} _loopCount - Safety counter for infinite loop detection.
    */
    _loopCount := 0

    /**
    * @field {Integer} _lastPos - Last recorded position to detect progress.
    */
    _lastPos := 0

    /**
    * @constructor
    * @param {String} input - Raw YAML string.
    */
    __New(input) {
        ; Normalize line breaks to \n (YAML 1.2.2 - 5.4)
        _source := StrReplace(input, "`r`n", "`n")
        this._source := StrReplace(_source, "`r", "`n")
        this._sourceLength := StrLen(this._source)
    }

    /**
    * @method FetchToken
    * Advances and returns the next token from the stream.
    * @returns {Object} Token object {type, value, line, column, style}
    */
    FetchToken() {
        ; Safety: Prevent infinite loops by checking if position advances
        if (this._pos == this._lastPos) {
            this._loopCount++
            if (this._loopCount > 1000) {
                throw YamlError("Infinite loop detected in Scanner at position " . this._pos, this._line, this._column)
            }
        } else {
            this._lastPos := this._pos
            this._loopCount := 0
        }

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
        if (this._pos > this._sourceLength) {
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

        ; Block Scalar Indicators
        if (_char == "|" || _char == ">") {
            return this._ScanBlockScalar(_char)
        }

        ; Anchors and Aliases
        if (_char == "&" || _char == "*") {
            _type := (_char == "&") ? "Anchor" : "Alias"
            this._Move(1)
            if (RegExMatch(SubStr(this._source, this._pos), "^[a-zA-Z0-9_-]+", &_match)) {
                _val := _match[0]
                _token := {type: _type, value: _val, line: this._line, column: this._column - 1}
                this._Move(StrLen(_val))
                return _token
            }
            throw YamlError("Invalid " . _type . " name", this._line, this._column)
        }

        ; Tags
        if (_char == "!") {
            if (RegExMatch(SubStr(this._source, this._pos), "^!!?[a-zA-Z0-9_-]*", &_match)) {
                _val := _match[0]
                _token := {type: "Tag", value: _val, line: this._line, column: this._column}
                this._Move(StrLen(_val))
                return _token
            }
        }

        ; Flow Indicators
        if (InStr("[]{},", _char)) {
            _type := (_char == "[") ? "FlowSequenceStart"
                    : (_char == "]") ? "FlowSequenceEnd"
                    : (_char == "{") ? "FlowMappingStart"
                    : (_char == "}") ? "FlowMappingEnd"
                    : "FlowEntrySeparator"

            _token := {type: _type, value: _char, line: this._line, column: this._column}
            this._Move(1)
            return _token
        }

        ; Sequence Indicator '-'
        if (_char == "-" && this._IsFollowedByWhitespace(this._pos + 1)) {
            _token := {type: "SequenceIndicator", value: "-", line: this._line, column: this._column}
            this._Move(1)
            return _token
        }

        ; Mapping Indicator Lookahead
        if (RegExMatch(SubStr(this._source, this._pos), "^(?<_scalar>(?:[^:#\s\n\[\]{},]|(?<!\s)#)+)(?<_indicator>:\s|:$|:\n|:[\]},])", &_match)) {
            _token := {type: "Scalar", value: _match._scalar, line: this._line, column: this._column, style: 0}
            this._Move(StrLen(_match._scalar))
            return _token
        }

        ; Mapping Indicator ':'
        if (_char == ":" && (this._IsFollowedByWhitespace(this._pos + 1) || InStr("]}", SubStr(this._source, this._pos + 1, 1)))) {
            _token := {type: "MappingIndicator", value: ":", line: this._line, column: this._column}
            this._Move(1)
            return _token
        }

        ; Default Plain Scalar
        if (RegExMatch(SubStr(this._source, this._pos), "^(?:[^:#\s\n\[\]{},]|(?<!\s)#)+", &_match)) {
            _val := _match[0]
            _token := {type: "Scalar", value: _val, line: this._line, column: this._column, style: 0}
            this._Move(StrLen(_val))
            return _token
        }

        ; Fallback for any single character
        _val := SubStr(this._source, this._pos, 1)
        _token := {type: "Scalar", value: _val, line: this._line, column: this._column, style: 0}
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
        while (this._pos <= this._sourceLength) {
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

        ; Check for Document Boundaries (---, ...) or Directives (%)
        if (_currentIndent == 0) {
            _rem := SubStr(this._source, this._pos)
            if (RegExMatch(_rem, "^---(\s|\n|$)")) {
                this._UnrollIndents(0)
                this._pendingTokens.Push({type: "DocumentStart", value: "---", line: this._line, column: 1})
                this._Move(3)
                return
            } else if (RegExMatch(_rem, "^\.\.\.(\s|\n|$)")) {
                this._UnrollIndents(0)
                this._pendingTokens.Push({type: "DocumentEnd", value: "...", line: this._line, column: 1})
                this._Move(3)
                return
            } else if (SubStr(_rem, 1, 1) == "%") {
                ; Parse directive line
                RegExMatch(_rem, "^%[^\n]*", &_match)
                this._pendingTokens.Push({type: "Directive", value: _match[0], line: this._line, column: 1})
                this._Move(StrLen(_match[0]))
                return
            }
        }

        ; Skip empty lines or full-line comments
        _nextChar := SubStr(this._source, this._pos, 1)
        if (this._pos <= this._sourceLength && (_nextChar == "`n" || _nextChar == "#")) {
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
        while (this._pos <= this._sourceLength) {
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
    */
    _SkipComment() {
        while (this._pos <= this._sourceLength && SubStr(this._source, this._pos, 1) != "`n") {
            this._Move(1)
        }
    }

    /**
    * @method _ScanQuotedScalar
    */
    _ScanQuotedScalar(quote) {
        static _escapes := Map(
            "0", "`0", "a", "`a", "b", "`b", "t", "`t", "n", "`n",
            "v", "`v", "f", "`f", "r", "`r", "e", "`e",
            " ", " ", '"', '"', "/", "/", "\", "\",
            "N", "`n", "L", "`n", "P", " "
        )

        _startLine := this._line
        _startCol := this._column
        this._Move(1) ; Consume opening quote

        _val := ""
        _style := (quote == "'") ? 1 : 2

        while (this._pos <= this._sourceLength) {
            _char := SubStr(this._source, this._pos, 1)

            if (_char == quote) {
                this._Move(1) ; Consume closing quote
                return {type: "Scalar", value: _val, line: _startLine, column: _startCol, style: _style}
            }

            if (_char == "\") {
                if (quote == "'") {
                    _val .= "\"
                } else {
                    this._Move(1)
                    _nextChar := SubStr(this._source, this._pos, 1)
                    if (_escapes.Has(_nextChar)) {
                        _val .= _escapes[_nextChar]
                    } else if (_nextChar == "`n") {
                        ; Escaped line break
                    } else {
                        throw YamlError("Invalid escape sequence: \" . _nextChar, this._line, this._column)
                    }
                    this._Move(1)
                    continue
                }
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
    * @method _ScanBlockScalar
    * Reads literal (|) or folded (>) block scalars with chopping support (+, -).
    */
    _ScanBlockScalar(indicator) {
        _startLine := this._line
        _startCol := this._column
        this._Move(1) ; Consume '|' or '>'

        _style := (indicator == "|") ? 3 : 4

        ; Parse chopping indicator
        _chopping := "clip"
        _next := SubStr(this._source, this._pos, 1)
        if (_next == "-") {
            _chopping := "strip"
            this._Move(1)
        } else if (_next == "+") {
            _chopping := "keep"
            this._Move(1)
        }

        ; Skip trailing space and comment on the indicator line
        this._SkipWhitespaceAndComments()
        if (this._pos <= this._sourceLength && SubStr(this._source, this._pos, 1) == "`n") {
            this._Move(1)
            this._line++
            this._column := 1
        }

        _blockIndent := 0
        _content := ""
        _isFirstLine := true
        _lastLineEmpty := false

        while (this._pos <= this._sourceLength) {
            _currentLineIndent := 0
            _tempPos := this._pos
            while (_tempPos <= this._sourceLength && SubStr(this._source, _tempPos, 1) == " ") {
                _currentLineIndent++
                _tempPos++
            }

            _charAfterIndent := SubStr(this._source, _tempPos, 1)

            ; Check for block end
            if (_charAfterIndent != "`n" && _currentLineIndent <= this._indentStack[this._indentStack.Length]) {
                break
            }

            if (_isFirstLine && _charAfterIndent != "`n") {
                _blockIndent := _currentLineIndent
                _isFirstLine := false
            }

            if (_charAfterIndent == "`n") {
                _content .= "`n"
                _lastLineEmpty := true
                this._Move(_currentLineIndent + 1)
            } else {
                if (_currentLineIndent < _blockIndent) {
                    throw YamlError("Less indentation than block start", this._line, _currentLineIndent + 1)
                }

                this._Move(_blockIndent)
                _lineText := ""
                while (this._pos <= this._sourceLength && SubStr(this._source, this._pos, 1) != "`n") {
                    _lineText .= SubStr(this._source, this._pos, 1)
                    this._Move(1)
                }

                if (indicator == ">" && _content != "" && SubStr(_content, -1) == "`n" && !_lastLineEmpty) {
                    _content := SubStr(_content, 1, -1) . " "
                }

                _content .= _lineText
                _lastLineEmpty := false

                if (this._pos <= this._sourceLength && SubStr(this._source, this._pos, 1) == "`n") {
                    _content .= "`n"
                    this._Move(1)
                }
            }
            this._line++
            this._column := 1
        }

        ; Handle Chopping
        if (_chopping == "strip") {
            _content := RTrim(_content, "`n")
        } else if (_chopping == "clip") {
            if (_content != "") {
                _content := RTrim(_content, "`n") . "`n"
            }
        }

        this._isAtLineStart := true
        return {type: "Scalar", value: _content, line: _startLine, column: _startCol, style: _style}
    }

    /**
    * @method _IsFollowedByWhitespace
    */
    _IsFollowedByWhitespace(pos) {
        if (pos > this._sourceLength) {
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
