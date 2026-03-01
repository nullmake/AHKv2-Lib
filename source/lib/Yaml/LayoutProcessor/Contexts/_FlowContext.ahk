#Requires AutoHotkey v2.0

/**
 * @file _FlowContext.ahk
 * @description Handles logic for flow-style collections (Mapping and Sequence).
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Handles logic for flow-style collections.
 */
class _FlowContext extends _YamlContext {
    /**
     * Processes the start of a line in flow context.
     * @param {Object} ctx
     * @param {Integer} indent
     * @param {Object} nextToken
     * @param {Integer} contextIndent
     * @returns {Boolean}
     */
    ProcessLineStart(ctx, indent, nextToken, contextIndent) {
        if (indent <= contextIndent) {
            if (!nextToken.IsAnyOf(_YamlToken.Type.StreamEnd, _YamlToken.Type.DocStart, _YamlToken.Type.DocEnd)) {
                throw YamlError("Flow collection lines must be indented further than the parent block node",
                    nextToken.line, nextToken.column)
            }
        }
        return false
    }

    /**
     * Handles tokens in flow context.
     * @param {Object} ctx
     * @param {Object} token
     * @returns {Boolean}
     */
    OnToken(ctx, token) {
        if (token.Is(_YamlToken.Type.Punctuator)) {
            if (token.value == "[" || token.value == "{") {
                ctx.ContextStack.Push(_YamlContext.Type.Flow)
                return true
            }
            if (token.value == "]" || token.value == "}") {
                ctx.ContextStack.Pop()
                return true
            }
        }
        return false
    }
}
