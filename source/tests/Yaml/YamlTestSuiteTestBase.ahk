#Requires AutoHotkey v2.0

/**
 * @file YamlTestSuiteTestBase.ahk
 * @description Base class for YAML Test Suite runners.
 * @author nullmake
 * @license Apache-2.0
 * Copyright 2026 nullmake
 */

/**
 * Base class providing common functionality for loading and running YAML test suite cases.
 */
class YamlTestSuiteTestBase {
    /** @field {Object} _logger - Test logger instance */
    _logger := ""

    /** @field {YamlTestOptions} _options - Runner options */
    _options := ""

    /** @field {String} _baseDir - Root directory of the test suite data */
    _baseDir := ""

    /** @field {Array|String} _targetIds - Specific test IDs to run */
    _targetIds := ""

    /** @field {Integer} _passCount - Number of successful cases */
    _passCount := 0

    /** @field {Integer} _failCount - Number of failed cases */
    _failCount := 0

    /** @field {Integer} _total - Total number of cases attempted */
    _total := 0

    /** @field {Map} _failDataMap - Cache for tracking changes in failure states */
    _failDataMap := Map() ; Map<ID, {previous: {id, msg}, current: {id, msg}}>

    /**
     * @param {Object} logger
     * @param {YamlTestOptions} [options]
     * @param {Array|String} [targetIds=""]
     */
    __New(logger, options := YamlTestOptions(), targetIds := "") {
        this._logger := logger
        this._options := options
        this._targetIds := targetIds
        this._baseDir := A_ScriptDir . "\data\yaml-test-suite"
    }

    /**
     * Discovers and executes all relevant test cases.
     */
    Test_AllSuiteCases() {
        _log := this._logger
        this._passCount := 0
        this._failCount := 0
        this._total := 0
        this._failDataMap := Map()

        ; 1. Initialize failed cases log if SaveDiff is enabled
        if (this._options.SaveDiff) {
            _failedLogPath := A_ScriptDir . "\logs\failed_cases.log"
            if (!DirExist(A_ScriptDir . "\logs")) {
                DirCreate(A_ScriptDir . "\logs")
            }
            if (FileExist(_failedLogPath)) {
                _content := FileRead(_failedLogPath, "UTF-8")
                loop parse, _content, "`n", "`r" {
                    if (A_LoopField == "")
                        continue

                    ; Parse line: [STATUS] ID: Message
                    if (RegExMatch(A_LoopField, "^\[(.{2})\]\s*([^:]+):\s*(.*)$", &match)) {
                        _status := match[1]
                        if (_status == "--") ; Skip previously fixed cases
                            continue

                        _id := match[2]
                        _msg := match[3]
                        this._failDataMap[_id] := { previous: { id: _id, msg: _msg }, current: "" }
                    }
                }
            }
        }

        _hasTarget := false
        if (IsObject(this._targetIds)) {
            if (this._targetIds.Length > 0) {
                _hasTarget := true
            }
        } else if (this._targetIds != "") {
            _hasTarget := true
        }

        _log.Info("Starting YAML Test Suite (including sub-cases)...")
        _log.Info("Base Dir: " . this._baseDir)
        _log.Info("Has Target: " . (_hasTarget ? "Yes" : "No"))

        ; 2. Run Tests
        if (_hasTarget) {
            for i, v in this._targetIds {
                _id := String(v)
                _id := StrReplace(_id, "_", "\")

                _mainPath := this._baseDir . "\" . _id
                if (!DirExist(_mainPath)) {
                    throw Error("Specified Test Case does not exist: " . v)
                }
                if (FileExist(_mainPath . "\in.yaml")) {
                    this._RunCase(_mainPath, _id)
                }
                else {
                    loop files, _mainPath . "\*", "D" {
                        this._RunCase(_mainPath . "\" . A_LoopFileName, _id . "_" . A_LoopFileName)
                    }
                }
            }
        }
        else {
            loop files, this._baseDir . "\*", "D" {
                _id := A_LoopFileName
                if (!RegExMatch(_id, "^[0-9A-Z]{4}$"))
                    continue

                _mainPath := this._baseDir . "\" . _id
                if (FileExist(_mainPath . "\in.yaml")) {
                    this._RunCase(_mainPath, _id)
                } else {
                    loop files, _mainPath . "\*", "D" {
                        this._RunCase(_mainPath . "\" . A_LoopFileName, _id . "_" . A_LoopFileName)
                    }
                }

                if (Mod(this._total, 50) == 0 && this._total > 0) {
                    _log.Info(Format("    Progress: {1} cases processed... (Pass: {2}, Fail: {3})",
                        this._total, this._passCount, this._failCount))
                }
            }
        }

        ; 3. Final Summary
        _log.Info("========================================")
        _log.Info(Format("  FINAL: Pass {1}, Fail {2} of {3}",
            this._passCount, this._failCount, this._total
        ))
        _log.Info("========================================")

        ; 4. Output differences if SaveDiff is enabled
        if (this._options.SaveDiff) {
            _failedLogPath := A_ScriptDir . "\logs\failed_cases.log"
            _output := ""

            for _id, _data in this._failDataMap {
                _prev := _data.previous, _curr := _data.current

                if (IsObject(_curr)) {
                    if (!IsObject(_prev)) {
                        ; Newly failed
                        _output .= "[++] " . _id . ": " . _curr.msg . "`n"
                    } else if (_prev.msg != _curr.msg) {
                        ; Failed with different message
                        _output .= "[!=] " . _id
                            . ": [Current] " . _curr.msg
                            . "  [Previous] " . _prev.msg . "`n"
                    } else {
                        ; Same failure
                        _output .= "[==] " . _id . ": " . _curr.msg . "`n"
                    }
                } else if (IsObject(_prev)) {
                    ; Was failing, now passing
                    _output .= "[--] " . _id . ": (FIXED) " . _prev.msg . "`n"
                }
            }

            try {
                if (FileExist(_failedLogPath)) {
                    FileDelete(_failedLogPath)
                }
                FileAppend(_output, _failedLogPath, "UTF-8")
                _log.Info("Failed cases diff saved to: " . _failedLogPath)
            } catch Any as _e {
                _log.Error("Failed to save failed_cases.log: " . _e.Message)
            }
        }

        if (this._failCount > 0) {
            throw Error("YAML Test Suite failed with " . this._failCount . " errors.")
        }
    }

    /**
     * Handles the setup and execution of a single test case directory.
     * @param {String} path
     * @param {String} logId
     * @private
     */
    _RunCase(path, logId) {
        this._total++
        isErrorCase := FileExist(path . "\error")
        try {
            this._ExecuteCase(path, logId, isErrorCase, this._options)
            this._passCount++
        } catch Any as _e {
            this._failCount++

            ; Clean up error message (remove newlines for single line log)
            lines := StrSplit(_e.Message, "`n", "`r")
            _errMsg := lines.Length >= 2 ? lines[1] . ", " . lines[2] : _e.Message

            if (this._failDataMap.Has(logId)) {
                this._failDataMap[logId].current := { id: logId, msg: _errMsg }
            } else {
                this._failDataMap[logId] := { previous: "", current: { id: logId, msg: _errMsg } }
            }

            message :=
                "Occured Error: " . logId . (isErrorCase ? " (Error Case)" : "")
                . "`n" . _e.Message
            if (this._options.ErrorStack) {
                message .= "`n--- Stack Trace ---`n" . _e.Stack
            }
            this._logger.Warn(message)
        }
    }

    /**
     * Abstract method to be implemented by subclasses to perform specific validation.
     * @param {String} path
     * @param {String} logId
     * @param {Boolean} isErrorCase
     * @param {YamlTestOptions} options
     * @abstract
     * @private
     */
    _ExecuteCase(path, logId, isErrorCase, options) {
    }

    /**
     * Reads a test file and returns its content as a UTF-8 string.
     * @param {String} filePath
     * @returns {String}
     * @private
     */
    _ReadTestFile(filePath)
        => FileExist(filePath) ? FileRead(filePath, "UTF-8") : ""

    /**
     * Generates a hexadecimal representation of the given text for debugging.
     * @param {String} text
     * @returns {String}
     * @private
     */
    _GetBinary(text) {
        binary := ""
        loop parse text {
            binary .= Format("{:02X} ", Ord(A_LoopField))
            if (A_LoopField == "`n") {
                binary .= "`n"
            }
        }
        return binary
    }
}
