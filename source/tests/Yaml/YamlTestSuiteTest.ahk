#Requires AutoHotkey v2.0

/**
 * @class YamlTestSuiteTest
 * Integration tests using the official YAML Test Suite.
 */
class YamlTestSuiteTest {
    /** @field {String} _baseDir - Root directory of the test suite */
    _baseDir := A_ScriptDir . "/data/yaml-test-suite"

    /** @field {Object} _log - Logger instance */
    _log := ""

    /** @field {Integer} _caseTimeoutMS - Max time allowed per test case */
    _caseTimeoutMS := 2000

    /** @field {Integer} _maxConsecutiveTimeouts - Stop suite after this many timeouts */
    _maxConsecutiveTimeouts := 5

    /**
    * @constructor
    * @param {Object} logSvc - Logger instance for reporting.
    */
    __New(logSvc) {
        this._log := logSvc
    }

    /**
    * @method Test_AllSuiteCases
    * Automatically discovers and runs all test cases in the official suite.
    */
    Test_AllSuiteCases() {
        _passCount := 0
        _failCount := 0
        _total := 0
        _timeoutCount := 0
        _failedCases := []
        _log := this._log

        ; Iterate through each directory in the test suite
        Loop Files, this._baseDir . "/*", "D" {
            _id := A_LoopFileName

            ; Skip non-test directories
            if (_id ~= "^(\.git|name|tags)$") {
                continue
            }

            _total++

            ; Log every 50 cases to keep console alive/visible
            if (_log && Mod(_total, 50) == 0) {
                _log.Info("    Progress: " . _total . " cases processed...")
            }

            try {
                this._RunCase(_id, this._caseTimeoutMS)
                _passCount++
                _timeoutCount := 0 ; Reset consecutive timeouts on any success
            } catch Any as _e {
                _failCount++
                _failedCases.Push(_id . ": " . _e.Message)

                ; Check for consecutive timeouts
                if (InStr(_e.Message, "Watchdog")) {
                    _timeoutCount++
                    if (_timeoutCount >= this._maxConsecutiveTimeouts) {
                        _msg := Format("YAML Test Suite aborted after {1} consecutive timeouts. Last ID: {2}", _timeoutCount, _id)
                        _log.Error(_msg)
                        throw Error(_msg)
                    }
                } else {
                    _timeoutCount := 0 ; Mismatches or parse errors don't count as timeouts
                }
            }
        }

        if (_log) {
            _log.Info(Format("  YAML Test Suite (Full): Total {1}, Pass {2}, Fail {3}", _total, _passCount, _failCount))
            if (_failedCases.Length > 0) {
                _log.Warn("  Failed Test Cases Summary written to log file.")
                for _msg in _failedCases {
                    _log.Warn("    - " . _msg)
                }
            }
        }

        if (_failCount > 0) {
            throw Error("YAML Test Suite failed with " . _failCount . " errors.")
        }
    }

    /**
    * @method _RunCase
    * Executes a single test case from the official suite.
    * @param {String} id - Directory name of the test case.
    * @param {Integer} timeoutMS - Time limit in milliseconds.
    */
    _RunCase(id, timeoutMS := 2000) {
        _dir := this._baseDir . "/" . id
        _yamlPath := _dir . "/in.yaml"
        _eventPath := _dir . "/test.event"

        ; Check if required files exist
        if (!FileExist(_yamlPath) || !FileExist(_eventPath)) {
            return
        }

        ; 1. Load input YAML
        _input := FileRead(_yamlPath, "UTF-8")

        ; 2. Load expected event stream
        _expected := FileRead(_eventPath, "UTF-8")
        ; Normalize expected line breaks and trim
        _expected := StrReplace(_expected, "`r`n", "`n")
        _expected := Trim(_expected, " `n`r`t")

        ; 3. Parse and canonicalize
        _scanner := _YamlScanner(_input)
        _parser := _YamlParser(_scanner)
        _actual := ""
        _startTime := A_TickCount

        try {
            loop {
                ; Watchdog check: prevent infinite loops during parsing
                if (A_TickCount - _startTime > timeoutMS) {
                    throw Error("Watchdog: Test case timed out after " . timeoutMS . "ms")
                }

                _event := _parser.NextEvent()
                _actual .= EventCanonicalizer.Canonicalize(_event) . "`n"
            } until (_event is YamlStreamEndEvent)
        } catch Any as _e {
            throw Error("Parse error: " . _e.Message)
        }

        _actual := Trim(_actual, " `n`r`t")

        ; 4. Compare
        if (_expected != _actual) {
            throw Error("Mismatch in event stream.`nExpected:`n" . _expected . "`nActual:`n" . _actual)
        }
    }
}
