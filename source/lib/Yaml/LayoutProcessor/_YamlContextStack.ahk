#Requires AutoHotkey v2.0

/**
 * @file _YamlContextStack.ahk
 * @description YAML Layout Context Stack.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Stack for managing nested layout contexts.
 */
class _YamlContextStack extends Array {
    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /**
     * @param {_YamlTracer|String} [tracer=""] - Scoped tracer instance
     */
    __New(tracer := "") {
        this._tracer := tracer
    }

    /**
     * Checks if any context in the stack matches the given type.
     * @param {Integer} typeId
     * @returns {Boolean}
     */
    Has(typeId) {
        for ctxId in this {
            if (ctxId == typeId) {
                return true
            }
        }
        return false
    }

    /**
     * Current state (top of stack).
     */
    Current => this[this.Length]

    /**
     * Creates a deep copy of the stack.
     * @returns {Object} Cloned stack
     */
    Clone() {
        cloned := _YamlContextStack(this._tracer)
        for item in this {
            super.Push.Call(cloned, item)
        }
        return cloned
    }

    /**
     * Pushes a new context ID onto the stack.
     * @param {Integer} ctxId
     */
    Push(ctxId) {
        if (this._tracer) {
            this._tracer.Trace("CONTEXT_PUSH: " . _YamlContext.Type.GetName(ctxId))
        }
        super.Push(ctxId)
    }

    /**
     * Pops the top context ID from the stack.
     * @returns {Integer|String} The popped ID, or empty string if at base
     */
    Pop() {
        if (this.Length > 1) {
            ctxId := super.Pop()
            if (this._tracer) {
                this._tracer.Trace("CONTEXT_POP: " . _YamlContext.Type.GetName(ctxId))
            }
            return ctxId
        }
        return ""
    }

    /**
     * Returns a string representation of the stack.
     * @returns {String}
     */
    ToString() {
        str := ""
        for i, ctxId in this {
            str .= (i == 1 ? "" : " > ") . _YamlContext.Type.GetName(ctxId)
        }
        return str
    }
}
