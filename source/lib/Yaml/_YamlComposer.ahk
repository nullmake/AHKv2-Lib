#Requires AutoHotkey v2.0

/**
 * @file _YamlComposer.ahk
 * @description Resolves anchors and builds node graphs from YAML events (Layer 4).
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Builds a Node Graph from a stream of YAML events.
 */
class _YamlComposer {
    /** @field {_YamlParser} _parser - YAML event source */
    _parser := ""

    /** @field {Map} _anchors - Registry of nodes by anchor name for the current document */
    _anchors := Map()

    /** @field {Boolean} _isStreamStarted - Whether StreamStart has been processed */
    _isStreamStarted := false

    /** @field {Boolean} _isStreamEnded - Whether StreamEnd has been processed */
    _isStreamEnded := false

    /**
     * @param {Object} parser - An instance of _YamlParser
     */
    __New(parser) {
        this._parser := parser
    }

    /**
     * Composes the next document in the stream.
     * @returns {YamlNode|String} The root node of the document, or empty string if no more documents.
     */
    Compose() {
        if (this._isStreamEnded) {
            return ""
        }

        if (!this._isStreamStarted) {
            _event := this._parser.NextEvent()
            if (!(_event is YamlStreamStartEvent)) {
                return ""
            }
            this._isStreamStarted := true
        }

        _event := this._parser.NextEvent()
        if (_event is YamlStreamEndEvent) {
            this._isStreamEnded := true
            return ""
        }

        if (_event is YamlDocumentStartEvent) {
            ; Anchors are restricted to the scope of a single document.
            this._anchors := Map()
            _node := this._ComposeNode()

            _endEvent := this._parser.NextEvent()
            if (!(_endEvent is YamlDocumentEndEvent)) {
                throw YamlError("Expected DocumentEndEvent", _endEvent.line, _endEvent.column)
            }
            return _node
        }

        return ""
    }

    /**
     * Recursively composes a single node.
     * @returns {YamlNode}
     */
    _ComposeNode() {
        _event := this._parser.NextEvent()
        if (_event == "") {
            throw YamlError("Unexpected end of event stream")
        }
        return this._ComposeNodeFromEvent(_event)
    }

    /**
     * Builds a node starting from a specific event.
     * @param {YamlEvent} _event - The initial event for the node
     * @returns {YamlNode}
     */
    _ComposeNodeFromEvent(_event) {
        if (_event is YamlAliasEvent) {
            if (!this._anchors.Has(_event.anchor)) {
                throw YamlError("Unresolved alias: " . _event.anchor, _event.line, _event.column)
            }
            return this._anchors[_event.anchor]
        }

        _node := ""
        if (_event is YamlScalarEvent) {
            _node := YamlScalarNode(_event.value, _event.tag, _event.anchor, _event.style)
        } else if (_event is YamlMappingStartEvent) {
            _node := YamlMappingNode(_event.tag, _event.anchor)
            ; Register anchor BEFORE composing children to support recursive structures.
            if (_event.anchor != "") {
                this._anchors[_event.anchor] := _node
            }
            loop {
                _nextEvent := this._parser.NextEvent()
                if (_nextEvent is YamlMappingEndEvent) {
                    break
                }
                _keyNode := this._ComposeNodeFromEvent(_nextEvent)
                _valueNode := this._ComposeNode()
                _node.Add(_keyNode, _valueNode)
            }
        } else if (_event is YamlSequenceStartEvent) {
            _node := YamlSequenceNode(_event.tag, _event.anchor)
            if (_event.anchor != "") {
                this._anchors[_event.anchor] := _node
            }
            loop {
                _nextEvent := this._parser.NextEvent()
                if (_nextEvent is YamlSequenceEndEvent) {
                    break
                }
                _itemNode := this._ComposeNodeFromEvent(_nextEvent)
                _node.children.Push(_itemNode)
            }
        }

        ; Register anchor for scalars (collections are registered above)
        if (_node is YamlScalarNode && _event.anchor != "") {
            this._anchors[_event.anchor] := _node
        }

        return _node
    }
}
