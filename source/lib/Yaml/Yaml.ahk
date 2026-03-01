#Requires AutoHotkey v2.0

/**
 * @file Yaml.ahk
 * @description Main entry point for the YAML 1.2.2 library.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

#Include _YamlError.ahk
#Include _YamlToken.ahk
#Include _YamlTracer.ahk
#Include _YamlRawScanner.ahk
#Include LayoutProcessor/Contexts/_YamlContext.ahk
#Include LayoutProcessor/Contexts/_BlockContext.ahk
#Include LayoutProcessor/Contexts/_BlockScalarContext.ahk
#Include LayoutProcessor/Contexts/_FlowContext.ahk
#Include LayoutProcessor/Contexts/_NodePropsContext.ahk
#Include LayoutProcessor/Contexts/_StreamStartContext.ahk
#Include LayoutProcessor/_YamlBlockScalarBuilder.ahk
#Include LayoutProcessor/_YamlContextStack.ahk
#Include LayoutProcessor/_YamlIndentStack.ahk
#Include LayoutProcessor/_YamlTokenQueue.ahk
#Include LayoutProcessor/_YamlLayoutProcessorContext.ahk
#Include _YamlEvents.ahk
#Include _YamlLayoutProcessor.ahk
#Include Parser/States/_YamlParserStateBase.ahk
#Include Parser/States/_YamlParserNodeStateBase.ahk
#Include Parser/States/_ParseBlockMappingEndState.ahk
#Include Parser/States/_ParseBlockMappingKeyState.ahk
#Include Parser/States/_ParseBlockMappingState.ahk
#Include Parser/States/_ParseBlockMappingValueState.ahk
#Include Parser/States/_ParseBlockNodeState.ahk
#Include Parser/States/_ParseBlockScalarState.ahk
#Include Parser/States/_ParseBlockSequenceEntryState.ahk
#Include Parser/States/_ParseBlockSequenceState.ahk
#Include Parser/States/_ParseDocumentEndState.ahk
#Include Parser/States/_ParseDocumentStartState.ahk
#Include Parser/States/_ParseFlowImplicitMappingState.ahk
#Include Parser/States/_ParseFlowMappingEndState.ahk
#Include Parser/States/_ParseFlowMappingEntryState.ahk
#Include Parser/States/_ParseFlowMappingStartState.ahk
#Include Parser/States/_ParseFlowMappingValueState.ahk
#Include Parser/States/_ParseFlowNodeState.ahk
#Include Parser/States/_ParseFlowSequenceEndState.ahk
#Include Parser/States/_ParseFlowSequenceEntryState.ahk
#Include Parser/States/_ParseFlowSequenceStartState.ahk
#Include Parser/States/_ParsePlainScalarState.ahk
#Include Parser/States/_ParseStreamContentState.ahk
#Include Parser/States/_ParseStreamEndState.ahk
#Include Parser/States/_ParseStreamStartState.ahk
#Include Parser/_YamlParserStateStack.ahk
#Include Parser/_YamlParserContext.ahk
#Include _YamlParser.ahk
#Include _YamlNodes.ahk
#Include _YamlComposer.ahk
#Include _YamlConstructor.ahk
#Include _YamlRepresenter.ahk
#Include _YamlSerializer.ahk
#Include _YamlPresenter.ahk
#Include _YamlEmitter.ahk

/**
 * Represents a YAML null value.
 */
class YamlNull {
    /**
     * Returns string representation of null.
     * @returns {String}
     */
    ToString() => "null"
}

/**
 * Represents a YAML boolean true value.
 */
class YamlTrue {
    /**
     * Returns string representation of true.
     * @returns {String}
     */
    ToString() => "true"
}

/**
 * Represents a YAML boolean false value.
 */
class YamlFalse {
    /**
     * Returns string representation of false.
     * @returns {String}
     */
    ToString() => "false"
}

/**
 * Configuration options for YAML loading and dumping.
 */
class YamlOptions {
    _trace := ""

    /** @field {Object|String} Trace - Callback function for trace messages */
    Trace {
        get => this._trace
        set => this._trace := value
    }

    /**
     * Sets the trace callback function. (Fluent API)
     * @param {Object|String} callback
     * @returns {YamlOptions}
     */
    SetTrace(callback) {
        this._trace := callback
        return this
    }

    /**
     * Creates a scoped tracer instance if tracing is enabled.
     * @param {String} componentName
     * @returns {_YamlTracer|String} Tracer instance or empty string.
     */
    CreateTracer(componentName) {
        if (HasMethod(this._trace, "Call")) {
            return _YamlTracer(this._trace, componentName)
        }
        return ""
    }

    /**
     * @param {YamlOptions|Object} [initialOptions] - Initial values for options
     */
    __New(initialOptions := "") {
        if (IsObject(initialOptions)) {
            if (initialOptions is YamlOptions) {
                this._trace := initialOptions.Trace
            } else {
                for _prop, _val in initialOptions.OwnProps() {
                    try this.%_prop% := _val
                }
            }
        }
    }
}

/**
 * Provides high-level Load and Dump functions for YAML data.
 */
class Yaml {
    /** @field {YamlNull} Null - Singleton representing YAML null value */
    static Null := YamlNull()

    /** @field {YamlTrue} True - Singleton representing YAML boolean true */
    static True := YamlTrue()

    /** @field {YamlFalse} False - Singleton representing YAML boolean false */
    static False := YamlFalse()

    /**
     * Parses a YAML string and returns a native AutoHotkey v2 object.
     * @param {String} input - The YAML text to parse.
     * @param {YamlOptions|Object} [options] - Parsing options.
     * @returns {Any} - Map, Array, or Scalar values.
     */
    static Load(input, options := "") {
        _opts := (options is YamlOptions) ? options : YamlOptions(options)

        _scanner := _YamlRawScanner(input, _opts)
        _processor := _YamlLayoutProcessor(_scanner, _opts)
        _parser := _YamlParser(_processor, _opts)
        _composer := _YamlComposer(_parser)
        _constructor := _YamlConstructor()

        _rootNode := _composer.Compose()
        if (_rootNode == "") {
            return ""
        }

        return _constructor.Construct(_rootNode)
    }

    /**
     * Parses a YAML string and returns an Array of native AutoHotkey v2 objects.
     * @param {String} input - The YAML text to parse.
     * @param {YamlOptions|Object} [options] - Parsing options.
     * @returns {Array} - Array of Map, Array, or Scalar values.
     */
    static LoadAll(input, options := "") {
        _opts := (options is YamlOptions) ? options : YamlOptions(options)

        _scanner := _YamlRawScanner(input, _opts)
        _processor := _YamlLayoutProcessor(_scanner, _opts)
        _parser := _YamlParser(_processor, _opts)
        _composer := _YamlComposer(_parser)
        _constructor := _YamlConstructor()

        _results := []
        loop {
            _rootNode := _composer.Compose()
            if (_rootNode == "") {
                break
            }
            _results.Push(_constructor.Construct(_rootNode))
        }

        return _results
    }

    /**
     * Serializes an AutoHotkey v2 object into a YAML string.
     * @param {Any} obj - The object to serialize.
     * @param {YamlOptions|Object} [options] - Serialization options.
     * @returns {String} - The resulting YAML text.
     */
    static Dump(obj, options := "") {
        return this.DumpAll([obj], options)
    }

    /**
     * Serializes an array of AutoHotkey v2 objects into a YAML multi-document stream.
     * @param {Array} objs - The objects to serialize.
     * @param {YamlOptions|Object} [options] - Serialization options.
     * @returns {String} - The resulting YAML text.
     */
    static DumpAll(objs, options := "") {
        _opts := (options is YamlOptions) ? options : YamlOptions(options)

        _representer := _YamlRepresenter(_opts)
        _serializer := _YamlSerializer(_opts)
        _presenter := _YamlPresenter(_opts)
        _emitter := _YamlEmitter(_opts)

        _allEvents := []
        _allEvents.Push(YamlStreamStartEvent())

        for _o in objs {
            _rootNode := _representer.Represent(_o)
            _events := _serializer.Serialize(_rootNode)

            ; Merge document events, skipping StreamStart/End
            for _ev in _events {
                if (!(_ev is YamlStreamStartEvent) && !(_ev is YamlStreamEndEvent)) {
                    _allEvents.Push(_ev)
                }
            }
        }

        _allEvents.Push(YamlStreamEndEvent())

        ; Layout analysis for the entire stream at once
        _annotatedEvents := _presenter.Present(_allEvents)

        return _emitter.Emit(_annotatedEvents)
    }
}
