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
    * @field {Map} _anchors - Registry of nodes by anchor name.
    */
    _anchors := Map()

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
        return this._ComposeNodeFromEvent(_event)
    }

    /**
    * @method _ComposeNodeFromEvent
    * Builds a node starting from a pre-fetched event.
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
            loop {
                _nextEvent := this._parser.NextEvent()
                if (_nextEvent is YamlSequenceEndEvent) {
                    break
                }
                _itemNode := this._ComposeNodeFromEvent(_nextEvent)
                _node.children.Push(_itemNode)
            }
        }

        ; Register anchor if present
        if (_node != "" && _event.HasProp("anchor") && _event.anchor != "") {
            this._anchors[_event.anchor] := _node
        }

        return _node
    }
}
