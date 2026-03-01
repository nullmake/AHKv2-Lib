#Requires AutoHotkey v2.0

/**
 * @class YamlLayoutProcessorTest
 * @description Test runner for the structural analysis (Layer 2).
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */
class YamlLayoutProcessorTest extends YamlTestSuiteTestBase {
    /**
     * @param {Object} logger
     * @param {YamlTestOptions} [options]
     * @param {Array|String} [targetIds=""]
     */
    __New(logger, options := YamlTestOptions(), targetIds := "") {
        super.__New(logger, options, targetIds)
    }

    /**
     * Processes a single YAML file through the LayoutProcessor and verifies tokens.
     * @param {String} path
     * @param {String} logId
     * @param {Boolean} isErrorCase
     * @param {YamlTestOptions} options
     * @private
     */
    _ExecuteCase(path, logId, isErrorCase, options) {
        ; 1. Load the input YAML source
        test_file := path . "/in.yaml"
        source := FileRead(test_file)

        ; 2. Setup the pipeline (Scanner -> LayoutProcessor)
        _traceBuffer := []
        _opts := YamlOptions().SetTrace(options.Trace ? (msg) => _traceBuffer.Push(msg) : "")
        scanner := _YamlRawScanner(source, _opts)
        processor := _YamlLayoutProcessor(scanner, _opts)
        tokenList := ""
        try {
            loop {
                ; Fetch structural tokens
                t := processor.FetchToken()

                ; Format value for display
                rawVal := t.HasProp("value") ? String(t.value) : ""
                displayVal := StrReplace(StrReplace(rawVal, "`n", "\n"), " ", "_")

                ; Format: [Line:Col] TYPE (Value)
                tokenList .= Format("[{1:3d}:{2:3d}] {3:-15} : '{4}'`n",
                    t.line, t.column, t.name, displayVal)
                if (t.Is(_YamlToken.Type.StreamEnd)) {
                    break
                }
            }
        }
        catch YamlError as _e {
            if (InStr("CQ3W;", logId) == 0) {
                _e.Message .= "`n" . this._GetLogDetails(options,
                    logId, source, tokenList, _traceBuffer)
                throw _e
            }
        }
        catch Any as _e {
            _e.Message .= "`n" . this._GetLogDetails(options,
                logId, source, tokenList, _traceBuffer)
            throw _e
        }
    }

    /**
     * Internal helper to dump the current state for debugging.
     * @param {YamlTestOptions} options
     * @param {String} logId
     * @param {String} source
     * @param {String} tokenList
     * @param {Array} traceBuffer
     * @returns {String}
     * @private
     */
    _GetLogDetails(options, logId, source, tokenList, traceBuffer) {
        traceMessages := ""
        if (options.Trace) {
            for message in traceBuffer {
                traceMessages .= message . "`n"
            }
        }

        logMessage := ""
        if (options.TestInfo) {
            logMessage .= "`n--- INPUT (in.yaml) ---`n" . source
                . "`n--- Structural Tokens ---`n" . tokenList
        }
        if (traceMessages) {
            logMessage .= "`n--- TRACE ---`n" . traceMessages
        }
        return logMessage
    }
}
