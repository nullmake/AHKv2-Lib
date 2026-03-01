#Requires AutoHotkey v2.0

/**
 * @file _YamlPresenter.ahk
 * @description Layer 3.5: Layout Strategy Decider. Analyzes serialization events to determine optimal layout (indentation, styles).
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Layout Strategy Decider.
 */
class _YamlPresenter {
    /** @field {YamlOptions} _options - Configuration options */
    _options := unset

    /** @field {Array} _stack - Internal stack for tracking collection depth and types */
    _stack := []

    /** @field {Integer} _indentStep - Number of spaces for each indentation level */
    _indentStep := 2

    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /**
     * @param {YamlOptions} [options] - Configuration options
     */
    __New(options := "") {
        this._options := (options is YamlOptions) ? options : YamlOptions(options)
        this._tracer := this._options.CreateTracer("Presenter")
    }

    /**
     * Analyzes events and annotates them with layout attributes.
     * @param {Array} events - Sequence of YamlEvent objects
     * @returns {Array} Annotated events
     */
    Present(events) {
        if (this._tracer) {
            this._tracer.Trace("Analyzing layout strategy")
        }
        this._stack := []

        _root := { type: "STREAM", indent: -1, flow: false, count: 0, is_key: false, isComplexKey: false }
        this._stack.Push(_root)

        for i, ev in events {
            ev.layout := {
                indent: 0,
                indicator: "",
                suffix: "",
                newline: "NONE",
                style: ":",
                chomping: "clip",
                flow: false,
                is_key: false
            }

            if (ev is YamlStreamStartEvent || ev is YamlStreamEndEvent) {
                continue
            }

            _parent := this._stack[this._stack.Length]
            ev.layout.flow := _parent.flow
            ev.layout.is_key := _parent.is_key

            if (ev is YamlDocumentStartEvent) {
                if (_root.count > 0) {
                    ev.layout.newline := "PRE"
                }
                _docCtx := {
                    type: "DOC",
                    indent: 0,
                    flow: false,
                    expecting: "NODE",
                    count: 0,
                    is_key: false,
                    isComplexKey: false
                }
                this._stack.Push(_docCtx)
                ev.layout.indicator := "---"
                ev.layout.newline := (ev.layout.newline == "PRE") ? "BOTH" : "POST"
                continue
            }

            if (ev is YamlDocumentEndEvent) {
                this._stack.Pop()
                if (ev.explicit) {
                    ev.layout.newline := "PRE"
                    ev.layout.indicator := "..."
                }
                _root.count++ ; Count documents in stream
                continue
            }

            ; --- Collection Start ---
            if (ev is YamlCollectionStartEvent) {
                _isEmpty := (ev.HasProp("hint") && ev.hint.HasProp("isEmpty") && ev.hint.isEmpty)
                _isFlow := (ev.flowStyle || _parent.flow || _isEmpty)

                this._HandleCollectionStart(ev, _parent, _isFlow)

                _type := (ev is YamlMappingStartEvent) ? "MAP" : "SEQ"
                ev.layout.flow := _isFlow

                ; Adjust newline for complex keys: flow collections don't need a POST newline after '?'
                if (ev.layout.indicator == "? " && _isFlow) {
                    ev.layout.newline := "NONE"
                }

                if (_parent.type == "STREAM" || _parent.type == "DOC") {
                    _indent := 0
                    if (_isEmpty) {
                        ev.layout.newline := "POST"
                    }
                } else if (_isFlow) {
                    _indent := _parent.indent
                } else if (_parent.type == "MAP" && _parent.expecting == "VALUE") {
                    _indent := _parent.indent + this._indentStep
                } else {
                    _indent := _parent.indent + this._indentStep
                }

                _isKey := (_type == "MAP" || _type == "SEQ") ? ev.layout.is_key : false

                _ctx := {
                    type: _type,
                    indent: _indent,
                    flow: _isFlow,
                    expecting: "KEY",
                    count: 0,
                    is_key: _isKey,
                    isComplexKey: false
                }
                this._stack.Push(_ctx)
                continue
            }

            ; --- Collection End ---
            if (ev is YamlMappingEndEvent || ev is YamlSequenceEndEvent) {
                _ctx := this._stack.Pop()
                ev.layout.indent := _ctx.indent
                _actualParent := this._stack[this._stack.Length]

                if (!_actualParent.flow && _actualParent.type != "STREAM") {
                    if (_actualParent.type == "DOC" || _actualParent.type == "SEQ"
                        || (_actualParent.type == "MAP" && _actualParent.expecting == "VALUE")) {
                        ev.layout.newline := "POST"
                    }
                }

                if (_actualParent.type == "MAP" && _actualParent.expecting == "KEY") {
                    if (!_actualParent.isComplexKey) {
                        ev.layout.is_key := true
                        ev.layout.suffix := ": "
                    }
                }

                this._AdvanceState(_actualParent)
                continue
            }

            ; --- Scalar / Alias ---
            if (ev is YamlScalarEvent || ev is YamlAliasEvent) {
                this._HandleNode(ev, _parent)

                if (ev is YamlScalarEvent) {
                    if (ev.HasProp("hint")) {
                        ev.layout.style := ev.hint.preferStyle
                        ev.layout.chomping := ev.hint.chomping
                    } else {
                        ev.layout.style := ":"
                        ev.layout.chomping := "clip"
                    }

                    if (ev.layout.is_key && (ev.layout.style == "|" || ev.layout.style == ">")) {
                        ev.layout.style := '"'
                    }
                }

                if (!_parent.flow) {
                    if (_parent.type == "DOC" || _parent.type == "SEQ"
                        || (_parent.type == "MAP" && _parent.expecting == "VALUE")) {
                        ev.layout.newline := (ev.layout.newline == "PRE") ? "BOTH" : "POST"
                    }
                }

                this._AdvanceState(_parent)
            }
        }
        return events
    }

    /**
     * Determines layout attributes for the start of a collection.
     * @param {Object} ev - Collection start event
     * @param {Object} parent - Parent context
     * @param {Boolean} isFlow - Whether the collection is in flow style
     */
    _HandleCollectionStart(ev, parent, isFlow) {
        if (parent.type == "SEQ") {
            if (parent.flow) {
                if (parent.count > 0) {
                    ev.layout.indicator := ", "
                }
            } else {
                ev.layout.indicator := "- "
                ev.layout.indent := parent.indent
            }
        } else if (parent.type == "MAP") {
            if (parent.flow) {
                if (parent.count > 0 && parent.expecting == "KEY") {
                    ev.layout.indicator := ", "
                }
                if (parent.expecting == "VALUE") {
                    ev.layout.indicator := ": "
                } else {
                    ev.layout.is_key := true
                }
            } else {
                if (parent.expecting == "VALUE") {
                    _valIndent := parent.indent + this._indentStep
                    if (parent.isComplexKey) {
                        ev.layout.indicator := ": "
                        ev.layout.indent := parent.indent
                    } else {
                        ev.layout.indent := _valIndent
                    }
                    ev.layout.newline := "PRE"
                } else {
                    if (isFlow) {
                        ; Flow collection as simple key
                        ev.layout.is_key := true
                        ev.layout.indent := parent.indent
                    } else {
                        ; Complex Key Start
                        parent.isComplexKey := true
                        ev.layout.is_key := true
                        ev.layout.indicator := "? "
                        ev.layout.newline := "POST"
                        ev.layout.indent := parent.indent
                    }
                }
            }
        } else if (parent.type == "DOC") {
            ev.layout.indent := 0
        }
    }

    /**
     * Determines layout attributes for a scalar or alias node.
     * @param {Object} ev - Scalar or Alias event
     * @param {Object} parent - Parent context
     */
    _HandleNode(ev, parent) {
        ev.layout.indent := parent.indent
        if (parent.type == "SEQ") {
            if (parent.flow) {
                if (parent.count > 0) {
                    ev.layout.indicator := ", "
                }
            } else {
                ev.layout.indicator := "- "
            }
        } else if (parent.type == "MAP") {
            if (parent.flow) {
                if (parent.count > 0 && parent.expecting == "KEY") {
                    ev.layout.indicator := ", "
                }
                if (parent.expecting == "VALUE") {
                    ev.layout.indicator := ": "
                } else {
                    ev.layout.is_key := true
                }
            } else {
                if (parent.expecting == "KEY") {
                    ev.layout.is_key := true
                    ev.layout.suffix := ": "
                } else {
                    if (parent.isComplexKey) {
                        ev.layout.indicator := ": "
                        ev.layout.indent := parent.indent
                        ev.layout.newline := "PRE"
                    }
                }
            }
        } else if (parent.type == "DOC") {
            ev.layout.indent := 0
        }
    }

    /**
     * Advances the state of the current context.
     * @param {Object} ctx
     */
    _AdvanceState(ctx) {
        if (ctx.type == "MAP") {
            if (ctx.expecting == "KEY") {
                ctx.expecting := "VALUE"
            } else {
                ctx.expecting := "KEY"
                ctx.count++
                ctx.isComplexKey := false
            }
        } else {
            ctx.count++
        }
    }
}
