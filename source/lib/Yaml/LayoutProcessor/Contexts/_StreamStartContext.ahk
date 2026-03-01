#Requires AutoHotkey v2.0

/**
 * @file _StreamStartContext.ahk
 * @description Handles logic for the very beginning of a YAML stream.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * [Concrete] STREAM_START
 * Handles indentation of the very first line of the stream.
 */
class _StreamStartContext extends _YamlContext {
    /**
     * Processes the start of the first line in the stream.
     * @param {Object} ctx
     * @param {Integer} indent
     * @param {Object} nextToken
     * @param {Integer} contextIndent
     * @returns {Boolean}
     */
    ProcessLineStart(ctx, indent, nextToken, contextIndent) {
        ; Capture initial indent and transition to ROOT
        ctx.HandleIndentation(indent, nextToken)
        ctx.ContextStack.Pop()
        ctx.ContextStack.Push(_YamlContext.Type.Root)
        return false ; Let ROOT handle further logic
    }

    /**
     * Handles the first token in the stream.
     * @param {Object} ctx
     * @param {Object} token
     * @returns {Boolean}
     */
    OnToken(ctx, token) {
        ctx.ContextStack.Pop()
        ctx.ContextStack.Push(_YamlContext.Type.Root)
        return false
    }
}
