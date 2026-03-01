#Requires AutoHotkey v2.0

/**
 * @file _YamlSerializer.ahk
 * @description Layer 3: Converts node graphs to YAML event streams with rich hints.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Serializes a YAML node graph into an event stream.
 */
class _YamlSerializer {
    /** @field {Array} _events - Accumulated event stream */
    _events := []

    /** @field {Map} _anchors - Mapping of object pointers to anchor names */
    _anchors := Map()

    /** @field {Map} _visited - Tracking set for anchor detection */
    _visited := Map()

    /** @field {Map} _serialized - Tracking set for alias generation */
    _serialized := Map()

    /** @field {YamlOptions} _options - Configuration options */
    _options := unset

    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /**
     * @param {YamlOptions} [options] - Configuration options
     */
    __New(options := "") {
        this._options := (options is YamlOptions) ? options : YamlOptions(options)
        this._tracer := this._options.CreateTracer("Serializer")
    }

    /**
     * Serializes a node graph into a sequence of events.
     * @param {YamlNode} node - The root node
     * @returns {Array} Sequence of YamlEvent objects
     */
    Serialize(node) {
        this._events := []
        this._anchors := Map()
        this._visited := Map()
        this._serialized := Map()

        this._FindAnchors(node)

        this._EmitEvent(YamlStreamStartEvent())
        this._EmitEvent(YamlDocumentStartEvent(false))
        this._SerializeNode(node)
        this._EmitEvent(YamlDocumentEndEvent(false))
        this._EmitEvent(YamlStreamEndEvent())

        return this._events
    }

    /**
     * Appends an event to the stream.
     * @param {YamlEvent} ev
     */
    _EmitEvent(ev) {
        this._events.Push(ev)
    }

    /**
     * Recursively identifies nodes that need anchors.
     * @param {YamlNode} node
     */
    _FindAnchors(node) {
        if (!IsObject(node) || node is YamlScalarNode) {
            return
        }
        _ptr := ObjPtr(node)
        if (this._visited.Has(_ptr)) {
            if (!this._anchors.Has(_ptr)) {
                this._anchors[_ptr] := "id" . (this._anchors.Count + 1)
            }
            return
        }
        this._visited[_ptr] := true
        if (node is YamlMappingNode) {
            for _pair in node.children {
                this._FindAnchors(_pair.Key)
                this._FindAnchors(_pair.Value)
            }
        } else if (node is YamlSequenceNode) {
            for _child in node.children {
                this._FindAnchors(_child)
            }
        }
    }

    /**
     * Recursively serializes a node into events.
     * @param {YamlNode} node
     */
    _SerializeNode(node) {
        _ptr := IsObject(node) ? ObjPtr(node) : 0
        if (_ptr && this._serialized.Has(_ptr)) {
            this._EmitEvent(YamlAliasEvent(this._anchors[_ptr]))
            return
        }

        _anchor := ""
        if (_ptr && this._anchors.Has(_ptr)) {
            _anchor := this._anchors[_ptr]
        }

        if (_ptr && _anchor != "") {
            this._serialized[_ptr] := true
        }

        if (node is YamlScalarNode) {
            _hint := {
                isMultiline: node.isMultiline,
                chomping: node.chomping,
                preferStyle: node.style
            }
            this._EmitEvent(YamlScalarEvent(node.value, node.tag, _anchor, node.style, 0, 0, _hint))
        } else if (node is YamlMappingNode) {
            _hint := { isEmpty: node.children.Length == 0 }
            this._EmitEvent(YamlMappingStartEvent(node.tag, _anchor, false, 0, 0, _hint))
            for _pair in node.children {
                this._SerializeNode(_pair.Key)
                this._SerializeNode(_pair.Value)
            }
            this._EmitEvent(YamlMappingEndEvent())
        } else if (node is YamlSequenceNode) {
            _hint := { isEmpty: node.children.Length == 0 }
            this._EmitEvent(YamlSequenceStartEvent(node.tag, _anchor, false, 0, 0, _hint))
            for _child in node.children {
                this._SerializeNode(_child)
            }
            this._EmitEvent(YamlSequenceEndEvent())
        }
    }
}
