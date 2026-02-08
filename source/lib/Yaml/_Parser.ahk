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
            if (_t.type == "StreamEnd") {
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
        
        if (_token.type == "StreamEnd") {
            this._states.Pop()
            return YamlStreamEndEvent()
        }

        _explicit := false
        if (_token.type == "DocumentStart") {
            this._FetchToken()
            _explicit := true
        }

        this._states.Pop()
        this._states.Push("_StateDocumentEnd")
        this._states.Push("_StateBlockNode")
        
        return YamlDocumentStartEvent(_explicit, _token.line, _token.column)
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
        if (_token.type == "Indent") {
            this._FetchToken()
            return this.NextEvent()
        }

        ; Block Sequence
        if (_token.type == "SequenceIndicator") {
            this._states.Pop()
            this._states.Push("_StateBlockSequenceEnd")
            this._states.Push("_StateBlockSequenceEntry")
            return YamlSequenceStartEvent("", "", false, _token.line, _token.column)
        }

        if (_token.type == "Scalar") {
            _next := this._PeekToken(2)
            
            if (_next.type == "MappingIndicator") {
                ; Transition to Mapping: Send MappingStart and then process keys
                this._states.Pop()
                this._states.Push("_StateBlockMappingEnd")
                this._states.Push("_StateBlockMappingKey")
                return YamlMappingStartEvent("", "", false, _token.line, _token.column)
            }
            
            ; Simple scalar node
            this._FetchToken()
            this._states.Pop()
            return YamlScalarEvent(_token.value, "", "", 0, _token.line, _token.column)
        }
        
        if (_token.type == "Dedent" || _token.type == "StreamEnd" || _token.type == "DocumentStart") {
            this._states.Pop()
            return YamlScalarEvent("", "", "", 0, _token.line, _token.column)
        }
        
        throw YamlError("Expected scalar, sequence, or indent, but found " . _token.type, _token.line, _token.column)
    }

    /**
     * @method _StateBlockSequenceEntry
     * Handles a single '-' entry in a block sequence.
     */
    _StateBlockSequenceEntry() {
        this._FetchToken() ; Consumes '-'
        
        this._states.Pop()
        this._states.Push("_StateBlockSequenceNext")
        this._states.Push("_StateBlockNode")
        
        return this.NextEvent()
    }

    /**
     * @method _StateBlockSequenceNext
     * Checks if there's another '-' or if the sequence ends.
     */
    _StateBlockSequenceNext() {
        _token := this._PeekToken()
        
        if (_token.type == "SequenceIndicator") {
            this._states.Pop()
            this._states.Push("_StateBlockSequenceEntry")
            return this.NextEvent()
        }
        
        if (_token.type == "Dedent" || _token.type == "StreamEnd" || _token.type == "DocumentStart") {
            if (_token.type == "Dedent") {
                this._FetchToken()
            }
            this._states.Pop()
            return this.NextEvent()
        }
        
        throw YamlError("Expected sequence entry or dedent, but found " . _token.type, _token.line, _token.column)
    }

    /**
     * @method _StateBlockSequenceEnd
     */
    _StateBlockSequenceEnd() {
        this._states.Pop()
        return YamlSequenceEndEvent()
    }

    /**
     * @method _StateBlockMappingKey
     * Decides whether to continue the mapping or end it.
     */
    _StateBlockMappingKey() {
        _token := this._PeekToken()
        
        if (_token.type == "Dedent" || _token.type == "StreamEnd" || _token.type == "DocumentStart") {
            if (_token.type == "Dedent") {
                this._FetchToken()
            }
            this._states.Pop()
            return this.NextEvent() ; Proceed to BlockMappingEnd
        }
        
        if (_token.type == "Scalar") {
            this._states.Pop()
            this._states.Push("_StateBlockMappingValue")
            return this.NextEvent()
        }

        this._FetchToken()
        return this._StateBlockMappingKey()
    }

    /**
     * @method _StateBlockMappingValue
     */
    _StateBlockMappingValue() {
        _keyToken := this._FetchToken() ; Consumes Key
        this._FetchToken() ; Consumes ':'
        
        this._states.Pop()
        this._states.Push("_StateBlockMappingKey") 
        this._states.Push("_StateBlockNode") 
        
        return YamlScalarEvent(_keyToken.value, "", "", 0, _keyToken.line, _keyToken.column)
    }

    /**
     * @method _StateBlockMappingEnd
     */
    _StateBlockMappingEnd() {
        this._states.Pop()
        return YamlMappingEndEvent()
    }
}