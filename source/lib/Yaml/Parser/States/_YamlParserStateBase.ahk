#Requires AutoHotkey v2.0

/**
 * @file _YamlParserStateBase.ahk
 * @description Base class for YAML Parser State Objects.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Base class for Parser State Objects.
 */
class _YamlParserStateBase {
    /**
     * Bitmask categories for parser states.
     */
    static Category := {
        None: 0,
        Scope: { Flow: 0x1, Block: 0x2 },
        Type: { Map: 0x10, Seq: 0x20 },
        Role: { Start: 0x100, End: 0x200, Key: 0x400, Value: 0x800 },
        Key: { Explicit: 0x1000, Simple: 0x2000 }
    }

    /** @field {String} state - The name of the state */
    state := ""

    /** @field {Integer} category - Bitmask category of this state */
    category := 0

    /** @field {Integer} indent - The indentation level where this state started */
    indent := -1

    /**
     * @param {String} state - The name of the state
     * @param {Integer} [category=0] - Bitmask category of this state
     * @param {Integer} [indent=-1] - The indentation level where this state started
     */
    __New(state, category := 0, indent := -1) {
        this.state := state
        this.category := category
        this.indent := indent
    }

    /**
     * Creates a deep copy of the state object.
     * @abstract
     * @returns {Object}
     */
    DeepClone() {
        throw Error("Not implemented")
    }

    /**
     * Handles the current state and returns an event if applicable.
     * @abstract
     * @param {Object} ctx - Parser context
     * @returns {Object|String} YamlEvent or empty string
     */
    Handle(ctx) {
        throw Error("State class '" . Type(this) . "' must implement Handle(ctx)")
    }
}
