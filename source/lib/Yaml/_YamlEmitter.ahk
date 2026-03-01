#Requires AutoHotkey v2.0

/**
 * @file _YamlEmitter.ahk
 * @description Layer 2: Advanced YAML Emitter using a Semantic Writer.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Outputs text based on rich Layout Attributes and hints.
 */
class _YamlEmitter {
    /** @field {Object} _writer - The internal semantic writer */
    _writer := unset

    /** @field {YamlOptions} _options - Configuration options */
    _options := unset

    /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
    _tracer := ""

    /**
     * @param {YamlOptions} [options] - Configuration options
     */
    __New(options := "") {
        this._options := (options is YamlOptions) ? options : YamlOptions(options)
        this._tracer := this._options.CreateTracer("Emitter")
    }

    /**
     * Internal semantic writer for managing columns and line starts.
     */
    class Writer {
        /** @field {String} output - Accumulated output string */
        output := ""

        /** @field {Integer} column - Current column position */
        column := 0

        /** @field {Boolean} isAtLineStart - Whether the next write is at the start of a line */
        isAtLineStart := true

        /** @field {YamlOptions} _options - Configuration options */
        _options := unset

        /** @field {_YamlTracer|String} _tracer - Scoped tracer instance */
        _tracer := ""

        /**
         * @param {YamlOptions} [options] - Configuration options
         */
        __New(options := "") {
            this._options := (options is YamlOptions) ? options : YamlOptions(options)
            this._tracer := this._options.CreateTracer("Writer")
        }

        /**
         * Writes text to the output.
         * @param {String} text
         */
        Write(text) {
            if (this._tracer) {
                this._tracer.Trace("Writing: '" . StrReplace(text, "`n", "\n") . "'")
            }
            this.output .= text
            lastNL := InStr(text, "`n", , -1)
            if (lastNL) {
                this.column := StrLen(text) - lastNL
                if (this.column == 0) {
                    this.isAtLineStart := true
                } else {
                    this.isAtLineStart := false
                }
            } else {
                this.column += StrLen(text)
                this.isAtLineStart := false
            }
        }

        /**
         * Writes indentation spaces.
         * @param {Integer} level
         */
        WriteIndent(level) {
            if (!this.isAtLineStart) {
                return
            }
            if (level <= 0) {
                return
            }
            if (this._tracer) {
                this._tracer.Trace("Writing Indent: " . level)
            }
            loop level {
                this.output .= " "
            }
            this.column += level
            this.isAtLineStart := false
        }

        /**
         * Finalizes the current line.
         */
        Newline() {
            if (!this.isAtLineStart) {
                if (this._tracer) {
                    this._tracer.Trace("Writing Newline")
                }
                this.output .= "`n"
                this.column := 0
                this.isAtLineStart := true
            }
        }
    }

    /**
     * Emits YAML text from a sequence of events.
     * @param {Array} events - Sequence of YamlEvent objects
     * @returns {String}
     */
    Emit(events) {
        if (this._tracer) {
            this._tracer.Trace("Emitting events")
        }
        this._writer := _YamlEmitter.Writer(this._options)

        for ev in events {
            if (ev is YamlStreamStartEvent || ev is YamlStreamEndEvent) {
                continue
            }

            layout := ev.layout

            if (layout.newline == "PRE" || layout.newline == "BOTH") {
                this._writer.Newline()
            }

            ; 1. Indent & Indicator
            _hasContent := (layout.indicator != "" || (ev.HasProp("tag") && ev.tag != "")
            || (ev.HasProp("anchor") && ev.anchor != "") || (ev is YamlScalarEvent)
            || (ev is YamlAliasEvent) || (ev is YamlCollectionStartEvent && layout.flow)
            || (ev is YamlMappingEndEvent && layout.flow) || (ev is YamlSequenceEndEvent && layout.flow))

            if (this._writer.isAtLineStart && _hasContent) {
                this._writer.WriteIndent(layout.indent)
            }

            if (layout.indicator != "") {
                this._writer.Write(layout.indicator)
            }

            ; 2. Tag & Anchor
            _props := ""
            if (ev.HasProp("tag") && ev.tag != "") {
                _fTag := this._FormatTag(ev.tag)
                if (_fTag != "") {
                    _props .= _fTag . " "
                }
            }
            if (ev.HasProp("anchor") && ev.anchor != "" && !(ev is YamlAliasEvent)) {
                _props .= "&" . ev.anchor . " "
            }

            if (_props != "") {
                if (ev is YamlCollectionStartEvent && !layout.flow) {
                    this._writer.Write(RTrim(_props))
                    this._writer.Newline()
                } else {
                    this._writer.Write(_props)
                }
            }

            ; 3. Content
            if (ev is YamlScalarEvent) {
                this._EmitScalar(ev.value, layout.style, layout.indent, layout.chomping)
            } else if (ev is YamlAliasEvent) {
                this._writer.Write("*" . ev.anchor)
            } else if (ev is YamlCollectionStartEvent) {
                if (layout.flow) {
                    this._writer.Write((ev is YamlMappingStartEvent) ? "{" : "[")
                }
            } else if (ev is YamlMappingEndEvent || ev is YamlSequenceEndEvent) {
                if (layout.flow) {
                    if (ev is YamlMappingEndEvent) {
                        this._writer.Write("}")
                    } else {
                        this._writer.Write("]")
                    }
                }
            }

            ; 4. Suffix (e.g. ": ")
            if (layout.suffix != "") {
                this._writer.Write(layout.suffix)
            }

            if (layout.newline == "POST" || layout.newline == "BOTH") {
                this._writer.Newline()
            }
        }

        return RTrim(this._writer.output, "`n ") . "`n"
    }

    /**
     * Emits a scalar value with appropriate styling.
     * @param {String} val
     * @param {String} style
     * @param {Integer} indent
     * @param {String} chomping
     */
    _EmitScalar(val, style, indent, chomping) {
        if (style == "|" || style == ">") {
            this._EmitBlockScalar(val, style, indent, chomping)
        } else if (style == '"') {
            this._EmitDoubleQuoted(val)
        } else if (style == "'") {
            this._EmitSingleQuoted(val)
        } else {
            this._writer.Write(val)
        }
    }

    /**
     * Emits a double-quoted scalar.
     * @param {String} val
     */
    _EmitDoubleQuoted(val) {
        _s := val
        _s := StrReplace(_s, "\", "\\")
        _s := StrReplace(_s, "`"", "\`"")
        _s := StrReplace(_s, "`n", "\n")
        _s := StrReplace(_s, "`r", "\r")
        _s := StrReplace(_s, "`t", "\t")
        this._writer.Write("`"" . _s . "`"")
    }

    /**
     * Emits a single-quoted scalar.
     * @param {String} val
     */
    _EmitSingleQuoted(val) {
        _s := StrReplace(val, "'", "''")
        this._writer.Write("'" . _s . "'")
    }

    /**
     * Emits a block scalar (Literal or Folded).
     * @param {String} val
     * @param {String} style
     * @param {Integer} indent
     * @param {String} chomping
     */
    _EmitBlockScalar(val, style, indent, chomping) {
        indicator := style
        if (chomping == "strip") {
            indicator .= "-"
        } else if (chomping == "keep") {
            indicator .= "+"
        }

        this._writer.Write(indicator . "`n")

        _contentIndent := indent + 2

        ; Remove trailing newlines for processing the lines themselves
        content := RTrim(val, "`n`r")

        if (content != "") {
            for _line in StrSplit(content, "`n", "`r") {
                this._writer.WriteIndent(_contentIndent)
                this._writer.Write(_line)
                this._writer.Newline()
            }
        }

        ; Handle trailing newlines based on chomping
        if (chomping == "keep") {
            RegExMatch(val, "(`n|`r`n)+$", &match)
            if (match) {
                loop StrLen(match[0]) {
                    this._writer.WriteIndent(_contentIndent)
                    this._writer.Newline()
                }
            }
        } else if (chomping == "strip") {
            ; Already handled by RTrim and no final Newline
        } else { ; clip
            if (content != "") {
                ; Already has one newline from the loop
            } else {
                ; Completely empty scalar with clip? Still gets one newline after indicator
            }
        }
    }

    /**
     * Formats a tag for emission.
     * @param {String} tag
     * @returns {String}
     */
    _FormatTag(tag) {
        if (tag == "tag:yaml.org,2002:str" || tag == "tag:yaml.org,2002:int"
            || tag == "tag:yaml.org,2002:float" || tag == "tag:yaml.org,2002:bool"
            || tag == "tag:yaml.org,2002:null" || tag == "tag:yaml.org,2002:map"
            || tag == "tag:yaml.org,2002:seq") {
            ; Core tags are usually omitted in dumping unless specific style requires it.
            return ""
        }
        if (SubStr(tag, 1, 1) == "!") {
            return tag
        }
        return "!<" . tag . ">"
    }
}
