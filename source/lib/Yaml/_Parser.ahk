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
    * @field {String} _pendingAnchor - Temporary storage for an anchor name.
    */
    _pendingAnchor := ""

    /**
    * @field {String} _pendingTag - Temporary storage for a tag name.
    */
    _pendingTag := ""

    /**
    * @field {Integer} _loopDetector - Counter for transitions without token consumption.
    */
    _loopDetector := 0

    /**
    * @field {Object} _pendingDocumentStart - Buffered DocumentStartEvent.
    */
    _pendingDocumentStart := ""

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
        loop {
            if (this._states.Length == 0) {
                return ""
            }

            ; Return pending DocumentStart if it exists
            if (this._pendingDocumentStart) {
                _event := this._pendingDocumentStart
                this._pendingDocumentStart := ""
                this._loopDetector := 0
                return _event
            }

            ; Safety: Prevent infinite loops without progress
            this._loopDetector++
            if (this._loopDetector > 1000) {
                throw YamlError("Infinite loop detected in Parser: too many state transitions without token consumption.")
            }

            _stateName := this._states[this._states.Length]
            _event := this.%_stateName%()

            ; If an event was generated, return it and reset detector.
            ; Otherwise, continue to the next state.
            if (_event !== "") {
                this._loopDetector := 0
                return _event
            }
        }
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
        this._loopDetector := 0 ; Progress made
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

        ; Skip Directives (%) and DocumentEnd (...) before document starts
        while (_token.type == "Directive" || _token.type == "DocumentEnd") {
            this._FetchToken()
            _token := this._PeekToken()
        }

        if (_token.type == "StreamEnd") {
            this._states.Pop()
            return YamlStreamEndEvent()
        }

        ; Explicit Document Start '---'
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
        _token := this._PeekToken()
        _explicit := false

        if (_token.type == "DocumentEnd") {
            this._FetchToken()
            _explicit := true
        }

        this._states.Pop()
        this._states.Push("_StateDocumentStart")
        return YamlDocumentEndEvent(_explicit, _token.line, _token.column)
    }

    /**
    * @method _StateBlockNode
    * Handles nodes in a block context (Scalar, Mapping, Sequence).
    */
    _StateBlockNode() {
        _token := this._PeekToken()

        ; Property: Anchor (&anchor)
        if (_token.type == "Anchor") {
            this._pendingAnchor := this._FetchToken().value
            return this.NextEvent() ; Continue to actual node
        }

        ; Property: Tag (!tag)
        if (_token.type == "Tag") {
            this._pendingTag := this._FetchToken().value
            return this.NextEvent() ; Continue to actual node
        }

        ; Property: Alias (*alias)
        if (_token.type == "Alias") {
            _aliasToken := this._FetchToken()
            this._states.Pop()
            return YamlAliasEvent(_aliasToken.value, _aliasToken.line, _aliasToken.column)
        }

        ; Nested structure begins with an Indent token
        if (_token.type == "Indent") {
            this._FetchToken()
            return ""
        }

        ; Block Sequence
        if (_token.type == "SequenceIndicator") {
            _anchor := this._pendingAnchor
            _tag := this._pendingTag
            this._pendingAnchor := ""
            this._pendingTag := ""
            this._states.Pop()
            this._states.Push("_StateBlockSequenceEnd")
            this._states.Push("_StateBlockSequenceEntry")
            return YamlSequenceStartEvent(_tag, _anchor, false, _token.line, _token.column)
        }

        ; Flow Sequence
        if (_token.type == "FlowSequenceStart") {
            _anchor := this._pendingAnchor
            _tag := this._pendingTag
            this._pendingAnchor := ""
            this._pendingTag := ""
            this._FetchToken()
            this._states.Pop()
            this._states.Push("_StateFlowSequenceNext")
            return YamlSequenceStartEvent(_tag, _anchor, true, _token.line, _token.column)
        }

        ; Flow Mapping
        if (_token.type == "FlowMappingStart") {
            _anchor := this._pendingAnchor
            _tag := this._pendingTag
            this._pendingAnchor := ""
            this._pendingTag := ""
            this._FetchToken()
            this._states.Pop()
            this._states.Push("_StateFlowMappingKey")
            return YamlMappingStartEvent(_tag, _anchor, true, _token.line, _token.column)
        }

        if (_token.type == "Scalar") {
            _next := this._PeekToken(2)

            if (_next.type == "MappingIndicator") {
                ; Transition to Mapping
                _anchor := this._pendingAnchor
                _tag := this._pendingTag
                this._pendingAnchor := ""
                this._pendingTag := ""
                this._states.Pop()
                this._states.Push("_StateBlockMappingEnd")
                this._states.Push("_StateBlockMappingKey")
                return YamlMappingStartEvent(_tag, _anchor, false, _token.line, _token.column)
            }

            ; Simple scalar node
            _anchor := this._pendingAnchor
            _tag := this._pendingTag
            this._pendingAnchor := ""
            this._pendingTag := ""
            this._FetchToken()
            this._states.Pop()
            return YamlScalarEvent(_token.value, _tag, _anchor, _token.style, _token.line, _token.column)
        }

        ; Handle end of structures or document boundaries
        if (_token.type == "Dedent" || _token.type == "StreamEnd" || _token.type == "DocumentStart" || _token.type == "DocumentEnd") {
            if (_token.type == "Dedent") {
                this._FetchToken()
                return ""
            }

            _anchor := this._pendingAnchor
            _tag := this._pendingTag
            this._pendingAnchor := ""
            this._pendingTag := ""
            this._states.Pop()

            ; Implicit null scalar
            return YamlScalarEvent("", _tag, _anchor, 0, _token.line, _token.column)
        }

        throw YamlError("Expected scalar, collection, or indent, but found " . _token.type, _token.line, _token.column)
    }

    /**
    * @method _StateBlockSequenceEntry
    * Handles a single '-' entry in a block sequence.
    */
    _StateBlockSequenceEntry() {
        this._FetchToken() ; Consumes '-'

        _token := this._PeekToken()
        
        ; If the entry is a mapping (e.g., "- key: value"), start the mapping immediately
        if (_token.type == "Scalar" && this._PeekToken(2).type == "MappingIndicator") {
            this._states.Pop()
            this._states.Push("_StateBlockSequenceNext")
            this._states.Push("_StateBlockMappingEnd")
            this._states.Push("_StateBlockMappingKey")
            return YamlMappingStartEvent("", "", false, 0, _token.line, _token.column)
        }

        this._states.Pop()
        this._states.Push("_StateBlockSequenceNext")
        this._states.Push("_StateBlockNode")

        return ""
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
            return ""
        }

        if (_token.type == "Dedent" || _token.type == "StreamEnd" || _token.type == "DocumentStart" || _token.type == "DocumentEnd") {
            if (_token.type == "Dedent") {
                this._FetchToken()
            }
            this._states.Pop()
            return "" ; Proceed to BlockSequenceEnd
        }

        throw YamlError("Expected sequence entry or dedent, but found " . _token.type, _token.line, _token.column)
    }

    /**
    * @method _StateBlockSequenceEnd
    * Emits SequenceEnd event.
    */
    _StateBlockSequenceEnd() {
        this._states.Pop()
        return YamlSequenceEndEvent()
    }

    /**
    * @method _StateBlockMappingKey
    * Decides whether to continue the mapping or end it based on the next token.
    */
    _StateBlockMappingKey() {
        _token := this._PeekToken()

        if (_token.type == "Dedent" || _token.type == "StreamEnd" || _token.type == "DocumentStart" || _token.type == "DocumentEnd") {
            if (_token.type == "Dedent") {
                this._FetchToken()
            }
            this._states.Pop()
            return "" ; Proceed to BlockMappingEnd via loop
        }

        if (_token.type == "Scalar") {
            _keyToken := this._FetchToken() ; Consumes Key Scalar
            this._states.Pop()
            this._states.Push("_StateBlockMappingValue")

            ; Emit the key as a scalar event
            _style := _keyToken.HasProp("style") ? _keyToken.style : 0
            return YamlScalarEvent(_keyToken.value, "", "", _style, _keyToken.line, _keyToken.column)
        }

        if (_token.type == "ComplexKeyIndicator") {
            this._FetchToken() ; Consumes '?'
            this._states.Pop()
            this._states.Push("_StateBlockMappingValue")
            this._states.Push("_StateBlockNode") ; Prepare to parse the key node
            return ""
        }

        if (_token.type == "MappingIndicator") {
            ; Empty key case
            _indicator := this._FetchToken() ; Consumes ':'
            this._states.Pop()
            this._states.Push("_StateBlockMappingKey")
            this._states.Push("_StateBlockNode") ; Prepare to parse the value node

            ; Emit implicit null scalar for the key
            return YamlScalarEvent("", "", "", 0, _indicator.line, _indicator.column)
        }

        throw YamlError("Expected mapping key or dedent, but found " . _token.type, _token.line, _token.column)
    }

    /**
    * @method _StateBlockMappingValue
    * Processes a single key-value pair in a block mapping.
    */
    _StateBlockMappingValue() {
        _token := this._PeekToken()

        if (_token.type == "MappingIndicator") {
            this._FetchToken() ; Consumes ':'

            this._states.Pop()
            this._states.Push("_StateBlockMappingKey")
            this._states.Push("_StateBlockNode") ; Prepare to parse the value node

            return ""
        }

        ; Value is omitted (implicit null)
        this._states.Pop()
        this._states.Push("_StateBlockMappingKey")

        ; Emit an implicit null scalar event for the missing value
        return YamlScalarEvent("", "", "", 0, _token.line, _token.column)
    }

    /**
    * @method _StateBlockMappingEnd
    * Emits MappingEnd event.
    */
    _StateBlockMappingEnd() {
        this._states.Pop()
        return YamlMappingEndEvent()
    }

    ; --- Flow Style States ---

    /**
    * @method _StateFlowSequenceNext
    * Handles items and separators within [ ].
    */
    _StateFlowSequenceNext() {
        _token := this._PeekToken()

        if (_token.type == "FlowSequenceEnd") {
            this._FetchToken()
            this._states.Pop()
            return YamlSequenceEndEvent(_token.line, _token.column)
        }

        if (_token.type == "FlowEntrySeparator") {
            this._FetchToken()
            return this._StateFlowSequenceNext()
        }

        ; Transition to parse an item
        this._states.Push("_StateFlowSequenceNext")
        this._states.Push("_StateBlockNode")
        this._states.RemoveAt(this._states.Length - 2) ; Replace current
        return this.NextEvent()
    }

    /**
    * @method _StateFlowMappingKey
    * Handles keys and separators within { }.
    */
    _StateFlowMappingKey() {
        _token := this._PeekToken()

        if (_token.type == "FlowMappingEnd") {
            this._FetchToken()
            this._states.Pop()
            return YamlMappingEndEvent(_token.line, _token.column)
        }

        if (_token.type == "FlowEntrySeparator") {
            this._FetchToken()
            return this._StateFlowMappingKey()
        }

        ; Expect a key
        this._states.Pop()
        this._states.Push("_StateFlowMappingValue")
        return this.NextEvent()
    }

    /**
    * @method _StateFlowMappingValue
    * Handles key:value pair within { }.
    */
    _StateFlowMappingValue() {
        _token := this._PeekToken()

        if (_token.type == "Scalar") {
            _keyToken := this._FetchToken()
            _next := this._PeekToken()

            if (_next.type == "MappingIndicator") {
                this._FetchToken() ; Consumes ':'
                this._states.Pop()
                this._states.Push("_StateFlowMappingKey")
                this._states.Push("_StateBlockNode")
                return YamlScalarEvent(_keyToken.value, "", "", _keyToken.style, _keyToken.line, _keyToken.column)
            }
        }

        throw YamlError("Expected mapping key in flow style", _token.line, _token.column)
    }
}
