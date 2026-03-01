#Requires AutoHotkey v2.0

/**
 * @file _YamlParserContext.ahk
 * @description Context data and utility methods used by YAML Parser states.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Context data used by each state of the YAML parser.
 */
class _YamlParserContext {
    /** @field {Object} _processor - Layout processor instance */
    _processor := unset

    /** @field {Object} _states - Stack of parser states */
    _states := _YamlParserStateStack()

    /** @field {Array} _savepoints - Stack of savepoints for speculative parsing */
    _savepoints := []

    /** @field {YamlOptions} _options - Configuration options */
    _options := unset

    /** @field {Map} _tagHandles - Registry of tag handles and their expanded prefixes */
    _tagHandles := Map("!", "!", "!!", "tag:yaml.org,2002:")

    /** @field {Boolean} _lastDocEndedWithMarker - Whether the previous document ended with '...' */
    _lastDocEndedWithMarker := false

    /** @field {Boolean} _currentDocStartedWithMarker - Whether the current document started with '---' */
    _currentDocStartedWithMarker := false

    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /**
     * @param {Object} processor - Layout processor instance
     * @param {YamlOptions} [options] - Configuration options
     */
    __New(processor, options := "") {
        this._processor := processor
        this._options := (options is YamlOptions) ? options : YamlOptions(options)
        this._tracer := this._options.CreateTracer("Parser")
    }

    /**
     * Layout processor instance.
     */
    Processor => this._processor

    /**
     * Parser state stack.
     */
    States => this._states

    /**
     * Registered tag handles.
     */
    TagHandles => this._tagHandles

    /**
     * Scoped tracer instance.
     */
    Tracer => this._tracer

    /**
     * Whether the previous document ended with '...'.
     */
    LastDocEndedWithMarker {
        get => this._lastDocEndedWithMarker
        set => this._lastDocEndedWithMarker := value
    }

    /**
     * Whether the current document started with '---'.
     */
    CurrentDocStartedWithMarker {
        get => this._currentDocStartedWithMarker
        set => this._currentDocStartedWithMarker := value
    }

    /**
     * Resets tag handles to defaults.
     */
    ResetTags() {
        this._tagHandles := Map("!", "!", "!!", "tag:yaml.org,2002:")
    }

    /**
     * Registers a new tag handle.
     * @param {String} handle
     * @param {String} prefix
     */
    RegisterTagHandle(handle, prefix) {
        if (this._tagHandles.Has(handle) && handle != "!" && handle != "!!") {
            ; Only throw if it's a custom handle being redefined
            throw YamlError("Duplicate %TAG directive for handle: " . handle)
        }
        this._tagHandles[handle] := prefix
        if (this._tracer) {
            this._tracer.Trace(Format("Registered TAG handle: {} -> {}", handle, prefix))
        }
    }

    /**
     * Expands a tag using registered handles.
     * @param {String} tag
     * @returns {String} Expanded tag
     */
    ExpandTag(tag) {
        if (tag == "" || tag == "!" || SubStr(tag, 1, 1) == "&") {
            return tag
        }
        if (SubStr(tag, 1, 2) == "!<") {
            return SubStr(tag, 3, -1)
        }

        ; 1. Find the longest matching handle
        bestHandle := ""
        for handle, prefix in this._tagHandles {
            if (SubStr(tag, 1, StrLen(handle)) == handle) {
                if (StrLen(handle) > StrLen(bestHandle)) {
                    bestHandle := handle
                }
            }
        }

        ; 2. Expand if handle found, otherwise validate
        if (bestHandle != "") {
            suffix := SubStr(tag, StrLen(bestHandle) + 1)

            ; VALIDATION: Named handles and secondary handles MUST have a non-empty suffix.
            ; Primary handle (!) can have an empty suffix (non-specific tag).
            if (suffix == "" && bestHandle != "!") {
                throw YamlError("Tag handle used without suffix: " . bestHandle)
            }

            ; VALIDATION: Primary handle's suffix MUST NOT contain '!'.
            ; If it does, it was likely an intended but undefined named handle.
            if (bestHandle == "!" && InStr(suffix, "!")) {
                throw YamlError("Using undefined tag handle or invalid local tag: " . tag)
            }

            return this._tagHandles[bestHandle] . this._UriDecode(suffix)
        }

        ; VALIDATION: If it starts with '!', it MUST match a known handle (should be handled above)
        if (SubStr(tag, 1, 1) == "!") {
            throw YamlError("Using undefined tag handle: " . tag)
        }

        return tag
    }

    /**
     * Decodes percent-encoded characters in a URI.
     * @param {String} str
     * @returns {String} Decoded string
     */
    _UriDecode(str) {
        result := ""
        pos := 1
        len := StrLen(str)
        while (pos <= len) {
            char := SubStr(str, pos, 1)
            if (char == "%") {
                hex := SubStr(str, pos + 1, 2)
                if (RegExMatch(hex, "i)^[0-9A-F]{2}$")) {
                    result .= Chr(Integer("0x" . hex))
                    pos += 3
                    continue
                }
            }
            result .= char
            pos += 1
        }
        return result
    }

    /**
     * Whether the parser is currently speculating.
     */
    IsSpeculating => this._savepoints.Length > 0

    /**
     * Creates a savepoint for the current state.
     * @param {String} hypothesis - Description of the speculation
     */
    CreateSavepoint(hypothesis) {
        processorState := this._processor.CaptureState()
        this._savepoints.Push({
            states: this._DeepCloneStates(this._states),
            processorState: processorState,
            hypothesis: hypothesis,
            tagHandles: this._tagHandles.Clone()
        })
        if (this._tracer) {
            this._tracer.Trace(Format("[SAVEPOINT] Start Try: {} (POS: {})",
                hypothesis, processorState.scannerState.pos))
        }
    }

    /**
     * Executes a function speculatively and rolls back on failure.
     * @param {String} hypothesis
     * @param {Object} fn - Function to execute
     * @returns {Boolean} True if speculation succeeded
     */
    Speculate(hypothesis, fn) {
        this.CreateSavepoint(hypothesis)
        try {
            fn.Call()
            this.Commit()
            return true
        } catch _YamlSpeculativeParseError as e {
            this.Rollback(e.message)
            return false
        } catch YamlError as e {
            ; Hard error during speculation: propagate it
            throw e
        } catch Any as e {
            if (this._tracer) {
                this._tracer.Trace(Format("[SPECULATE] Unexpected Error in {}: {}", hypothesis, e.message))
            }
            this.Rollback("System Error")
            return false
        }
    }

    /**
     * Rolls back the state to the last savepoint.
     * @param {String} [reason=""]
     */
    Rollback(reason := "") {
        if (this._savepoints.Length == 0) {
            return
        }
        sp := this._savepoints.Pop()
        this._states := sp.states
        this._processor.RestoreState(sp.processorState)
        this._tagHandles := sp.tagHandles
        if (this._tracer) {
            this._tracer.Trace(Format("!!! ROLLBACK: {} -> REASON: {} -> RESET_POS: {}",
                sp.hypothesis, reason, sp.processorState.scannerState.pos))
        }
    }

    /**
     * Commits the current state and discards the last savepoint.
     */
    Commit() {
        if (this._savepoints.Length > 0) {
            sp := this._savepoints.Pop()
            if (this._tracer) {
                this._tracer.Trace(Format("[COMMIT] Hypothesis: {} was successful", sp.hypothesis))
            }
        }
    }

    /**
     * Deep clones the state stack.
     * @param {Object} states
     * @returns {Object} Cloned stack
     */
    _DeepCloneStates(states) {
        cloned := _YamlParserStateStack()
        idx := 1
        while (idx <= states.Length) {
            cloned.Push(states[idx].DeepClone())
            idx++
        }
        return cloned
    }
}
