#Requires AutoHotkey v2.0

/**
 * @class YamlDumpTest
 * @description Validates the Dump layer by performing round-trip tests:
 *              Load(original) -> Dump(obj) -> Load(dumped) -> Compare Objects.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */
class YamlDumpTest extends YamlTestSuiteTestBase {
    /**
     * @param {Object} logger
     * @param {YamlTestOptions} [options]
     * @param {Array|String} [targetIds=""]
     */
    __New(logger, options := YamlTestOptions(), targetIds := "") {
        super.__New(logger, options, targetIds)
    }

    /**
     * Executes a single test case for round-trip validation.
     * @param {String} path - Path to the test case directory.
     * @param {String} logId - Case ID for logging.
     * @param {Boolean} isErrorCase - Whether the test case is expected to fail.
     * @param {YamlTestOptions} options - Test options.
     * @private
     */
    _ExecuteCase(path, logId, isErrorCase, options) {
        ; We only test round-trip for valid YAML cases.
        if (isErrorCase) {
            return
        }

        _dir := path
        _yamlOriginal := FileRead(_dir . "\in.yaml", "UTF-8")

        _traceBuffer := []
        _trace := (options && options.Trace) ? (msg) => (_traceBuffer.Length < 5000 ? _traceBuffer.Push(msg) : "") : (
            msg) => ""

        _objsOrig := ""
        _yamlDumped := ""
        _objsReloaded := ""
        _errorObj := ""

        try {
            ; 1. Load original YAML
            _phase := "Load Original"
            _traceBuffer := []
            _opts := YamlOptions().SetTrace(_trace)
            _objsOrig := Yaml.LoadAll(_yamlOriginal, _opts)

            ; 2. Dump to YAML string
            _phase := "Dump to YAML"
            _traceBuffer := ["** Phase: " . _phase . " **"]
            _yamlDumped := Yaml.DumpAll(_objsOrig, _opts)

            ; 3. Reload the dumped YAML
            _phase := "Reload Dumped"
            _traceBuffer.Push("** Phase: " . _phase . " **")
            _objsReloaded := Yaml.LoadAll(_yamlDumped, _opts)

            ; 4. Compare objects using JsonStringifier for canonical comparison
            _jsonOrig := ""
            for _o in _objsOrig {
                _js := JsonStringifier.Stringify(_o)
                _jsonOrig .= _js . "`n"
                _trace("Original JSON: " . _js)
            }

            _jsonReloaded := ""
            for _o in _objsReloaded {
                _jsonReloaded .= JsonStringifier.Stringify(_o) . "`n"
            }
        } catch Any as _e {
            _e.Message .= "`n" . this._GetLogDetails(logId, isErrorCase, _phase,
                _e.Message, _yamlOriginal, _yamlDumped, _jsonOrig ?? "N/A", _jsonReloaded ?? "N/A",
                _traceBuffer, _e)
            throw _e
        }

        if (_jsonOrig != _jsonReloaded) {
            _message := "Mismatch`n" . this._GetLogDetails(logId, isErrorCase, _phase,
                "Round-trip mismatch", _yamlOriginal, _yamlDumped, _jsonOrig, _jsonReloaded,
                _traceBuffer)
            throw Error(_message)
        }
    }

    /**
     * Overrides fail log to provide visibility for round-trip differences.
     * @param {String} logId
     * @param {Boolean} isErrorCase
     * @param {String} phase
     * @param {String} message
     * @param {String} yamlOriginal
     * @param {String} yamlDumped
     * @param {String} jsonOrig
     * @param {String} jsonReloaded
     * @param {Array} traceBuffer
     * @param {Any} [errorObj=""]
     * @returns {String}
     * @private
     */
    _GetLogDetails(logId, isErrorCase, phase, message, yamlOriginal, yamlDumped,
        jsonOrig, jsonReloaded, traceBuffer, errorObj := "") {
        logMessage :=
            "Testing Dump with ID: " . logId . (isErrorCase ? " (Error Case)" : "")
            . "`n[Phase] " . phase . ": " . message . "`n"
            . "`n`n--- ORIGINAL YAML(TEXT) ---`n" . String(yamlOriginal)
            . "`n--- ORIGINAL YAML(BIN) ---`n" . this._GetBinary(String(yamlOriginal))
            . "`n--- DUMPED YAML(TEXT) ---`n" . (IsObject(yamlDumped) ? "[Object]" : String(yamlDumped))
            . "`n--- DUMPED YAML(BIN) ---`n" . (IsObject(yamlDumped) ? "[Object]" : this._GetBinary(String(yamlDumped)))
            . "`n`n`--- ORIGINAL JSON (Expected) ---`n" . (IsObject(jsonOrig) ? "[Object]" : String(jsonOrig))
            . "`n`n--- RELOADED JSON (Actual) ---`n" . (IsObject(jsonReloaded) ? "[Object]" : String(jsonReloaded))
        if (IsObject(errorObj)) {
            logMessage .=
                "`n`n--- ERROR DETAILS ---"
                . "`nType: " . Type(errorObj)
                . "`nMessage: " . errorObj.Message
                . "`nStack:`n" . errorObj.Stack
        }
        traceMessages := ""
        for _msg in traceBuffer {
            traceMessages .= _msg . "`n"
        }
        logMessage .= "`n`n--- TRACE ---`n" . traceMessages

        return logMessage
    }
}
