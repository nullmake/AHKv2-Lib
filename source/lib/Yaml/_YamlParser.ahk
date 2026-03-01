#Requires AutoHotkey v2.0

/**
 * @file _YamlParser.ahk
 * @description Layer 3: YAML Parser implementation using a state machine.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * YAML Parser.
 */
class _YamlParser {
    /** @field {Object} _ctx - Parser context instance */
    _ctx := unset

    /** @field {Integer} _lastEventPos - Position in the stream when the last event was emitted */
    _lastEventPos := -1

    /** @field {String} _lastEventType - Type of the last emitted event */
    _lastEventType := ""

    /** @field {Integer} _lastStackLen - Length of the state stack when the last event was emitted */
    _lastStackLen := -1

    /** @field {Integer} _samePosEventCount - Counter for events emitted at the same position (for loop detection) */
    _samePosEventCount := 0

    /** @field {Boolean} _isStalled - Whether the parser has encountered a terminal error/loop */
    _isStalled := false

    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /**
     * @param {Object} processor - Layout processor instance
     * @param {YamlOptions} [options] - Configuration options
     */
    __New(processor, options := "") {
        this._ctx := _YamlParserContext(processor, options)
        _opts := (options is YamlOptions) ? options : YamlOptions(options)
        this._tracer := _opts.CreateTracer("Parser")
        this._ctx.States.Push(_ParseStreamStartState())
    }

    /**
     * Fetches the next event from the parser.
     * @returns {Object|String} A YamlEvent object, or empty string if no more events.
     */
    NextEvent() {
        if (this._isStalled) {
            return ""
        }

        safetyCounter := 0
        lastLoopPos := -1
        lastStackLen := -1
        lastState := ""

        while (this._ctx.States.Length > 0) {
            processorState := this._ctx.Processor.CaptureState()
            currPos := processorState.scannerState.pos
            currStackLen := this._ctx.States.Length

            if (this._ctx.States.Current == "") {
                break
            }
            currState := this._ctx.States.Current.state

            if (++safetyCounter > 1000) {
                this._isStalled := true
                throw YamlError(Format("Safety break: transitions exceeded limit (State: {})", currState),
                processorState.scannerState.line, processorState.scannerState.column)
            }

            if (currPos == lastLoopPos && currStackLen == lastStackLen && currState == lastState) {
                this._isStalled := true
                throw YamlError(Format("Infinite loop detected: state '{}' stalled at POS: {}", currState, currPos),
                processorState.scannerState.line, processorState.scannerState.column)
            }

            lastLoopPos := currPos
            lastStackLen := currStackLen
            lastState := currState

            stateObj := this._ctx.States.Current
            event := stateObj.Handle(this._ctx)

            if (IsObject(event)) {
                if (currPos == this._lastEventPos && event.type == this._lastEventType && currStackLen == this._lastStackLen
                ) {
                    if (++this._samePosEventCount > 10) {
                        this._isStalled := true
                        throw YamlError(Format("Repeated event at same POS: {} type: {} depth: {}", currPos, event.type,
                            currStackLen), event.line, event.column)
                    }
                } else {
                    this._samePosEventCount := 0
                }

                this._lastEventPos := currPos
                this._lastEventType := event.type
                this._lastStackLen := currStackLen
                if (this._tracer) {
                    this._tracer.Trace(">>> EMIT EVENT: " . event.type . " at POS: " . currPos)
                }
                return event
            }
        }
        return ""
    }
}
