#Requires AutoHotkey v2.0

/**
 * @file _NodePropsContext.ahk
 * @description Handles logic for nodes with properties (Anchors and Tags).
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Handles logic for nodes with properties.
 */
class _NodePropsContext extends _YamlContext {
    /**
     * Processes the start of a line in node properties context.
     * @param {Object} ctx
     * @param {Integer} indent
     * @param {Object} nextToken
     * @param {Integer} contextIndent
     * @returns {Boolean}
     */
    ProcessLineStart(ctx, indent, nextToken, contextIndent) {
        lastIndent := ctx.IndentStack.Current
        if (indent < lastIndent) {
            ctx.ContextStack.Pop()
            return true
        }
        ; Properties do NOT establish indentation levels themselves,
        ; but if we are here, we might be at the content line following properties.
        ; We should let the parent context handle the indentation.
        if (!nextToken.IsAnyOf(_YamlToken.Type.Tag, _YamlToken.Type.Anchor)) {
            ctx.ContextStack.Pop()
            return true
        }
        return false
    }

    /**
     * Handles tokens in node properties context.
     * @param {Object} ctx
     * @param {Object} token
     * @returns {Boolean}
     */
    OnToken(ctx, token) {
        if (token.IsScalar
            || (token.Is(_YamlToken.Type.Punctuator) && InStr("[]{|}>", token.value))) {
            ctx.ContextStack.Pop()
            return false
        }
        return false
    }
}
