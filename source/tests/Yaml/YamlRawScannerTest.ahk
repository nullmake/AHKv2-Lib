#Requires AutoHotkey v2.0

/**
 * @class RawScannerTest
 * @description Validates the lexical analysis layer (Layer 1).
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */
class RawScannerTest extends YamlTestSuiteTestBase {
    /**
     * @param {Object} logger
     * @param {YamlTestOptions} [options]
     * @param {Array|String} [targetIds=""]
     */
    __New(logger, options := YamlTestOptions(), targetIds := "") {
        super.__New(logger, options, targetIds)
    }

    /**
     * Executes a single test case for lexical scanning.
     * @param {String} path
     * @param {String} logId
     * @param {Boolean} isErrorCase
     * @param {YamlTestOptions} options
     * @private
     */
    _ExecuteCase(path, logId, isErrorCase, options) {
        ; Load test data
        test_file := path . "/in.yaml"
        source := FileRead(test_file)

        isErrorId := InStr("CQ3W;", logId) > 0

        _traceBuffer := []
        _opts := YamlOptions().SetTrace(options.Trace ? (msg) => _traceBuffer.Push(msg) : "")
        scanner := _YamlRawScanner(source, _opts)

        try {
            token := ""
            loop {
                t := scanner.Next()
                ; Format: [Line:Col] TYPE: "Value"
                val := StrReplace(StrReplace(t.value, "`n", "\n"), " ", "_")
                token .= Format("[{1:3d}:{2:3d}] {3:-20}: '{4}'`n", t.line, t.column, t.type, val)
            }
            until (t.Is(_YamlToken.Type.StreamEnd))
        } catch YamlError as _e {
            if (!isErrorId) {
                _e.Message .= "`n" . this._GetLogDetails(options,
                    logId, source, token, _traceBuffer)
                throw _e
            }
        }
    }

    /**
     * Internal helper to dump the current state for debugging.
     * @param {YamlTestOptions} options
     * @param {String} logId
     * @param {String} source
     * @param {String} token
     * @param {Array} traceBuffer
     * @returns {String}
     * @private
     */
    _GetLogDetails(options, logId, source, token, traceBuffer) {
        traceMessages := ""
        if (options.Trace) {
            for message in traceBuffer {
                traceMessages .= message . "`n"
            }
        }

        logMessage := ""
        if (options.TestInfo) {
            logMessage .= "`n--- INPUT (in.yaml) ---`n" . source
                . "`n--- Tokens ---`n" . token
        }
        if (traceMessages) {
            logMessage .= "`n--- TRACE ---`n" . traceMessages
        }
        return logMessage
    }
}
