#Requires AutoHotkey v2.0

/**
 * @file _Parser.ahk
 * @description Syntactic analysis and event generation.
 * @author nullmake
 * @license Apache-2.0
 *
 * Copyright 2026 nullmake
 */

/**
 * @class _YamlParser
 * Produces a stream of YAML events by consuming tokens from the Scanner.
 */
class _YamlParser {
    /**
     * @field {Object} _scanner - Token source.
     */
    _scanner := ""

    /**
     * @field {Array} _states - Stack of parsing states (function objects).
     */
    _states := []

    /**
     * @field {Object} _peekedToken - Lookahead token.
     */
    _peekedToken := ""

    /**
     * @constructor
     * @param {Object} scanner - An instance of _YamlScanner.
     */
    __New(scanner) {
        this._scanner := scanner
        ; Start with the stream level
        this._states.Push(this._StateStreamStart.Bind(this))
    }

    /**
     * @method NextEvent
     * Consumes tokens and returns the next YAML event.
     * @returns {YamlEvent}
     */
    NextEvent() {
        if (this._states.Length == 0) {
            return ""
        }

        ; Execute the current state logic
        _stateFunc := this._states[this._states.Length]
        return _stateFunc()
    }

    /**
     * @method _PeekToken
     * Returns the next token without consuming it.
     */
    _PeekToken() {
        if (this._peekedToken == "") {
            this._peekedToken := this._scanner.FetchToken()
        }
        return this._peekedToken
    }

    /**
     * @method _FetchToken
     * Returns and consumes the next token.
     */
    _FetchToken() {
        if (this._peekedToken != "") {
            _token := this._peekedToken
            this._peekedToken := ""
            return _token
        }
        return this._scanner.FetchToken()
    }

    /**
     * @method _StateStreamStart
     * Initial state: emits StreamStart and moves to DocumentStart.
     */
    _StateStreamStart() {
        this._states.Pop()
        this._states.Push(this._StateDocumentStart.Bind(this))
        return YamlStreamStartEvent()
    }

    /**
     * @method _StateDocumentStart
     * Handles implicit or explicit document starts.
     */
    _StateDocumentStart() {
        _token := this._PeekToken()

        ; Handle Stream End
        if (_token.Type == "StreamEnd") {
            this._states.Pop()
            return YamlStreamEndEvent()
        }

        ; Explicit Document Start '---'
        _explicit := false
        if (_token.Type == "DocumentStart") {
            this._FetchToken()
            _explicit := true
        }

        this._states.Pop()
        this._states.Push(this._StateDocumentEnd.Bind(this))
        this._states.Push(this._StateBlockNode.Bind(this))

        return YamlDocumentStartEvent(_explicit, _token.Line, _token.Column)
    }

    /**
     * @method _StateDocumentEnd
     * Emits DocumentEnd and returns to DocumentStart.
     */
    _StateDocumentEnd() {
        this._states.Pop()
        this._states.Push(this._StateDocumentStart.Bind(this))
        return YamlDocumentEndEvent(false)
    }

    /**
     * @method _StateBlockNode
     * Handles nodes in a block context (Scalar, Mapping, Sequence).
     */
    _StateBlockNode() {
        _token := this._FetchToken()

        if (_token.Type == "Scalar") {
            this._states.Pop()
            return YamlScalarEvent(_token.Value, "", "", 0, _token.Line, _token.Column)
        }

        throw YamlError("Expected scalar, but found " . _token.Type, _token.Line, _token.Column)
    }
}
