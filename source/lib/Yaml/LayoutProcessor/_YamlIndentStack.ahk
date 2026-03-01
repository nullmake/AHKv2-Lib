#Requires AutoHotkey v2.0

/**
 * @file _YamlIndentStack.ahk
 * @description YAML Indentation Stack.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Stack for managing nested indentation levels.
 */
class _YamlIndentStack extends Array {
    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /**
     * @param {_YamlTracer|String} [tracer=""] - Scoped tracer instance
     */
    __New(tracer := "") {
        this._tracer := tracer
        super.Push(-1)
    }

    /**
     * Current indentation level (top of stack).
     */
    Current => this[this.Length]

    /**
     * Creates a deep copy of the stack.
     * @returns {Object} Cloned stack
     */
    Clone() {
        cloned := _YamlIndentStack(this._tracer)
        super.Pop.Call(cloned) ; Remove default -1
        for item in this {
            super.Push.Call(cloned, item)
        }
        return cloned
    }

    /**
     * Pushes a new indentation level onto the stack.
     * @param {Integer} indent
     */
    Push(indent) {
        if (this._tracer) {
            this._tracer.Trace("INDENT_PUSH: " . indent)
        }
        super.Push(indent)
    }

    /**
     * Pops the top indentation level from the stack.
     * @returns {Integer|String} The popped level, or empty string if at base
     */
    Pop() {
        if (this.Length > 1) {
            indent := super.Pop()
            if (this._tracer) {
                this._tracer.Trace("INDENT_POP: " . indent)
            }
            return indent
        }
        return ""
    }

    /**
     * Returns a string representation of the stack.
     * @returns {String}
     */
    ToString() {
        str := ""
        for i, indent in this {
            str .= (i == 1 ? "" : " > ") . indent
        }
        return str
    }
}
