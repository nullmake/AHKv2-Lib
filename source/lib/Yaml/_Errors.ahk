#Requires AutoHotkey v2.0

/**
 * @file _Errors.ahk
 * @description Standard error types for the YAML library.
 * @author nullmake
 * @license Apache-2.0
 *
 * Copyright 2026 nullmake
 */

/**
 * @class YamlError
 * Specialized error class for YAML syntax and processing issues.
 * Provides contextual information including line and column numbers.
 */
class YamlError extends Error {
    /** @field {Integer} line - 1-based line number */
    line := 0
    /** @field {Integer} column - 1-based column number */
    column := 0
    /** @field {String} snippet - Excerpt of the source text near the error */
    snippet := ""

    /**
    * @constructor
    * @param {String} message - Description of the error.
    * @param {Integer} line - Line number (optional).
    * @param {Integer} column - Column number (optional).
    * @param {String} snippet - Source context (optional).
    * @param {Integer} what - Stack offset for the error location.
    */
    __New(message, line := 0, column := 0, snippet := "", what := -1) {
        detail := message
        if (line > 0) {
            detail .= "`nLine: " . line . ", Column: " . column
        }
        if (snippet != "") {
            detail .= "`nContext:`n" . snippet
        }

        super.__New(detail, what)
        this.line := line
        this.column := column
        this.snippet := snippet
    }
}
