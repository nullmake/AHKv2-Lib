#Requires AutoHotkey v2.0

/**
 * @file Logger.ahk
 * @description Buffers logs in memory and flushes to rotating files.
 * @author nullmake
 * @license Apache-2.0
 * 
 * Copyright 2026 nullmake
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @class Logger
 * Buffers logs in memory and flushes to rotating files.
 * Automatically captures file and line info for all levels.
 */
class Logger {
    /** @field {Boolean} _enabled - Internal logging state */
    _enabled := true
    /** @field {String} logDir - Directory for log files */
    logDir := ""
    /** @field {Array} buffer - Memory storage for log entries */
    buffer := []
    /** @field {Integer} maxEntries - Maximum lines in memory */
    maxEntries := 0
    /** @field {Integer} maxFiles - Maximum history files to keep */
    maxFiles := 0
    /** @field {Integer} pid - Current process ID for uniqueness */
    pid := DllCall("GetCurrentProcessId")

    /**
     * @property Enabled
     * Handles switching and clears buffer when disabled.
     */
    Enabled {
        get => this._enabled
        set {
            this._enabled := value
            if (!value) {
                this.buffer := []
            }
        }
    }

    /**
     * @method __New
     * @constructor
     * @param {String} logDir - Full path to the log directory.
     * @param {Integer} maxEntries - Buffer size limit.
     * @param {Integer} maxFiles - Maximum history files.
     * @param {Boolean} enabled - Initial logging state.
     */
    __New(logDir, maxEntries := 1000, maxFiles := 30, enabled := true) {
        this.logDir := logDir
        this.maxEntries := maxEntries
        this.maxFiles := maxFiles
        this.Enabled := enabled

        if (!DirExist(this.logDir)) {
            DirCreate(this.logDir)
        }
    }

    /**
     * @method Info
     */
    Info(message) => this.Log("INFO", message)

    /**
     * @method Warn
     */
    Warn(message) {
        this.Log("WARN", message)
        this.Flush("WRN")
    }

    /**
     * @method Error
     * @param {String} message - Error description.
     * @param {Error} err - (Optional) The Error object.
     */
    Error(message, err := unset) {
        this.Log("ERROR", message, err?)
        this.Flush("ERR")
    }

    /**
     * @method Log
     * Handles metadata extraction and buffering. (Internal)
     * @param {String} level - INFO, WARN, ERROR, etc.
     * @param {String} msg - The message.
     * @param {Error} err - (Optional) The Error object.
     */
    Log(level, msg, err := unset) {
        if (!this.Enabled) {
            return
        }

        detail := ""
        ; Case: String passed - capture caller location using Error(-2)
        try {
            throw Error("", -2)
        } catch Error as e {
            SplitPath(e.File, &fileName)
            detail := Format("[{1}:{2}] {3}", fileName, e.Line, msg)
        }

        if (IsSet(err)) {
            detail .= "`n[" . err.What . "] " . err.Message
            detail .= "`n--- call stack ---`n" . err.Stack
        }

        ts := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        entry := "[" . ts . "] [" . level . "] " . detail
        this.buffer.Push(entry)

        if (this.buffer.Length > this.maxEntries) {
            this.buffer.RemoveAt(1)
        }
        OutputDebug(entry)
    }

    /**
     * @method Flush
     * Writes the current full buffer to a file. Does NOT clear the buffer.
     * @param {String} trigger - Label for the filename (Default: MAN).
     */
    Flush(trigger := "MAN") {
        if (!this.Enabled || this.buffer.Length == 0) {
            return
        }

        ts := FormatTime(, "yyyyMMdd_HHmmss")
        fName := "kyuri_" . ts . "_P" . this.pid . "_" . trigger . ".log"
        fullPath := this.logDir . "\" . fName

        content := ""
        for entry in this.buffer {
            content .= entry . "`n"
        }

        try {
            if (FileExist(fullPath)) {
                FileDelete(fullPath)
            }
            FileAppend(content, fullPath, "UTF-8")
            this.Rotate()
        } catch Error as e {
            OutputDebug("Log Flush failed: " . e.Message)
        }
    }

    /**
     * @method Rotate
     * Efficiently rotates logs using the built-in Sort function.
     */
    Rotate() {
        filePaths := ""
        loop files, this.logDir . "\kyuri_*.log" {
            filePaths .= A_LoopFileFullPath . "`n"
        }

        filePaths := RTrim(filePaths, "`n")
        if (filePaths == "") {
            return
        }

        sortedPaths := Sort(filePaths)
        fileList := StrSplit(sortedPaths, "`n")

        if (fileList.Length > this.maxFiles) {
            deleteCount := fileList.Length - this.maxFiles
            loop deleteCount {
                try {
                    FileDelete(fileList[A_Index])
                }
            }
        }
    }
}
