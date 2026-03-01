#Requires AutoHotkey v2.0

/**
 * @file _ParseDocumentStartState.ahk
 * @description Represents the state of parsing the start of a YAML document.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Represents the state of parsing the start of a YAML document.
 */
class _ParseDocumentStartState extends _YamlParserStateBase {
    /** @field {Boolean} _hasParsedDoc - Whether at least one document has been parsed in the stream */
    _hasParsedDoc := false

    /**
     * @param {Boolean} [hasParsedDoc=false]
     */
    __New(hasParsedDoc := false) {
        super.__New("_ParseDocumentStart")
        this._hasParsedDoc := hasParsedDoc
    }

    /**
     * @inheritdoc
     */
    DeepClone() {
        return _ParseDocumentStartState(this._hasParsedDoc)
    }

    /**
     * @inheritdoc
     */
    Handle(ctx) {
        ; 1. Explicitly allow directives while searching for the next document start.
        ctx.Processor.SetDirectivesAllowed(true)
        ctx.Processor.ContextIndentOverride := -1
        ctx.ResetTags() ; Reset custom tags for each document
        hasYamlDirective := false
        hasAnyDirective := false

        loop {
            state_lk := ctx.Processor.CaptureState()
            t := ctx.Processor.FetchToken()

            ; Skip noise tokens and directives, keeping directive scanning ENABLED.
            if (t.IsAnyOf(_YamlToken.Type.Newline, _YamlToken.Type.Indent, _YamlToken.Type.Dedent,
                _YamlToken.Type.Directive)) {
                if (t.Is(_YamlToken.Type.Directive)) {
                    hasAnyDirective := true
                    if (RegExMatch(t.value, "i)^YAML\s+(.*)$", &match)) {
                        if (hasYamlDirective) {
                            throw YamlError("Found multiple %YAML directives", t.line, t.column)
                        }
                        val := Trim(match[1])
                        if (!(val ~= "^\d+\.\d+$")) {
                            throw YamlError("Invalid %YAML directive version format", t.line, t.column)
                        }
                        hasYamlDirective := true
                    }
                    else if (RegExMatch(t.value, "i)^TAG\s+(.*)$", &match)) {
                        val := Trim(match[1])
                        if (!RegExMatch(val, "^(!\S*)\s+(\S+)$", &tagMatch)) {
                            throw YamlError("Invalid %TAG directive format", t.line, t.column)
                        }
                        ctx.RegisterTagHandle(tagMatch[1], tagMatch[2])
                    }
                    else {
                        ; Unknown directive - should probably be allowed but ignored in YAML 1.2,
                        ; but let's be strict for now or at least ensure format is somewhat sane.
                    }
                }
                continue
            }

            ; 2. Once DocStart or any content is found, directives are no longer allowed in this document.
            ctx.Processor.SetDirectivesAllowed(false)

            if (t.Is(_YamlToken.Type.StreamEnd)) {
                if (hasAnyDirective) {
                    throw YamlError("Missing document content after directive", t.line, t.column)
                }
                ctx.States.Pop()
                return ""
            }

            if (t.Is(_YamlToken.Type.DocEnd)) {
                if (hasAnyDirective) {
                    throw YamlError("Missing document content between directive and '...'", t.line, t.column)
                }
                ctx.States.Pop()
                return ""
            }

            if (t.Is(_YamlToken.Type.DocStart)) {
                ctx.States.Pop()
                ctx.States.Push(_ParseDocumentEndState())
                ctx.States.Push(_ParseBlockNodeState("", "", t.line))
                ctx.CurrentDocStartedWithMarker := true
                return YamlDocumentStartEvent(true, t.line, t.column)
            }

            ; Implicit start: Only if actual content exists.
            if (t.IsScalar || t.IsAnyOf(_YamlToken.Type.Anchor, _YamlToken.Type.Tag,
                _YamlToken.Type.Punctuator, _YamlToken.Type.BlockEntry, _YamlToken.Type.Text,
                _YamlToken.Type.KeyIndicator, _YamlToken.Type.ValueIndicator)) {
                if (this._hasParsedDoc && !ctx.LastDocEndedWithMarker) {
                    throw YamlError("Subsequent documents must be explicit (start with '---')", t.line, t.column)
                }
                ctx.Processor.RestoreState(state_lk)
                ctx.States.Pop()
                ctx.States.Push(_ParseDocumentEndState())
                ctx.States.Push(_ParseBlockNodeState())
                ctx.CurrentDocStartedWithMarker := false
                return YamlDocumentStartEvent(false, t.line, t.column)
            }

            ; If nothing matches, this document start is invalid or empty
            ctx.States.Pop()
            return ""
        }
    }
}
