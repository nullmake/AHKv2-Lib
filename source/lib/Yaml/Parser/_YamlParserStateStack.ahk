#Requires AutoHotkey v2.0

/**
 * @file _YamlParserStateStack.ahk
 * @description YAML Parser State Transition Stack.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * YAML Parser State Transition Stack.
 */
class _YamlParserStateStack extends Array {
    /**
     * Returns the current state (top of the stack).
     */
    Current => this.Length > 0 ? this[this.Length] : ""

    /**
     * Checks if any state in the stack matches the given category mask.
     * @param {Integer} mask
     * @returns {Boolean}
     */
    Has(mask) {
        for s in this {
            if (s.category & mask) {
                return true
            }
        }
        return false
    }

    /**
     * Scans the stack from top to bottom to find the first state matching the mask.
     * @param {Integer} mask
     * @returns {Object|String} The state object if found, otherwise empty string.
     */
    Find(mask) {
        idx := this.Length
        while (idx > 0) {
            if (this[idx].category & mask) {
                return this[idx]
            }
            idx--
        }
        return ""
    }

    /**
     * Returns a string representation of the stack for tracing.
     * @returns {String}
     */
    ToString() {
        str := ""
        for i, item in this {
            name := item is _YamlParserStateBase ? item.state : Type(item)
            str .= (i == 1 ? "" : " > ") . name
        }
        return str
    }
}
