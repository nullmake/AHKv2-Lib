#Requires AutoHotkey v2.0

/**
 * @file _YamlToken.ahk
 * @description Lexical token definitions for YAML.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents a lexical token in YAML.
 */
class _YamlToken {
    /**
     * Lexical token types.
     */
    static Type := {
        StreamStart: 1,
        StreamEnd: 2,
        DocStart: 3,
        DocEnd: 4,
        Directive: 5,
        Newline: 6,
        Indent: 7,
        Dedent: 8,
        Space: 9,
        Tab: 10,
        Scalar: 11,
        ScalarSQ: 12,
        ScalarDQ: 13,
        Anchor: 14,
        Alias: 15,
        Tag: 16,
        BlockEntry: 17,
        KeyIndicator: 18,
        ValueIndicator: 19,
        Punctuator: 20,
        Symbol: 20, ; Alias for Punctuator
        Comment: 21,
        Text: 22
    }

    /** @field {Integer} type - Token type ID */
    type := 0

    /** @field {String} value - Token string value */
    value := ""

    /** @field {Integer} line - Start line number */
    line := 0

    /** @field {Integer} endLine - End line number (for multi-line tokens) */
    endLine := 0

    /** @field {Integer} column - Start column number */
    column := 0

    /** @field {Integer} pos - Start byte position in the source */
    pos := 0

    /** @field {Integer} len - Token length in characters */
    len := 0

    /** @field {String} style - Scalar style ('', "'", '"', '|', '>', ':') */
    style := ""

    /** @field {Object} scannerContext - Scanner state at the time of tokenization */
    scannerContext := ""

    /** @field {Boolean} precededByTab - Whether the token was preceded by a tab */
    precededByTab := false

    /** @field {Boolean} isAtLineStart - Whether the token started at the beginning of a line */
    isAtLineStart := false

    /**
     * @param {Integer} type
     * @param {String} value
     * @param {Integer} line
     * @param {Integer} col
     * @param {Integer} pos
     * @param {Integer} [len=0]
     */
    __New(type, value, line, col, pos, len := 0) {
        this.type := type
        this.value := value
        this.line := line
        this.endLine := line
        this.column := col
        this.pos := pos
        this.len := (len > 0) ? len : StrLen(String(value))
    }

    /**
     * Checks if the token is of the specified type.
     * @param {Integer} type
     * @returns {Boolean}
     */
    Is(type) {
        return (this.type == type)
    }

    /**
     * Checks if the token type is one of the specified types.
     * @param {Integer} types*
     * @returns {Boolean}
     */
    IsAnyOf(types*) {
        for t in types {
            if (this.type == t) {
                return true
            }
        }
        return false
    }

    /**
     * Whether the token represents a scalar value (plain, quoted, or text).
     */
    IsScalar {
        get {
            return ((this.type >= _YamlToken.Type.Scalar && this.type <= _YamlToken.Type.ScalarDQ)
            || this.type == _YamlToken.Type.Text)
        }
    }

    /**
     * Human-readable name of the token type.
     */
    name {
        get {
            for n, v in _YamlToken.Type.OwnProps() {
                if (v == this.type) {
                    return n
                }
            }
            return "Unknown"
        }
    }

    /**
     * Returns a string representation for debugging.
     * @returns {String}
     */
    ToString() {
        val := ""
        if (this.HasProp("value") && this.value !== "") {
            val := IsObject(this.value)
                ? " [" . Type(this.value) . "]"
                : " [" . StrReplace(String(this.value), "`n", "\n") . "]"
        }
        return Format("{1}{2} at L:{3} C:{4} (pos:{5})", this.name, val, this.line, this.column, this.pos)
    }

    ; Static Factory Methods

    static StreamStart(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.StreamStart, v, l, c, p, len)
    }
    static StreamEnd(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.StreamEnd, v, l, c, p, len)
    }
    static DocStart(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.DocStart, v, l, c, p, len)
    }
    static DocEnd(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.DocEnd, v, l, c, p, len)
    }
    static Directive(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Directive, v, l, c, p, len)
    }
    static Newline(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Newline, v, l, c, p, len)
    }
    static Indent(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Indent, v, l, c, p, len)
    }
    static Dedent(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Dedent, v, l, c, p, len)
    }
    static Space(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Space, v, l, c, p, len)
    }
    static Tab(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Tab, v, l, c, p, len)
    }
    static Scalar(v, l, c, p, s := ":", len := 0) {
        t := _YamlToken(_YamlToken.Type.Scalar, v, l, c, p, len)
        t.style := s
        return t
    }
    static ScalarSQ(v, l, c, p, len := 0) {
        t := _YamlToken(_YamlToken.Type.ScalarSQ, v, l, c, p, len)
        t.style := "'"
        return t
    }
    static ScalarDQ(v, l, c, p, len := 0) {
        t := _YamlToken(_YamlToken.Type.ScalarDQ, v, l, c, p, len)
        t.style := '"'
        return t
    }
    static Anchor(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Anchor, v, l, c, p, len)
    }
    static Alias(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Alias, v, l, c, p, len)
    }
    static Tag(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Tag, v, l, c, p, len)
    }
    static BlockEntry(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.BlockEntry, v, l, c, p, len)
    }
    static KeyIndicator(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.KeyIndicator, v, l, c, p, len)
    }
    static ValueIndicator(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.ValueIndicator, v, l, c, p, len)
    }
    static Punctuator(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Punctuator, v, l, c, p, len)
    }
    static Symbol(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Punctuator, v, l, c, p, len)
    }
    static Comment(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Comment, v, l, c, p, len)
    }
    static Text(v, l, c, p, len := 0) {
        return _YamlToken(_YamlToken.Type.Text, v, l, c, p, len)
    }
}
