#Requires AutoHotkey v2.0

/**
 * @file _YamlTracer.ahk
 * @description Internal helper class for scoped tracing.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Scoped tracer that prepends component names to messages.
 */
class _YamlTracer {
    /** @field {Object} _callback - Original trace callback */
    _callback := unset

    /** @field {String} _component - Component name prefix */
    _component := ""

    /**
     * @param {Object} callback
     * @param {String} component
     */
    __New(callback, component) {
        this._callback := callback
        this._component := component
    }

    /**
     * Executes the trace callback with the component prefix.
     * @param {String} msg
     */
    Trace(msg) {
        _safeMsg := IsObject(msg) ? "[Object]" : String(msg)
        this._callback.Call("[" . this._component . "] " . _safeMsg)
    }
}
