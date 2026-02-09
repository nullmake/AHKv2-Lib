#Requires AutoHotkey v2.0

/**
 * @file TestLogger.ahk
 * @description Immediate logging utility specialized for unit testing.
 * @author nullmake
 * @license Apache-2.0
 *
 * @example
 * _log := TestLogger(A_ScriptDir "\logs")
 * _log.Info("Starting test suite...")
 *
 * Copyright 2026 nullmake
 */

/**
 * @class TestLogger
 * Real-time logger that writes directly to file and standard output without buffering.
 */
class TestLogger {
    /** @field {String} _logPath - Full path to the active log file */
    _logPath := ""

    /** @field {Boolean} _isDebugger - Whether a debugger is attached */
    _isDebugger := false

    /**
    * @constructor
    * @param {String} logDir - Directory to store log files.
    */
    __New(logDir) {
        if (!DirExist(logDir)) {
            DirCreate(logDir)
        }

        _ts := FormatTime(, "yyyyMMdd_HHmmss")
        this._logPath := logDir . "\test_" . _ts . ".log"

        ; Detect debugger once during initialization
        this._isDebugger := DllCall("IsDebuggerPresent")
        if (!this._isDebugger) {
            DllCall("CheckRemoteDebuggerPresent", "Ptr", DllCall("GetCurrentProcess", "Ptr"), "Int*", &_isRemoteDebugger := 0)
            this._isDebugger := _isRemoteDebugger
        }

        if (!this._isDebugger) {
            _cmdLine := DllCall("GetCommandLine", "Str")
            if (InStr(_cmdLine, "/debug")) {
                this._isDebugger := true
            }
        }

        this.Info("=== Test Execution Started ===")
    }

    /**
    * @method Info
    * @param {String} message
    */
    Info(message) => this._Write("INFO", message)

    /**
    * @method Warn
    * @param {String} message
    */
    Warn(message) => this._Write("WARN", message)

    /**
    * @method Error
    * @param {String} message
    * @param {Error} err - (Optional) Error object
    */
    Error(message, err := unset) {
        _detail := message
        if (IsSet(err)) {
            _detail .= "`n[" . err.What . "] " . err.Message . "`n" . err.Stack
        }
        this._Write("ERROR", _detail)
    }

    /**
    * @method _Write
    * Internal method to handle immediate output to stdout and file.
    * @private
    */
    _Write(level, msg) {
        _ts := FormatTime(, "yyyy-MM-dd HH:mm:ss")

        ; Capture caller location
        _location := ""
        try {
            throw Error("", -3)
        } catch Error as _e {
            SplitPath(_e.File, &_fileName)
            _location := Format("[{1}:{2}] ", _fileName, _e.Line)
        }

        _entryBase := Format("[{1}] [{2}] {3}{4}", _ts, level, _location, msg)
        _entryWithNL := _entryBase . "`n"

        if (this._isDebugger) {
            ; VSCode Debug Console typically adds a newline per OutputDebug call
            OutputDebug(_entryBase)
        } else {
            ; Output to standard output (stdout) for CLI
            try {
                FileAppend(_entryWithNL, "*", "UTF-8")
            }
        }

        ; Output to log file
        try {
            FileAppend(_entryWithNL, this._logPath, "UTF-8")
        }
    }

    /**
    * @method Flush
    * Compatibility method.
    */
    Flush(trigger := "") {
        ; No-op
    }
}
