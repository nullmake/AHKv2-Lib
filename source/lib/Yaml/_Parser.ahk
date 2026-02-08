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
     * @field {Array} _states - Stack of parsing state names (method names).
     */
    _states := []

    /**
     * @field {Array} _tokens - Lookahead token queue.
     */
    _tokens := []

    /**
     * @constructor
     * @param {Object} scanner - An instance of _YamlScanner.
     */
    __New(scanner) {
        this._scanner := scanner
        ; Start with the stream level
        this._states.Push("_StateStreamStart")
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
        
        _stateName := this._states[this._states.Length]
        return this.%_stateName%()
    }

    /**
     * @method _PeekToken
     * Returns the N-th next token without consuming it.
     * @param {Integer} n - The lookahead depth.
     */
    _PeekToken(n := 1) {
        while (this._tokens.Length < n) {
            _t := this._scanner.FetchToken()
            this._tokens.Push(_t)
            if (_t.Type == "StreamEnd") {
                break
            }
        }
        return (n <= this._tokens.Length) ? this._tokens[n] : this._tokens[this._tokens.Length]
    }

    /**
     * @method _FetchToken
     * Returns and consumes the next token from the queue or scanner.
     */
    _FetchToken() {
        if (this._tokens.Length > 0) {
            return this._tokens.RemoveAt(1)
        }
        return this._scanner.FetchToken()
    }

    /**
     * @method _StateStreamStart
     * Initial state: emits StreamStart.
     */
    _StateStreamStart() {
        this._states.Pop()
        this._states.Push("_StateDocumentStart")
        return YamlStreamStartEvent()
    }

    /**
     * @method _StateDocumentStart
     * Handles implicit or explicit document starts.
     */
    _StateDocumentStart() {
        _token := this._PeekToken()
        
        if (_token.Type == "StreamEnd") {
            this._states.Pop()
            return YamlStreamEndEvent()
        }

        _explicit := false
        if (_token.Type == "DocumentStart") {
            this._FetchToken()
            _explicit := true
        }

        this._states.Pop()
        this._states.Push("_StateDocumentEnd")
        this._states.Push("_StateBlockNode")
        
        return YamlDocumentStartEvent(_explicit, _token.Line, _token.Column)
    }

    /**
     * @method _StateDocumentEnd
     * Emits DocumentEnd and returns to DocumentStart.
     */
    _StateDocumentEnd() {
        this._states.Pop()
        this._states.Push("_StateDocumentStart")
        return YamlDocumentEndEvent(false)
    }

    /**
     * @method _StateBlockNode
     * Handles nodes in a block context (Scalar, Mapping, Sequence).
     */
    _StateBlockNode() {
        _token := this._PeekToken()
        
        ; Nested structure begins with an Indent token
        if (_token.Type == "Indent") {
            this._FetchToken() ; Consume 'Indent'
            return this.NextEvent() ; Recurse to find the actual node type
        }

        if (_token.Type == "Scalar") {
            _next := this._PeekToken(2)
            
            if (_next.Type == "MappingIndicator") {
                ; Transition to Mapping: Send MappingStart and then process keys
                this._states.Pop()
                this._states.Push("_StateBlockMappingEnd")
                this._states.Push("_StateBlockMappingKey")
                return YamlMappingStartEvent("", "", false, _token.Line, _token.Column)
            }
            
            ; Simple scalar node
            this._FetchToken()
            this._states.Pop()
            return YamlScalarEvent(_token.Value, "", "", 0, _token.Line, _token.Column)
        }
        
        ; Handle empty values or end of structures
        if (_token.Type == "Dedent" || _token.Type == "StreamEnd" || _token.Type == "DocumentStart") {
            this._states.Pop()
            return YamlScalarEvent("", "", "", 0, _token.Line, _token.Column)
        }
        
        throw YamlError("Expected scalar or indent, but found " . _token.Type, _token.Line, _token.Column)
    }

    /**
     * @method _StateBlockMappingKey
     * Decides whether to continue the mapping or end it based on the next token.
     */
    _StateBlockMappingKey() {
        _token := this._PeekToken()
        
        ; Mapping ends on Dedent or new document/stream
        if (_token.Type == "Dedent" || _token.Type == "StreamEnd" || _token.Type == "DocumentStart") {
            if (_token.Type == "Dedent") {
                this._FetchToken() ; Consume the 'Dedent' that closed this mapping
            }
            this._states.Pop()
            return this.NextEvent() ; Proceed to BlockMappingEnd
        }
        
        ; If there's another scalar, it's a new key
        if (_token.Type == "Scalar") {
            this._states.Pop()
            this._states.Push("_StateBlockMappingValue")
            return this.NextEvent()
        }

        ; Skip other virtual tokens
        this._FetchToken()
        return this._StateBlockMappingKey()
    }

    /**
     * @method _StateBlockMappingValue
     * Processes a single key-value pair in a block mapping.
     */
    _StateBlockMappingValue() {
        _keyToken := this._FetchToken() ; Consumes Key Scalar
        _indicator := this._FetchToken() ; Consumes ':'
        
        ; Transition: After returning the key, parse the value
        this._states.Pop()
        this._states.Push("_StateBlockMappingKey") 
        this._states.Push("_StateBlockNode") 
        
        return YamlScalarEvent(_keyToken.Value, "", "", 0, _keyToken.Line, _keyToken.Column)
    }

    /**
     * @method _StateBlockMappingEnd
     * Emits MappingEnd event.
     */
    _StateBlockMappingEnd() {
        this._states.Pop()
        return YamlMappingEndEvent()
    }
}