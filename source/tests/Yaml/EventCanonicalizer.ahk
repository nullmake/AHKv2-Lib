#Requires AutoHotkey v2.0

/**
 * @file EventCanonicalizer.ahk
 * @description Converts YamlEvent objects into the YAML Test Suite canonical format string.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Provides utility to transform an array of YamlEvents into a single canonical string.
 */
class EventCanonicalizer {
    /**
     * Transforms a single event into its canonical string representation.
     * @param {YamlEvent} event - The event to transform.
     * @returns {String} Canonical format line.
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
     * Formats a scalar event into canonical VAL representation.
     * @param {YamlScalarEvent} event
     * @returns {String}
     * @private
     */
    static _FormatScalar(event) {
        _props := ""
        if (event.anchor != "") {
            _props .= " &" . event.anchor
        }

        if (event.tag != "") {
            _props .= " <" . this._NormalizeTag(event.tag) . ">"
        }

        ; Map internal style markers to canonical characters.
        styleStr := String(event.style)
        switch styleStr {
            case "'", '"', "|", ">", ":":
                _styleChar := styleStr
            default:
                throw Error("Unknown or unset scalar style: [" . event.style . "] for value: " . event.value)
        }

        _escapedValue := this._Escape(event.value)
        return "=VAL" . _props . " " . _styleChar . _escapedValue
    }

    /**
     * Formats a collection start event into canonical SEQ/MAP representation.
     * @param {String} prefix - "+SEQ" or "+MAP"
     * @param {YamlCollectionStartEvent} event
     * @returns {String}
     * @private
     */
    static _FormatCollection(prefix, event) {
        _props := ""
        if (event.anchor != "") {
            _props .= " &" . event.anchor
        }
        if (event.tag != "") {
            _props .= " <" . this._NormalizeTag(event.tag) . ">"
        }
        _flow := event.flowStyle ? (prefix == "+SEQ" ? " []" : " {}") : ""
        return prefix . _flow . _props
    }

    /**
     * Expands shorthand tags to full URIs for YAML Test Suite compliance.
     * @param {String} tag
     * @returns {String}
     * @private
     */
    static _NormalizeTag(tag) {
        if (tag == "" || tag == "!") {
            return tag
        }
        if (SubStr(tag, 1, 4) == "tag:") {
            return tag
        }
        static _shorthands := Map(
            "!!str", "tag:yaml.org,2002:str",
            "!!int", "tag:yaml.org,2002:int",
            "!!float", "tag:yaml.org,2002:float",
            "!!bool", "tag:yaml.org,2002:bool",
            "!!null", "tag:yaml.org,2002:null",
            "!!map", "tag:yaml.org,2002:map",
            "!!seq", "tag:yaml.org,2002:seq",
            "!!binary", "tag:yaml.org,2002:binary",
            "!!timestamp", "tag:yaml.org,2002:timestamp",
            "!!set", "tag:yaml.org,2002:set",
            "!!omap", "tag:yaml.org,2002:omap",
            "!!pairs", "tag:yaml.org,2002:pairs"
        )
        return _shorthands.Has(tag) ? _shorthands[tag] : tag
    }

    /**
     * Escapes special characters for canonical VAL display.
     * @param {String} val
     * @returns {String}
     * @private
     */
    static _Escape(val) {
        if (val == "") {
            return ""
        }
        _res := val
        _res := StrReplace(_res, "\", "\\")
        _res := StrReplace(_res, "`b", "\b")
        _res := StrReplace(_res, "`f", "\f")
        _res := StrReplace(_res, "`n", "\n")
        _res := StrReplace(_res, "`r", "\r")
        _res := StrReplace(_res, "`t", "\t")
        return _res
    }
}
