#Requires AutoHotkey v2.0

/**
 * @file _YamlError.ahk
 * @description Exception classes for YAML parsing and serialization.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Standard exception thrown by the YAML library.
 */
class YamlError extends Error {
    /** @field {Integer} line - Line number where the error occurred */
    line := 0

    /** @field {Integer} column - Column number where the error occurred */
    column := 0

    /** @field {String} snippet - Code snippet near the error */
    snippet := ""

    /**
     * @param {String} message - Error message
     * @param {Integer} [line=0]
     * @param {Integer} [column=0]
     * @param {String} [snippet=""]
     * @param {Integer} [what=-1]
     */
    __New(message, line := 0, column := 0, snippet := "", what := -1) {
        _safeMessage := IsObject(message) ? "[Object]" : String(message)
        super.__New(_safeMessage, what)
        this.line := line
        this.column := column
        this.snippet := snippet
    }
}

/**
 * Internal exception used to signal a failed speculation in the parser.
 */
class _YamlSpeculativeParseError {
    /** @field {String} message - Error message (for internal tracing) */
    message := ""

    /**
     * @param {String} [message=""]
     */
    __New(message := "") {
        this.message := message
    }
}
