#Requires AutoHotkey v2.0

/**
 * @file EventCanonicalizer.ahk
 * @description Converts YamlEvent objects into the YAML Test Suite canonical format string.
 * @author nullmake
 * @license Apache-2.0
 *
 * Copyright 2026 nullmake
 */

/**
 * @class EventCanonicalizer
 * Provides utility to transform an array of YamlEvents into a single canonical string.
 */
class EventCanonicalizer {
    /**
    * @method Canonicalize
    * Transforms a single event into its string representation.
    * @param {YamlEvent} event - The event to transform.
    * @returns {String}
    */
    static Canonicalize(event) {
        if (event is YamlStreamStartEvent) {
            return "+STR"
        }
        if (event is YamlStreamEndEvent) {
            return "-STR"
        }
        if (event is YamlDocumentStartEvent) {
            return "+DOC" . (event.explicit ? " ---" : "")
        }
        if (event is YamlDocumentEndEvent) {
            return "-DOC" . (event.explicit ? " ..." : "")
        }
        if (event is YamlAliasEvent) {
            return "=ALI *" . event.anchor
        }
        if (event is YamlScalarEvent) {
            return this._FormatScalar(event)
        }
        if (event is YamlSequenceStartEvent) {
            return this._FormatCollection("+SEQ", event)
        }
        if (event is YamlSequenceEndEvent) {
            return "-SEQ"
        }
        if (event is YamlMappingStartEvent) {
            return this._FormatCollection("+MAP", event)
        }
        if (event is YamlMappingEndEvent) {
            return "-MAP"
        }
        return ""
    }

    /**
    * @method _FormatScalar
    * @private
    */
    static _FormatScalar(event) {
        _props := ""
        if (event.anchor != "") {
            _props .= " &" . event.anchor
        }
        if (event.tag != "") {
            _props .= " <" . event.tag . ">"
        }

        _style := (event.style == 1) ? "'" ; Single Quoted
                : (event.style == 2) ? '"' ; Double Quoted
                : (event.style == 3) ? "|" ; Literal
                : (event.style == 4) ? ">" ; Folded
                : ":"                      ; Plain

        _escapedValue := this._Escape(event.value)
        return "=VAL" . _props . " " . _style . _escapedValue
    }

    /**
    * @method _FormatCollection
    * @private
    */
    static _FormatCollection(prefix, event) {
        _props := ""
        if (event.anchor != "") {
            _props .= " &" . event.anchor
        }
        if (event.tag != "") {
            _props .= " <" . event.tag . ">"
        }
        _flow := event.flowStyle ? (prefix == "+SEQ" ? " []" : " {}") : ""
        return prefix . _props . _flow
    }

    /**
    * @method _Escape
    * Escapes special characters for canonical format.
    * @private
    */
    static _Escape(val) {
        _res := val
        _res := StrReplace(_res, "\", "\\")
        _res := StrReplace(_res, "`0", "\0")
        _res := StrReplace(_res, "`b", "\b")
        _res := StrReplace(_res, "`t", "\t")
        _res := StrReplace(_res, "`n", "\n")
        _res := StrReplace(_res, "`r", "\r")
        return _res
    }
}
