#Requires AutoHotkey v2.0

/**
 * @file _Events.ahk
 * @description Definition of YAML Serialization Events.
 * @author nullmake
 * @license Apache-2.0
 *
 * Copyright 2026 nullmake
 */

/**
 * @class YamlEvent
 * Base class for all YAML serialization events.
 */
class YamlEvent {
    /** @field {Integer} line - Start line of the event */
    line := 0
    /** @field {Integer} column - Start column of the event */
    column := 0

    __New(line := 0, column := 0) {
        this.line := line
        this.column := column
    }
}

class YamlStreamStartEvent extends YamlEvent {
}

class YamlStreamEndEvent extends YamlEvent {
}

class YamlDocumentStartEvent extends YamlEvent {
    /** @field {Boolean} explicit - True if '---' is present */
    explicit := false
    __New(explicit := false, line := 0, column := 0) {
        super.__New(line, column)
        this.explicit := explicit
    }
}

class YamlDocumentEndEvent extends YamlEvent {
    /** @field {Boolean} explicit - True if '...' is present */
    explicit := false
    __New(explicit := false, line := 0, column := 0) {
        super.__New(line, column)
        this.explicit := explicit
    }
}

class YamlAliasEvent extends YamlEvent {
    /** @field {String} anchor - The anchor name being referenced (e.g., "id001") */
    anchor := ""
    __New(anchor, line := 0, column := 0) {
        super.__New(line, column)
        this.anchor := anchor
    }
}

class YamlScalarEvent extends YamlEvent {
    /** @field {String} value - The scalar content */
    value := ""
    /** @field {String} tag - YAML tag (optional) */
    tag := ""
    /** @field {String} anchor - Anchor name (optional) */
    anchor := ""
    /** @field {Integer} style - Presentation style (Plain, SingleQuoted, etc.) */
    style := 0

    __New(value, tag := "", anchor := "", style := 0, line := 0, column := 0) {
        super.__New(line, column)
        this.value := value
        this.tag := tag
        this.anchor := anchor
        this.style := style
    }
}

class YamlCollectionStartEvent extends YamlEvent {
    /** @field {String} tag - YAML tag (optional) */
    tag := ""
    /** @field {String} anchor - Anchor name (optional) */
    anchor := ""
    /** @field {Boolean} flowStyle - True for inline [ ] or { } */
    flowStyle := false

    __New(tag := "", anchor := "", flowStyle := false, line := 0, column := 0) {
        super.__New(line, column)
        this.tag := tag
        this.anchor := anchor
        this.flowStyle := flowStyle
    }
}

class YamlSequenceStartEvent extends YamlCollectionStartEvent {
}

class YamlSequenceEndEvent extends YamlEvent {
}

class YamlMappingStartEvent extends YamlCollectionStartEvent {
}

class YamlMappingEndEvent extends YamlEvent {
}
