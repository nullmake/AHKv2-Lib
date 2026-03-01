#Requires AutoHotkey v2.0

#Include ../vendor/JSON.ahk

/**
 * @class YamlConstructorTest
 * @description Validates the Constructor layer by comparing constructed AHK objects with in.json.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */
class YamlConstructorTest extends YamlTestSuiteTestBase {
    /**
     * @param {Object} logger
     * @param {YamlTestOptions} [options]
     * @param {Array|String} [targetIds=""]
     */
    __New(logger, options := YamlTestOptions(), targetIds := "") {
        super.__New(logger, options, targetIds)
        ; Configure cJson to return objects for true/false/null
        JSON.BoolsAsInts := false
        JSON.NullsAsStrings := false
    }

    /**
     * Executes a single test case for object construction.
     * @param {String} path
     * @param {String} logId
     * @param {Boolean} isErrorCase
     * @param {YamlTestOptions} options
     * @private
     */
    _ExecuteCase(path, logId, isErrorCase, options) {
        _dir := path
        _yaml := FileRead(_dir . "\in.yaml", "UTF-8")
        _expectedJsonFile := _dir . "\in.json"

        if (!FileExist(_expectedJsonFile)) {
            return
        }

        _expectedJsonRaw := FileRead(_expectedJsonFile, "UTF-8")
        _expectError := isErrorCase

        _traceBuffer := []
        _trace := (options && options.Trace) ? (msg) => (_traceBuffer.Length < 5000 ? _traceBuffer.Push(msg) : "") : (
            msg) => ""
        _actualJson := ""
        _errorOccurred := false
        _errorObj := ""

        try {
            ; 1. Load actual objects from in.yaml
            _objs := Yaml.LoadAll(_yaml, YamlOptions().SetTrace(_trace))

            _actualJson := ""
            for _o in _objs {
                _actualJson .= JsonStringifier.Stringify(_o) . "`n"
            }
            _actualJson := RTrim(_actualJson, "`n")
        } catch Any as _e {
            _errorOccurred := true
            _errorObj := _e
            _trace("ERROR [" . Type(_e) . "]: " . _e.Message . "`n" . _e.Stack)
        }

        ; 2. Generate expected normalized JSON
        _expectedJson := ""
        if (!_errorOccurred) {
            ; Handle multiple documents in in.json
            if (IsSet(_objs) && _objs.Length > 1) {
                _expectedJson := ""
                _lines := StrSplit(_expectedJsonRaw, "`n", "`r")
                _currentBuffer := ""
                for _line in _lines {
                    if (Trim(_line) == "") {
                        continue
                    }
                    _currentBuffer .= (_currentBuffer == "" ? "" : "`n") . _line
                    try {
                        _objExp := JSON.Load(_currentBuffer)
                        _expectedJson .= JsonStringifier.Stringify(_objExp) . "`n"
                        _currentBuffer := "" ; Reset buffer on success
                    } catch {
                        continue
                    }
                }
                _expectedJson := RTrim(_expectedJson, "`n")
            } else {
                ; Single document
                try {
                    _objExp := JSON.Load(_expectedJsonRaw)
                    _expectedJson := JsonStringifier.Stringify(_objExp)
                } catch Any {
                    _expectedJson := this._MinifyJson(_expectedJsonRaw)
                }
            }
        }

        if (_expectError) {
            if (!_errorOccurred) {
                this._WriteFailLog(logId, _yaml, _expectedJson, _expectError, _actualJson, _traceBuffer,
                    "Expected error but none occurred")
                throw Error("Expected error missing")
            }
            return
        }

        if (_errorOccurred) {
            this._WriteFailLog(logId, _yaml, _expectedJson, _expectError, _actualJson, _traceBuffer, _errorObj)
            throw Error("Unexpected error [" . Type(_errorObj) . "]: " . _errorObj.Message)
        }

        if (_actualJson != _expectedJson) {
            this._WriteFailLog(logId, _yaml, _expectedJson, _expectError, _actualJson, _traceBuffer,
                "JSON mismatch (from in.yaml)")
            throw Error("Mismatch")
        }

        ; --- PASS 2: JSON Compatibility ---
        if (!_expectError) {
            try {
                _yamlInputFromJson := ""
                if (_objs.Length > 1) {
                    _lines := StrSplit(_expectedJsonRaw, "`n", "`r")
                    _currentBuffer := ""
                    for _line in _lines {
                        if (Trim(_line) == "") {
                            continue
                        }
                        _currentBuffer .= (_currentBuffer == "" ? "" : "`n") . _line
                        try {
                            JSON.Load(_currentBuffer)
                            _yamlInputFromJson .= "--- " . _currentBuffer . "`n"
                            _currentBuffer := ""
                        } catch {
                            continue
                        }
                    }
                } else {
                    _yamlInputFromJson := _expectedJsonRaw
                }

                _objsFromJson := Yaml.LoadAll(_yamlInputFromJson)
                _actualJsonFromJson := ""
                for _o in _objsFromJson {
                    _actualJsonFromJson .= JsonStringifier.Stringify(_o) . "`n"
                }
                _actualJsonFromJson := RTrim(_actualJsonFromJson, "`n")

                if (_actualJsonFromJson != _expectedJson) {
                    this._WriteFailLog(logId, _expectedJsonRaw, _expectedJson, _expectError, _actualJsonFromJson,
                        _traceBuffer, "JSON mismatch (from in.json)")
                    throw Error("Mismatch using in.json as input")
                }
            } catch Any as _e {
                this._WriteFailLog(logId, _expectedJsonRaw, _expectedJson, _expectError, "", _traceBuffer,
                    "Error parsing in.json: " . _e.Message)
                throw _e
            }
        }
    }

    /**
     * Minifies a JSON string by removing whitespace outside of quotes.
     * @param {String} json
     * @returns {String}
     * @private
     */
    _MinifyJson(json) {
        _minified := ""
        _inQuote := false
        _escaped := false
        loop parse json {
            _char := A_LoopField
            if (_char == "`"" && !_escaped) {
                _inQuote := !_inQuote
            }
            if (_char == "\") {
                _escaped := !_escaped
            } else {
                _escaped := false
            }
            if (_inQuote || (_char != " " && _char != "`t" && _char != "`n" && _char != "`r")) {
                _minified .= _char
            }
        }
        return _minified
    }

    /**
     * Writes detailed failure information to a log file.
     * @param {String} logId
     * @param {String} input
     * @param {String} expected
     * @param {Boolean} expectError
     * @param {String} actual
     * @param {Array} traceBuffer
     * @param {Any} [errorDetail=""]
     * @private
     */
    _WriteFailLog(logId, input, expected, expectError, actual, traceBuffer, errorDetail := "") {
        _logDir := A_ScriptDir . "\logs"
        if (!DirExist(_logDir)) {
            DirCreate(_logDir)
        }
        _logPath := _logDir . "\fail_constructor_" . logId . ".log"
        _file := FileOpen(_logPath, "w", "UTF-8")
        _file.Write("--- INPUT ---`n" . input . "`n`n")
        _file.Write("--- EXPECTED JSON ---`n" . expected . "`n`n")
        _file.Write("--- EXPECTED ERROR ---`n" . (expectError ? "Yes" : "No") . "`n`n")
        _file.Write("--- ACTUAL JSON ---`n" . actual . "`n`n")
        if (IsObject(errorDetail)) {
            _file.Write("--- ERROR DETAILS ---`n")
            _file.Write("Type: " . Type(errorDetail) . "`n")
            _file.Write("Message: " . errorDetail.Message . "`n")
            _file.Write("Stack:`n" . errorDetail.Stack . "`n`n")
        } else if (errorDetail != "") {
            _file.Write("--- ERROR ---`n" . errorDetail . "`n`n")
        }
        _file.Write("--- TRACE ---`n")
        for _msg in traceBuffer {
            _file.Write(_msg . "`n")
        }
        _file.Close()
    }
}
