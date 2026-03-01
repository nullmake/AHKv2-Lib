#Requires AutoHotkey v2.0

/**
 * @file _YamlContext.ahk
 * @description Base class for YAML layout contexts.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Base class for YAML layout contexts.
 */
class _YamlContext {
    /**
     * Context Types.
     */
    class Type {
        static Streamstart => 1
        static Root => 2
        static BlockMap => 3
        static BlockSeq => 4
        static NodeProps => 5
        static BlockScalar => 6
        static Flow => 7

        /**
         * Returns the name of the context type.
         * @param {Integer} type
         * @returns {String}
         */
        static GetName(type) {
            switch type {
                case _YamlContext.Type.Streamstart: return "Streamstart"
                case _YamlContext.Type.Root: return "Root"
                case _YamlContext.Type.BlockMap: return "BlockMap"
                case _YamlContext.Type.BlockSeq: return "BlockSeq"
                case _YamlContext.Type.NodeProps: return "NodeProps"
                case _YamlContext.Type.BlockScalar: return "BlockScalar"
                case _YamlContext.Type.Flow: return "Flow"
                default: throw Error("Not supported type:" . type)
            }
        }
    }

    /**
     * Processes the start of a line in the current context.
     * @param {Object} ctx - Layout processor context
     * @param {Integer} indent - Current line indentation
     * @param {Object} nextToken - The first non-space token on the line
     * @param {Integer} contextIndent - Required indentation level
     * @returns {Boolean} True if the context should be popped
     */
    ProcessLineStart(ctx, indent, nextToken, contextIndent) {
        throw Error("Not implemented")
    }

    /**
     * Handles a token in the current context.
     * @param {Object} ctx - Layout processor context
     * @param {Object} token - The token to process
     * @returns {Boolean} True if the token was consumed/handled
     */
    OnToken(ctx, token) {
        throw Error("Not implemented")
    }

    /**
     * Collects a scalar value according to the current context.
     * @param {Object} ctx - The layout processor context.
     * @param {Object} scanner - The raw scanner.
     * @param {Object} hint - Information about the scalar to collect.
     * @returns {Object} A Scalar token.
     */
    CollectScalar(ctx, scanner, hint) {
        throw Error("Scalar collection not supported in " . Type(this))
    }
}
