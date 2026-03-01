#Requires AutoHotkey v2.0

/**
 * @file _BlockContext.ahk
 * @description Handles common logic for block-style collections (Root, Map, Seq).
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Handles common logic for block-style collections (Root, Map, Seq).
 */
class _BlockContext extends _YamlContext {
    /**
     * Processes the start of a line in block context.
     * @param {Object} ctx
     * @param {Integer} indent
     * @param {Object} nextToken
     * @param {Integer} contextIndent
     * @returns {Boolean}
     */
    ProcessLineStart(ctx, indent, nextToken, contextIndent) {
        if (nextToken.IsAnyOf(_YamlToken.Type.Tag, _YamlToken.Type.Anchor)) {
            ; Properties do NOT establish a new indentation level.
            ; We must ensure they are at least as indented as the current level.
            if (indent < ctx.IndentStack.Current) {
                ctx.HandleIndentation(indent, nextToken)
            }
            return false
        }
        ctx.HandleIndentation(indent, nextToken)
        return false
    }

    /**
     * Handles tokens in block context.
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
        }
        if (token.IsAnyOf(_YamlToken.Type.Tag, _YamlToken.Type.Anchor)) {
            ctx.ContextStack.Push(_YamlContext.Type.NodeProps)
            return true
        }
        return false
    }
}
