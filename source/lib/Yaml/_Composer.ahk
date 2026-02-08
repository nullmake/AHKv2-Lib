#Requires AutoHotkey v2.0

/**
 * @file _Composer.ahk
 * @description Resolves anchors and builds node graphs.
 * @author nullmake
 * @license Apache-2.0
 *
 * Copyright 2026 nullmake
 */

/**
 * @class _YamlComposer
 * Builds a Node Graph from a stream of YAML events.
 */
class _YamlComposer {
    /**
    * @field {Object} _parser - YAML event source.
    */
    _parser := ""

    /**
    * @constructor
    * @param {Object} parser - An instance of _YamlParser.
    */
    __New(parser) {
        this._parser := parser
    }

    /**
    * @method Compose
    * Composes the entire document and returns the root node.
    * @returns {YamlNode}
    */
    Compose() {
        _event := this._parser.NextEvent() ; StreamStart
        if (!(_event is YamlStreamStartEvent)) {
            return ""
        }

        _event := this._parser.NextEvent()
        if (_event is YamlStreamEndEvent) {
            return ""
        }

        ; Assume single document for now
        if (_event is YamlDocumentStartEvent) {
            _node := this._ComposeNode()
            this._parser.NextEvent() ; DocumentEnd
            this._parser.NextEvent() ; StreamEnd
            return _node
        }

        return ""
    }

    /**
    * @method _ComposeNode
    * Recursively composes a single node from events.
    * @returns {YamlNode}
    */
    _ComposeNode() {
        _event := this._parser.NextEvent()

        if (_event is YamlScalarEvent) {
            return YamlScalarNode(_event.value, _event.tag, _event.anchor, _event.style)
        }

        if (_event is YamlMappingStartEvent) {
            _node := YamlMappingNode(_event.tag, _event.anchor)
            loop {
                ; Peek is not available for events yet, so we fetch and check
                _nextEvent := this._parser.NextEvent()
                if (_nextEvent is YamlMappingEndEvent) {
                    break
                }

                ; Mapping events: Key (Scalar) then Value (Recursive)
                _keyNode := YamlScalarNode(_nextEvent.value, _nextEvent.tag, _nextEvent.anchor, _nextEvent.style)
                _valueNode := this._ComposeNode()
                _node.Add(_keyNode, _valueNode)
            }
            return _node
        }

        if (_event is YamlSequenceStartEvent) {
            _node := YamlSequenceNode(_event.tag, _event.anchor)
            loop {
                _nextEvent := this._parser.NextEvent()
                if (_nextEvent is YamlSequenceEndEvent) {
                    break
                }

                ; For sequences, each event starts a new node
                _itemNode := this._ComposeNodeFromEvent(_nextEvent)
                _node.children.Push(_itemNode)
            }
            return _node
        }

        return ""
    }

    /**
    * @method _ComposeNodeFromEvent
    * Handles starting a node construction when the first event is already fetched.
    */
    _ComposeNodeFromEvent(_event) {
        if (_event is YamlScalarEvent) {
            return YamlScalarNode(_event.value, _event.tag, _event.anchor, _event.style)
        }

        if (_event is YamlMappingStartEvent || _event is YamlSequenceStartEvent) {
            ; If it's a collection start, we need to push it back or handle recursion.
            ; For simplicity, we re-inject the state or call _ComposeNode with a modified parser.
            ; But since our events are already hierarchical in the stream, we can just call _ComposeNode
            ; if we had a way to "unread" the event.
            ; Instead, let's make _ComposeNode accept an optional initial event.
            return this._ComposeNodeExtended(_event)
        }
        return ""
    }

    /**
    * @method _ComposeNodeExtended
    * Extended version of _ComposeNode that can start from a pre-fetched event.
    */
    _ComposeNodeExtended(_initialEvent) {
        _event := _initialEvent

        if (_event is YamlScalarEvent) {
            return YamlScalarNode(_event.value, _event.tag, _event.anchor, _event.style)
        }

        if (_event is YamlMappingStartEvent) {
            _node := YamlMappingNode(_event.tag, _event.anchor)
            loop {
                _nextEvent := this._parser.NextEvent()
                if (_nextEvent is YamlMappingEndEvent) {
                    break
                }
                _keyNode := YamlScalarNode(_nextEvent.value, _nextEvent.tag, _nextEvent.anchor, _nextEvent.style)
                _valueNode := this._ComposeNode()
                _node.Add(_keyNode, _valueNode)
            }
            return _node
        }

        if (_event is YamlSequenceStartEvent) {
            _node := YamlSequenceNode(_event.tag, _event.anchor)
            loop {
                _nextEvent := this._parser.NextEvent()
                if (_nextEvent is YamlSequenceEndEvent) {
                    break
                }
                _itemNode := this._ComposeNodeExtended(_nextEvent)
                _node.children.Push(_itemNode)
            }
            return _node
        }

        return ""
    }
}
