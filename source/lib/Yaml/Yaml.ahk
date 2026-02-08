#Requires AutoHotkey v2.0

/**
 * @file Yaml.ahk
 * @description Main entry point for the YAML 1.2.2 library.
 * @author nullmake
 * @license Apache-2.0
 *
 * Copyright 2026 nullmake
 */

#Include _Scanner.ahk
#Include _Parser.ahk
#Include _Composer.ahk
#Include _Constructor.ahk
#Include _Representer.ahk
#Include _Serializer.ahk
#Include _Presenter.ahk
#Include _Events.ahk
#Include _Nodes.ahk
#Include _Errors.ahk

/**
 * @class Yaml
 * Provides high-level Load and Dump functions for YAML data.
 */
class Yaml {
    /**
    * @method Load
    * Parses a YAML string and returns an AHK v2 object.
    * @param {String} input - The YAML text to parse.
    * @returns {Any} - Map, Array, or Scalar values.
    */
    static Load(input) {
        _scanner := _YamlScanner(input)
        _parser := _YamlParser(_scanner)
        _composer := _YamlComposer(_parser)

        _rootNode := _composer.Compose()
        if (_rootNode == "") {
            return ""
        }

        _constructor := _YamlConstructor()
        return _constructor.Construct(_rootNode)
    }

    /**
    * @method Dump
    * Serializes an AHK v2 object into a YAML string.
    * @param {Any} obj - The object to serialize.
    * @returns {String} - The resulting YAML text.
    */
    static Dump(obj) {
        ; TODO: Implement Dump pipeline
        return ""
    }
}
