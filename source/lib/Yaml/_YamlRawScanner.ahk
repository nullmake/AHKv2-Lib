#Requires AutoHotkey v2.0

/**
 * @file _YamlRawScanner.ahk
 * @description Layer 1: Context-free lexical analysis. Scans YAML source text into raw tokens.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Raw scanner for YAML.
 */
class _YamlRawScanner {
    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /** @field {YamlOptions} _options - Configuration options */
    _options := unset

    /** @field {String} _source - Normalized source text */
    _source := ""

    /** @field {Integer} _len - Length of the source text */
    _len := 0

    /** @field {Integer} _pos - Current character position (1-based) */
    _pos := 1

    /** @field {Integer} _line - Current line number */
    _line := 1

    /** @field {Integer} _column - Current column position */
    _column := 0

    /** @field {Integer} _scanningMode - Current scanning mode (determines termination rules) */
    _scanningMode := _YamlRawScanner.Mode.None

    /** @field {Integer} _grammarScope - Current grammar scope (Block or Flow) */
    _grammarScope := _YamlRawScanner.Scope.Block

    /** @field {Object} _currentContext - Current scanner state/context */
    _currentContext := unset

    /** @field {Integer} _contextIndent - Indentation level of the parent container */
    _contextIndent := 0

    /** @field {Boolean} _isAtLineStart - Whether we are at the beginning of a line */
    _isAtLineStart := true

    /** @field {Boolean} IgnoreDirectives - Whether to ignore '%' directives */
    IgnoreDirectives := false

    /**
     * Scanning Modes (Determines termination conditions)
     */
    class Mode {
        static None := 0
        static PlainScalar := 1
        static BlockScalar := 2
        static FlowValue := 3
    }

    /**
     * Grammar Scopes (Determines character interpretation rules)
     */
    class Scope {
        static Block := 1
        static Flow := 2
    }

    ; Characters that have special meaning as indicators at the start of a token.
    static _indicators := "-?:,[]{}#&*!|>" . Chr(39) . Chr(34) . "%@"

    /**
     * @param {String} source - YAML source text
     * @param {YamlOptions} [options] - Configuration options
     */
    __New(source, options := "") {
        this._options := (options is YamlOptions) ? options : YamlOptions(options)
        this._tracer := this._options.CreateTracer("RawScanner")
        this._source := StrReplace(source, "`r`n", "`n")
        this._source := StrReplace(this._source, "`r", "`n")
        this._len := StrLen(this._source)
        this._isAtLineStart := true
        this._currentContext := this.CaptureState()
    }

    /**
     * Indentation level of the parent container.
     */
    ContextIndent {
        get => this._contextIndent
        set => this._contextIndent := value
    }

    /**
     * Current scanning mode.
     */
    ScanningMode {
        get => this._scanningMode
        set => this._scanningMode := value
    }

    /**
     * Current grammar scope.
     */
    GrammarScope {
        get => this._grammarScope
        set => this._grammarScope := value
    }

    /**
     * Emits a token and updates the scanner context.
     * @param {Object} token
     * @returns {Object} The same token
     */
    _Emit(token) {
        token.scannerContext := this._currentContext
        token.endLine := this._line

        ; Set isAtLineStart for the token and update scanner state
        token.isAtLineStart := this._isAtLineStart
        if (!token.IsAnyOf(_YamlToken.Type.Space, _YamlToken.Type.Tab,
            _YamlToken.Type.Newline, _YamlToken.Type.Comment)) {
            this._isAtLineStart := false
        }

        if (this._tracer) {
            _val := ""
            if (token.HasProp("value")) {
                _val := IsObject(token.value) ? "[" . Type(token.value) . "]" : " [" . StrReplace(String(token.value),
                "`n", "\n") . "]"
            }
            this._tracer.Trace(Format("SENT: {1}{2} at L:{3} C:{4} (pos:{5}) {6}",
                token.name, _val, token.line, token.column, token.pos, token.isAtLineStart ? "LINE_START" : ""))
        }
        this._currentContext := this.CaptureState()
        return token
    }

    /**
     * Fetches the next raw token.
     * @returns {Object}
     */
    Next() {
        return this._Scan()
    }

    /**
     * Captures the current state of the scanner.
     * @returns {Object}
     */
    CaptureState() {
        return {
            pos: this._pos,
            line: this._line,
            column: this._column,
            scanningMode: this._scanningMode,
            grammarScope: this._grammarScope,
            contextIndent: this._contextIndent,
            isAtLineStart: this._isAtLineStart
        }
    }

    /**
     * Restores the scanner to a previously captured state.
     * @param {Object} state
     */
    RestoreState(state) {
        this._pos := state.pos
        this._line := state.line
        this._column := state.column
        this._scanningMode := state.scanningMode
        this._grammarScope := state.grammarScope
        this._contextIndent := state.contextIndent
        this._isAtLineStart := state.isAtLineStart
        this._currentContext := this.CaptureState()
    }

    /**
     * Core scanning logic.
     * @returns {Object}
     */
    _Scan() {
        loop {
            startPos := this._pos
            startLine := this._line
            startCol := this._column

            if (this._pos > this._len) {
                return this._Emit(_YamlToken.StreamEnd("", startLine, startCol, startPos, 0))
            }

            char := SubStr(this._source, this._pos, 1)

            if (char == "`n") {
                this._Advance(1, true)
                token := this._Emit(_YamlToken.Newline("`n", startLine, startCol, startPos, 1))
                this._isAtLineStart := true
                return token
            }

            if (char == " ") {
                if (this._scanningMode == _YamlRawScanner.Mode.BlockScalar) {
                    this._Advance(1)
                    return this._Emit(_YamlToken.Space(1, startLine, startCol, startPos, 1))
                }
                count := 0
                while (this._pos <= this._len && SubStr(this._source, this._pos, 1) == " ") {
                    this._Advance(1)
                    count++
                }
                return this._Emit(_YamlToken.Space(count, startLine, startCol, startPos, count))
            }

            if (char == "`t") {
                count := 0
                while (this._pos <= this._len && SubStr(this._source, this._pos, 1) == "`t") {
                    this._Advance(1)
                    count++
                }
                return this._Emit(_YamlToken.Tab(count, startLine, startCol, startPos, count))
            }

            ; Handle Directives (%) at the start of a line
            if (char == "%" && startCol == 0 && this._scanningMode != _YamlRawScanner.Mode.BlockScalar
                && !this.IgnoreDirectives) {
                nextChar := SubStr(this._source, this._pos + 1, 1)
                if (nextChar ~= "[a-zA-Z0-9]") {
                    return this._Emit(this._ScanDirective(startPos, startLine, startCol))
                }
            }

            if (this._scanningMode == _YamlRawScanner.Mode.BlockScalar) {
                if (char ~= "[0-9]") {
                    this._Advance(1)
                    return this._Emit(_YamlToken.Scalar(char, startLine, startCol, startPos, ":", 1))
                }
                if (InStr("+-", char)) {
                    this._Advance(1)
                    return this._Emit(_YamlToken.Symbol(char, startLine, startCol, startPos, 1))
                }
            }

            prevChar := (startPos > 1) ? SubStr(this._source, startPos - 1, 1) : "`n"
            if (this._scanningMode != _YamlRawScanner.Mode.PlainScalar && InStr(" `t`n,:?[]{}", prevChar)) {
                if (char == "'") {
                    return this._Emit(this._ScanSingleQuoted(startPos, startLine, startCol))
                }
                if (char == '"') {
                    return this._Emit(this._ScanDoubleQuoted(startPos, startLine, startCol))
                }
            }

            ; Handle Document Markers (---, ...) at the start of a line
            if ((char == "-" || char == ".") && startCol == 0 && this._CheckDocMarker(char)) {
                marker := SubStr(this._source, this._pos, 3)
                this._Advance(3)
                if (marker == "---") {
                    return this._Emit(_YamlToken.DocStart(marker, startLine, startCol, startPos, 3))
                } else {
                    return this._Emit(_YamlToken.DocEnd(marker, startLine, startCol, startPos, 3))
                }
            }

            if (InStr(_YamlRawScanner._indicators, char)) {
                if (char == "#") {
                    ; Flow context: '#' is NOT allowed as a comment start unless preceded by space.
                    ; To catch this as an error, we emit it as a Punctuator if not preceded by space.
                    isCommentStart := (startCol == 0 || InStr(" `t`n", SubStr(this._source, startPos - 1, 1)))
                    if (this._grammarScope == _YamlRawScanner.Scope.Flow && !isCommentStart) {
                        this._Advance(1)
                        return this._Emit(_YamlToken.Punctuator(char, startLine, startCol, startPos, 1))
                    }

                    ; Standard comment handling
                    if (this._scanningMode != _YamlRawScanner.Mode.BlockScalar && isCommentStart) {
                        return this._Emit(this._ScanComment(startPos, startLine, startCol))
                    }
                }

                if (InStr("-?:,[]{}", char)) {
                    nextChar := SubStr(this._source, this._pos + 1, 1)

                    isIndicator := false
                    if (InStr("[],{}", char) || char == ",") {
                        isIndicator := true
                    } else if (InStr("-?", char)) {
                        ; In PlainScalar mode, '?' and '-' are indicators ONLY if they start the line
                        ; and are followed by a separator.
                        if (this._scanningMode == _YamlRawScanner.Mode.PlainScalar) {
                            isIndicator := (this._isAtLineStart && (nextChar == "" || InStr(" `t`n,[]{}", nextChar)))
                        } else {
                            isIndicator := (nextChar == "" || InStr(" `t`n,[]{}", nextChar))
                        }
                    } else if (char == ":") {
                        isIndicator := (this._scanningMode == _YamlRawScanner.Mode.FlowValue
                            || (this._grammarScope == _YamlRawScanner.Scope.Flow
                                && (nextChar == "" || InStr(" `t`n,[]{}", nextChar)))
                            || nextChar == ""
                            || InStr(" `t`n,[]{}", nextChar))
                    }

                    if (isIndicator) {
                        this._Advance(1)
                        return this._Emit(_YamlToken.Symbol(char, startLine, startCol, startPos, 1))
                    }
                }

                if (char == "&" || char == "*") {
                    nextChar := SubStr(this._source, this._pos + 1, 1)
                    if (nextChar != "" && !InStr(" `t`n,[]{}", nextChar)) {
                        type := (char == "&") ? _YamlToken.Type.Anchor : _YamlToken.Type.Alias
                        return this._Emit(this._ScanAnchorOrAlias(type, startPos, startLine, startCol))
                    }
                }

                if (char == "!") {
                    return this._Emit(this._ScanTag(startPos, startLine, startCol))
                }

                if (InStr("|>", char)) {
                    this._Advance(1)
                    return this._Emit(_YamlToken.Symbol(char, startLine, startCol, startPos, 1))
                }
            }

            text := ""
            loop {
                if (this._pos > this._len) {
                    break
                }
                c := SubStr(this._source, this._pos, 1)

                ; Flow boundaries always end text
                if (InStr("[]{},", c) || InStr(" `t`n", c)) {
                    break
                }

                ; Colon logic
                if (c == ":") {
                    nc := SubStr(this._source, this._pos + 1, 1)
                    isInd := (nc == "" || InStr(" `t`n,[]{}", nc))
                    if (!isInd && (this._grammarScope == _YamlRawScanner.Scope.Flow
                        || this._scanningMode == _YamlRawScanner.Mode.FlowValue)) {
                        isInd := true
                    }
                    if (isInd) {
                        break
                    }
                }

                ; Comment start ends text
                if (c == "#") {
                    pc := (this._pos > 1) ? SubStr(this._source, this._pos - 1, 1) : "`n"
                    if (InStr(" `t`n", pc)) {
                        break
                    }
                }

                text .= c
                this._Advance(1)
            }

            if (text == "") {
                ; Fallback
                text := SubStr(this._source, this._pos, 1)
                this._Advance(1)
            }

            return this._Emit(_YamlToken.Text(text, startLine, startCol, startPos, StrLen(text)))
        }
    }

    /**
     * Scans a comment.
     * @param {Integer} startPos
     * @param {Integer} startLine
     * @param {Integer} startCol
     * @returns {Object}
     */
    _ScanComment(startPos, startLine, startCol) {
        val := ""
        while (this._pos <= this._len && SubStr(this._source, this._pos, 1) != "`n") {
            val .= SubStr(this._source, this._pos, 1)
            this._Advance(1)
        }
        return _YamlToken.Comment(val, startLine, startCol, startPos)
    }

    /**
     * Scans a directive (e.g., %YAML, %TAG).
     * @param {Integer} startPos
     * @param {Integer} startLine
     * @param {Integer} startCol
     * @returns {Object}
     */
    _ScanDirective(startPos, startLine, startCol) {
        this._Advance(1) ; Consume '%'
        name := ""
        while (this._pos <= this._len) {
            c := SubStr(this._source, this._pos, 1)
            if (InStr(" `t`n", c)) {
                break
            }
            name .= c
            this._Advance(1)
        }

        value := ""
        hasSpaceBeforeHash := false
        loop {
            if (this._pos > this._len) {
                break
            }
            c := SubStr(this._source, this._pos, 1)
            if (c == "`n") {
                break
            }
            if (c == "#") {
                if (!hasSpaceBeforeHash && value != "") {
                    throw YamlError("Missing space before directive comment", this._line, this._column)
                }
                ; Comment starts here, stop scanning directive value
                break
            }

            hasSpaceBeforeHash := (c == " " || c == "`t")
            value .= c
            this._Advance(1)
        }
        return _YamlToken.Directive(name . value, startLine, startCol, startPos, this._pos - startPos)
    }

    /**
     * Scans an anchor (&) or alias (*).
     * @param {Integer} type
     * @param {Integer} startPos
     * @param {Integer} startLine
     * @param {Integer} startCol
     * @returns {Object}
     */
    _ScanAnchorOrAlias(type, startPos, startLine, startCol) {
        indicatorLen := 1
        this._Advance(1)
        name := ""
        while (this._pos <= this._len) {
            c := SubStr(this._source, this._pos, 1)

            isBoundary := InStr(" `t`n,[]{}", c)

            if (isBoundary) {
                break
            }
            name .= c
            this._Advance(1)
        }
        totalLen := indicatorLen + StrLen(name)
        if (type == _YamlToken.Type.Alias) {
            return _YamlToken.Alias(name, startLine, startCol, startPos, totalLen)
        }
        return _YamlToken.Anchor(name, startLine, startCol, startPos, totalLen)
    }

    /**
     * Scans a YAML tag (!tag).
     * @param {Integer} startPos
     * @param {Integer} startLine
     * @param {Integer} startCol
     * @returns {Object}
     */
    _ScanTag(startPos, startLine, startCol) {
        indicatorLen := 1
        this._Advance(1)
        tag := "!"
        if (SubStr(this._source, this._pos, 1) == "<") {
            this._Advance(1)
            inner := ""
            while (this._pos <= this._len && SubStr(this._source, this._pos, 1) != ">") {
                inner .= SubStr(this._source, this._pos, 1)
                this._Advance(1)
            }
            if (SubStr(this._source, this._pos, 1) == ">") {
                this._Advance(1)
            }
            totalLen := indicatorLen + 1 + StrLen(inner) + 1
            return _YamlToken.Tag("!<" . inner . ">", startLine, startCol, startPos, totalLen)
        }
        while (this._pos <= this._len) {
            c := SubStr(this._source, this._pos, 1)
            if (InStr(" `t`n,[]{}", c)) {
                break
            }
            tag .= c
            this._Advance(1)
        }
        return _YamlToken.Tag(tag, startLine, startCol, startPos, indicatorLen + StrLen(tag) - 1)
    }

    /**
     * Scans a single-quoted scalar.
     * @param {Integer} startPos
     * @param {Integer} startLine
     * @param {Integer} startCol
     * @returns {Object}
     */
    _ScanSingleQuoted(startPos, startLine, startCol) {
        initialPos := this._pos
        this._Advance(1)
        val := ""
        pendingWS := ""
        loop {
            if (this._pos > this._len) {
                break
            }
            char := SubStr(this._source, this._pos, 1)
            if (char == "'") {
                if (SubStr(this._source, this._pos + 1, 1) == "'") {
                    val .= pendingWS . "'"
                    pendingWS := ""
                    this._Advance(2)
                    continue
                }
                this._Advance(1)
                val .= pendingWS

                ; VALIDATION: A quoted scalar must be followed by a separator.
                nextChar := SubStr(this._source, this._pos, 1)
                if (nextChar != "" && !InStr(" `t`n,[]{}#?:", nextChar)) {
                    throw YamlError("Missing separation space after quoted scalar", this._line, this._column)
                }
                return _YamlToken.ScalarSQ(val, startLine, startCol, startPos, this._pos - initialPos)
            }
            if (char == "`n") {
                pendingWS := ""
                this._Advance(1, true)
                if (this._CheckDocMarker("-") || this._CheckDocMarker(".")) {
                    throw YamlError("Unexpected document marker inside quoted scalar", this._line, this._column)
                }

                newlines := 1 + this._SkipWhitespaceAndValidateIndent()

                ; Indentation validation for block context
                if (this._grammarScope == _YamlRawScanner.Scope.Block) {
                    nextChar := SubStr(this._source, this._pos, 1)
                    if (nextChar != "" && nextChar != "`n" && this._column <= this._contextIndent) {
                        throw YamlError("Quoted scalar lines must be indented", this._line, this._column)
                    }
                }

                if (newlines > 1) {
                    loop (newlines - 1) {
                        val .= "`n"
                    }
                } else {
                    val .= " "
                }
                continue
            }
            if (char == " " || char == "`t") {
                pendingWS .= char
            } else {
                val .= pendingWS . char
                pendingWS := ""
            }
            this._Advance(1)
        }
        throw YamlError("Unclosed single-quoted scalar", startLine, startCol)
    }

    /**
     * Scans a double-quoted scalar.
     * @param {Integer} startPos
     * @param {Integer} startLine
     * @param {Integer} startCol
     * @returns {Object}
     */
    _ScanDoubleQuoted(startPos, startLine, startCol) {
        initialPos := this._pos
        this._Advance(1)
        val := ""
        pendingWS := ""
        while (this._pos <= this._len) {
            char := SubStr(this._source, this._pos, 1)
            if (char == '"') {
                this._Advance(1)
                val .= pendingWS

                ; VALIDATION: A quoted scalar must be followed by a separator.
                nextChar := SubStr(this._source, this._pos, 1)
                if (nextChar != "" && !InStr(" `t`n,[]{}#?:", nextChar)) {
                    throw YamlError("Missing separation space after quoted scalar", this._line, this._column)
                }
                return _YamlToken.ScalarDQ(val, startLine, startCol, startPos, this._pos - initialPos)
            }
            if (char == "\") {
                val .= pendingWS
                pendingWS := ""
                this._Advance(1)
                esc := SubStr(this._source, this._pos, 1)
                switch esc {
                    case "0": val .= Chr(0)
                    case "a": val .= Chr(7)
                    case "b": val .= Chr(8)
                    case "t", "`t": val .= "`t"
                    case "n": val .= "`n"
                    case "v": val .= Chr(11)
                    case "f": val .= "`f"
                    case "r": val .= "`r"
                    case "e": val .= Chr(27)
                    case " ": val .= " "
                    case '"': val .= '"'
                    case "/": val .= "/"
                    case "\": val .= "\"
                    case "N": val .= Chr(0x85)
                    case "_": val .= Chr(0xA0)
                    case "L": val .= Chr(0x2028)
                    case "P": val .= Chr(0x2029)
                    case "x":
                        hex := SubStr(this._source, this._pos + 1, 2)
                        val .= Chr(Integer("0x" . hex))
                        this._Advance(2)
                    case "u":
                        hex := SubStr(this._source, this._pos + 1, 4)
                        val .= Chr(Integer("0x" . hex))
                        this._Advance(4)
                    case "U":
                        hex := SubStr(this._source, this._pos + 1, 8)
                        val .= Chr(Integer("0x" . hex))
                        this._Advance(8)
                    case "`n":
                        this._Advance(1, true)
                        while (this._pos <= this._len && InStr(" `t", SubStr(this._source, this._pos, 1))) {
                            this._Advance(1)
                        }
                        continue
                    default:
                        throw YamlError("Unknown escape character: \" . esc, this._line, this._column)
                }
                this._Advance(1)
                continue
            }
            if (char == "`n") {
                pendingWS := ""
                this._Advance(1, true)
                if (this._CheckDocMarker("-") || this._CheckDocMarker(".")) {
                    throw YamlError("Unexpected document marker inside quoted scalar", this._line, this._column)
                }

                newlines := 1 + this._SkipWhitespaceAndValidateIndent()

                ; Indentation validation for block context
                if (this._grammarScope == _YamlRawScanner.Scope.Block) {
                    nextChar := SubStr(this._source, this._pos, 1)
                    if (nextChar != "" && nextChar != "`n" && this._column <= this._contextIndent) {
                        throw YamlError("Quoted scalar lines must be indented", this._line, this._column)
                    }
                }

                if (newlines > 1) {
                    loop (newlines - 1) {
                        val .= "`n"
                    }
                } else {
                    val .= " "
                }
                continue
            }
            if (char == " " || char == "`t") {
                pendingWS .= char
            } else {
                val .= pendingWS . char
                pendingWS := ""
            }
            this._Advance(1)
        }
        throw YamlError("Unclosed double-quoted scalar", startLine, startCol)
    }

    /**
     * Skips whitespace and validates indentation.
     * @returns {Integer} Number of newlines skipped
     */
    _SkipWhitespaceAndValidateIndent() {
        newlines := 0
        loop {
            char := SubStr(this._source, this._pos, 1)
            if (char == " ") {
                this._Advance(1)
            } else if (char == "`t") {
                ; Tab is forbidden if we haven't reached the required indentation level yet
                if (this._column <= this._contextIndent && this._grammarScope != _YamlRawScanner.Scope.Flow) {
                    throw YamlError("Tabs are not allowed for indentation", this._line, this._column)
                }
                this._Advance(1)
            } else if (char == "`n") {
                newlines++
                this._Advance(1, true)
                this._isAtLineStart := true
            } else {
                break
            }
        }
        return newlines
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

    /**
     * Checks for a document marker (--- or ...).
     * @param {String} char - The marker character ('-' or '.')
     * @returns {Boolean}
     */
    _CheckDocMarker(char) {
        if (this._pos + 2 > this._len) {
            return false
        }
        if (SubStr(this._source, this._pos, 3) !== (char char char)) {
            return false
        }
        nextChar := SubStr(this._source, this._pos + 3, 1)
        return (nextChar == "" || InStr(" `t`n", nextChar))
    }

    /**
     * Advances the scanner position.
     * @param {Integer} n - Number of characters to advance
     * @param {Boolean} [newline=false] - Whether to increment the line number
     */
    _Advance(n, newline := false) {
        this._pos += n
        if (newline) {
            this._line++
            this._column := 0
        } else {
            this._column += n
        }
    }
}
