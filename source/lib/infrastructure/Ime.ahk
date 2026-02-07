#Requires AutoHotkey v2.0

/**
 * @file Ime.ahk
 * @description Pure infrastructure utility for Input Method Editor (IME) operations.
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
 * @class Ime
 * Pure infrastructure utility for Input Method Editor (IME) operations.
 * Based on the logic of 'zenhan' utility for reliable switching.
 */
class Ime {
    /** @field {Integer} WM_IME_CONTROL - Windows Message for IME control */
    static WM_IME_CONTROL => 0x0283
    /** @field {Integer} IMC_GETOPENSTATUS - Command to get IME open status */
    static IMC_GETOPENSTATUS => 0x0005
    /** @field {Integer} IMC_SETOPENSTATUS - Command to set IME open status */
    static IMC_SETOPENSTATUS => 0x0006

    /**
     * @method GetStatus
     * Gets current IME status (Open/Closed).
     * @param {String} winTitle - Target window (default "A" for active window)
     * @returns {Integer} 1 for Open (ON), 0 for Closed (OFF)
     */
    static GetStatus(winTitle := "A") {
        hwnd := WinExist(winTitle)
        if (!hwnd) {
            return 0
        }

        try {
            ; Get the default IME window handle for the target window
            defaultImeWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
            if (!defaultImeWnd) {
                return 0
            }

            ; Use DllCall to bypass AHK's window matching logic and DetectHiddenWindows setting.
            ; This directly uses the HWND to send the WM_IME_CONTROL message.
            return DllCall("user32\SendMessage", "Ptr", defaultImeWnd, "UInt", Ime.WM_IME_CONTROL, "Ptr", Ime.IMC_GETOPENSTATUS, "Ptr", 0, "Ptr")
        } catch Any as e {
            OutputDebug("Error getting IME status: " . e.Message)
            return 0
        }
    }

    /**
     * @method SetStatus
     * Sets IME status (Open/Closed).
     * @param {Integer} setStatus - 1 for Open (ON), 0 for Closed (OFF)
     * @param {String} winTitle - Target window (default "A" for active window)
     */
    static SetStatus(setStatus, winTitle := "A") {
        hwnd := WinExist(winTitle)
        if (!hwnd) {
            return
        }

        try {
            ; Get the default IME window handle for the target window
            defaultImeWnd := DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hwnd, "Ptr")
            if (!defaultImeWnd) {
                return
            }

            ; Use DllCall to bypass AHK's window matching logic and DetectHiddenWindows setting.
            ; This directly uses the HWND to send the WM_IME_CONTROL message with IMC_SETOPENSTATUS.
            DllCall("user32\SendMessage", "Ptr", defaultImeWnd, "UInt", Ime.WM_IME_CONTROL, "Ptr", Ime.IMC_SETOPENSTATUS, "Ptr", setStatus, "Ptr")
        } catch Any as e {
            OutputDebug("Error setting IME status: " . e.Message)
        }
    }
}
