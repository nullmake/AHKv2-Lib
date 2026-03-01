#Requires AutoHotkey v2.0

/**
 * @class YamlParserTest
 * @description Test runner for the syntactic analysis (Layer 3).
 *              Compares produced events with the expected event stream.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */
class YamlParserTest extends YamlTestSuiteTestBase {
    /**
     * @param {Object} logger
     * @param {YamlTestOptions} [options]
     * @param {Array|String} [targetIds=""]
     */
    __New(logger, options := YamlTestOptions(), targetIds := "") {
        super.__New(logger, options, targetIds)
    }

    /**
     * Processes a single YAML file through the Parser and collects events.
     * @param {String} path
     * @param {String} logId
     * @param {Boolean} isErrorCase
     * @param {YamlTestOptions} options
     * @private
     */
    _ExecuteCase(path, logId, isErrorCase, options) {
        ; 1. Load the input YAML source
        source := this._ReadTestFile(path . "/in.yaml")
        expected := StrReplace(this._ReadTestFile(path . "/test.event"), "`r`n", "`n")

        ; 2. Setup the pipeline (Scanner -> LayoutProcessor -> Parser)
        _traceBuffer := []
        _trace0 := options.Trace ? (msg) => _traceBuffer.Push(msg) : ""
        _trace := (options.Varbose) ? (msg) => (_trace0.Call(msg), OutputDebug(msg)) : _trace0
        _opts := YamlOptions().SetTrace(_trace)

        scanner := _YamlRawScanner(source, _opts)
        processor := _YamlLayoutProcessor(scanner, _opts)
        parser := _YamlParser(processor, _opts)

        actualEvents := []
        eventCount := 0
        try {
            loop {
                ; Test-level safety
                if (eventCount++ > 1000) {
                    throw Error("Infinite loop detected in Test Runner at ID: " . logId)
                }

                event := parser.NextEvent()
                actualEvents.Push(event)
                if (event is YamlStreamEndEvent) {
                    break
                }
            }
        } catch YamlError as _e {
            ; Expected error handling
            if (isErrorCase) {
                if (false) {
                    this._logger.Info("Success: ID " . logId
                        . " correctly threw an error as expected: " . _e.message)
                }
                return
            }
            ; Otherwise, log details and rethrow
            _e.Message .= "`n" . this._GetLogDetails(options,
                "Test Failed: [" . Type(_e) . "] " . _e.Message, logId, source, expected,
                this._CanonicalizeEvents(actualEvents), _traceBuffer, isErrorCase)
            throw _e
        } catch Any as _e {
            _e.Message .= "`n" . this._GetLogDetails(options,
                "Test Failed: [" . Type(_e) . "] " . _e.Message, logId, source, expected,
                this._CanonicalizeEvents(actualEvents), _traceBuffer, isErrorCase)
            throw _e
        }

        ; 3. Automated Comparison
        if (isErrorCase) {
            message := "Test Failed: Expected error was NOT thrown for ID: " . logId
            throw Error(this._GetLogDetails(options, message, logId, source, expected,
                this._CanonicalizeEvents(actualEvents), _traceBuffer, isErrorCase))
        }

        if (!expected) {
            this._logger.Info(logId . " test.event does not exist.")
        }
        else {
            actual := this._CanonicalizeEvents(actualEvents)
            if (actual != expected) {
                ; Value mismatch debug
                expLines := StrSplit(expected, "`n"), actLines := StrSplit(actual, "`n")
                diffInfo := ""
                loop Min(expLines.Length, actLines.Length) {
                    if (expLines[A_Index] != actLines[A_Index]) {
                        expHex := "", actHex := ""
                        loop parse expLines[A_Index]
                            expHex .= Format("[{:02X}]", Ord(A_LoopField))
                        loop parse actLines[A_Index]
                            actHex .= Format("[{:02X}]", Ord(A_LoopField))
                        diffInfo .= Format("Line {}:`n  EXP: {}`n  ACT: {}`n", A_Index, expHex, actHex)
                        break
                    }
                }

                message := "Test Failed: Event sequence mismatch.`n" . diffInfo
                throw Error(this._GetLogDetails(options, message, logId, source,
                    expected, actual, _traceBuffer, isErrorCase))
            }
        }
    }

    /**
     * Converts a sequence of events to canonical string format.
     * @param {Array} events
     * @returns {String}
     * @private
     */
    _CanonicalizeEvents(events) {
        text := ""
        for ev in events {
            line := EventCanonicalizer.Canonicalize(ev)
            if (line != "") {
                text .= line . "`n"
            }
        }
        return StrReplace(text, "`r`n", "`n")
    }

    /**
     * Internal helper to dump the current state for debugging.
     * @param {YamlTestOptions} options
     * @param {String} message
     * @param {String} logId
     * @param {String} source
     * @param {String} expected
     * @param {String} actual
     * @param {Array} traceBuffer
     * @param {Boolean} isErrorCase
     * @returns {String}
     * @private
     */
    _GetLogDetails(options, message, logId, source, expected, actual,
        traceBuffer, isErrorCase) {
        traceMessages := ""
        if (options.Trace) {
            for tMsg in traceBuffer {
                traceMessages .= tMsg . "`n"
            }
        }

        logMessage :=
            "Testing Parser with ID: " . logId . (isErrorCase ? " (Error Case)" : "")
            . "`n" . message . "`n"
        if (options.TestInfo) {
            logMessage .= "`n--- INPUT(Text) (in.yaml) ---`n" . source
                . "`n--- INPUT(BIN) (in.yaml) ---`n" . this._GetBinary(source)
                . "`n--- EXPECTED (test.event) ---`n" . expected
                . "`n--- ACTUAL (Produced) ---`n" . actual
        }
        if (traceMessages) {
            logMessage .= "`n--- TRACE ---`n" . traceMessages
        }
        return logMessage
    }
}
