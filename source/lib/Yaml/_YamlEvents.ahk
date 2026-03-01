#Requires AutoHotkey v2.0

/**
 * @file _YamlEvents.ahk
 * @description Definition of YAML Serialization Events with Hints.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Base class for all YAML events emitted by the parser.
 */
class YamlEvent {
    /** @field {Integer} line - Line number of the event */
    line := 0

    /** @field {Integer} column - Column number of the event */
    column := 0

    /** @field {String} type - Normalized event type name */
    type := ""

    /** @field {Object} hint - Optional metadata/hint for the event */
    hint := unset

    /**
     * @param {Integer} [line=0]
     * @param {Integer} [column=0]
     * @param {Object|String} [hint=""]
     */
    __New(line := 0, column := 0, hint := "") {
        this.line := line
        this.column := column
        if (IsObject(hint)) {
            this.hint := hint
        }
        this.type := StrReplace(StrReplace(Type(this), "Yaml", ""), "Event", "")
    }

    /**
     * Returns a string representation of the event for debugging.
     * @returns {String}
     */
    ToString() {
        _valStr := ""
        if (this.HasProp("value")) {
            _valStr := IsObject(this.value)
                ? "[" . Type(this.value) . "]"
                : " [" . StrReplace(String(this.value), "`n", "\n") . "]"
        }
        return Format("[{1}]{2} L{3} C{4}", this.type, _valStr, this.line, this.column)
    }
}

/**
 * Marks the beginning of a YAML stream.
 */
class YamlStreamStartEvent extends YamlEvent {
}

/**
 * Marks the end of a YAML stream.
 */
class YamlStreamEndEvent extends YamlEvent {
}

/**
 * Marks the beginning of a YAML document.
 */
class YamlDocumentStartEvent extends YamlEvent {
    /** @field {Boolean} explicit - Whether the document started with '---' */
    explicit := false

    /**
     * @param {Boolean} [explicit=false]
     * @param {Integer} [line=0]
     * @param {Integer} [column=0]
     * @param {Object|String} [hint=""]
     */
    __New(explicit := false, line := 0, column := 0, hint := "") {
        super.__New(line, column, hint)
        this.explicit := explicit
    }
}

/**
 * Marks the end of a YAML document.
 */
class YamlDocumentEndEvent extends YamlEvent {
    /** @field {Boolean} explicit - Whether the document ended with '...' */
    explicit := false

    /**
     * @param {Boolean} [explicit=false]
     * @param {Integer} [line=0]
     * @param {Integer} [column=0]
     * @param {Object|String} [hint=""]
     */
    __New(explicit := false, line := 0, column := 0, hint := "") {
        super.__New(line, column, hint)
        this.explicit := explicit
    }
}

/**
 * Represents a YAML alias (*anchor).
 */
class YamlAliasEvent extends YamlEvent {
    /** @field {String} anchor - The name of the anchor being referenced */
    anchor := ""

    /**
     * @param {String} anchor
     * @param {Integer} [line=0]
     * @param {Integer} [column=0]
     * @param {Object|String} [hint=""]
     */
    __New(anchor, line := 0, column := 0, hint := "") {
        super.__New(line, column, hint)
        this.anchor := anchor
    }
}

/**
 * Represents a scalar value (e.g., string, integer).
 */
class YamlScalarEvent extends YamlEvent {
    /** @field {String} value - The scalar content */
    value := ""

    /** @field {String} tag - The YAML tag (if any) */
    tag := ""

    /** @field {String} anchor - The anchor name (if any) */
    anchor := ""

    /** @field {String} style - Scalar style (':', "'", '"', '|', '>') */
    style := 0

    /**
     * @param {String} value
     * @param {String} [tag=""]
     * @param {String} [anchor=""]
     * @param {String} [style=0]
     * @param {Integer} [line=0]
     * @param {Integer} [column=0]
     * @param {Object|String} [hint=""]
     */
    __New(value, tag := "", anchor := "", style := 0, line := 0, column := 0, hint := "") {
        super.__New(line, column, hint)
        this.value := value
        this.tag := tag
        this.anchor := anchor
        this.style := style
    }
}

/**
 * Base class for collection start events (Mapping or Sequence).
 */
class YamlCollectionStartEvent extends YamlEvent {
    /** @field {String} tag - The YAML tag (if any) */
    tag := ""

    /** @field {String} anchor - The anchor name (if any) */
    anchor := ""

    /** @field {Boolean} flowStyle - Whether the collection uses flow style ([], {}) */
    flowStyle := false

    /**
     * @param {String} [tag=""]
     * @param {String} [anchor=""]
     * @param {Boolean} [flowStyle=false]
     * @param {Integer} [line=0]
     * @param {Integer} [column=0]
     * @param {Object|String} [hint=""]
     */
    __New(tag := "", anchor := "", flowStyle := false, line := 0, column := 0, hint := "") {
        super.__New(line, column, hint)
        this.tag := tag
        this.anchor := anchor
        this.flowStyle := flowStyle
    }
}

/**
 * Marks the beginning of a YAML sequence.
 */
class YamlSequenceStartEvent extends YamlCollectionStartEvent {
}

/**
 * Marks the end of a YAML sequence.
 */
class YamlSequenceEndEvent extends YamlEvent {
}

/**
 * Marks the beginning of a YAML mapping.
 */
class YamlMappingStartEvent extends YamlCollectionStartEvent {
}

/**
 * Marks the end of a YAML mapping.
 */
class YamlMappingEndEvent extends YamlEvent {
}
