#Requires AutoHotkey v2.0

/**
 * @file KeyboardHook.ahk
 * @description Adapter Layer that encapsulates WH_KEYBOARD_LL.
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
 * Class: KeyboardHook
 * Adapter Layer that encapsulates WH_KEYBOARD_LL.
 */
class KeyboardHook {
    /** @field {Integer} WH_KEYBOARD_LL - Windows Hook ID for Low-Level Keyboard Hook */
    static WH_KEYBOARD_LL := 13
    /** @field {Integer} WM_KEYDOWN - Message ID for Key Down */
    static WM_KEYDOWN := 0x0100
    /** @field {Integer} WM_KEYUP - Message ID for Key Up */
    static WM_KEYUP := 0x0101
    /** @field {Integer} WM_SYSKEYDOWN - Message ID for System Key Down */
    static WM_SYSKEYDOWN := 0x0104
    /** @field {Integer} WM_SYSKEYUP - Message ID for System Key Up */
    static WM_SYSKEYUP := 0x0105

    /** @field {Integer} hHook - Handle to the Windows Hook */
    hHook := 0
    /** @field {Any} proc - Reference to the callback to prevent GC */
    proc := 0
    /** @field {Function} onEvent - Injected event handler */
    onEvent := ""

    /**
     * Constructor: __New
     * @param {Function} onEventCallback - Function to call when a key event occurs.
     */
    __New(onEventCallback) {
        this.onEvent := onEventCallback
        ; Ensure the callback is tied to this instance
        this.proc := CallbackCreate(this._LowLevelKeyboardProc.Bind(this), "Fast", 3)
    }

    /**
     * Method: Start
     * Begins capturing keyboard input.
     */
    Start() {
        if (this.hHook) {
            return
        }

        hMod := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
        this.hHook := DllCall("SetWindowsHookEx", "Int", KeyboardHook.WH_KEYBOARD_LL
            , "Ptr", this.proc, "Ptr", hMod, "UInt", 0, "Ptr")

        if (!this.hHook) {
            throw Error("Failed to set Keyboard Hook.")
        }
    }

    /**
     * Method: Stop
     * Releases the hook.
     */
    Stop() {
        if (this.hHook) {
            DllCall("UnhookWindowsHookEx", "Ptr", this.hHook)
            this.hHook := 0
        }
    }

    /**
     * Clean up on destruction.
     */
    __Delete() {
        this.Stop()
        if (this.proc) {
            CallbackFree(this.proc)
        }
    }

    /**
     * Low-level Hook Callback Procedure.
     * @param {Integer} nCode
     * @param {Integer} wParam
     * @param {Integer} lParam
     * @private
     */
    _LowLevelKeyboardProc(nCode, wParam, lParam) {
        try {
            if (nCode >= 0) {
                if (this._HandleRawInput(wParam, lParam)) {
                    return 1
                }
            }
        } catch Any as e {
            this._SafeLog(e)
        }

        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "Ptr", wParam, "Ptr", lParam, "Ptr")
    }

    /**
     * Parse raw input and dispatch as KeyEvent.
     * @param {Integer} wParam - Message ID (WM_KEYDOWN, etc.)
     * @param {Ptr} lParam - Pointer to KBDLLHOOKSTRUCT
     * @returns {Integer} 1 to suppress the event, 0 to allow it.
     * @private
     */
    _HandleRawInput(wParam, lParam) {
        ; Extract Virtual Key Code and Flags from KBDLLHOOKSTRUCT
        vkCode := NumGet(lParam, 0, "UInt")
        flags := NumGet(lParam, 8, "UInt")

        ; Determine if key is pressed or released
        isDown := (wParam == KeyboardHook.WM_KEYDOWN || wParam == KeyboardHook.WM_SYSKEYDOWN)

        ; Check LLKHF_INJECTED (0x10) to see if input is physical or artificial
        isPhysical := !(flags & 0x10)

        ; Get AHK-compatible key name (e.g., "vk1D", "a")
        ; Fallback: If GetKeyName returns empty, use "vkXX" format.
        ; This ensures JIS keys like Muhenkan (vk1D) are always identifiable.
        keyName := GetKeyName(Format("vk{:02X}", vkCode))
        if (keyName == "") {
            keyName := Format("vk{:02X}", vkCode)
        }

        ; Create KeyEvent object
        event := KeyEvent(keyName, isDown, isPhysical)

        ; Dispatch via injected callback
        if (this.onEvent) {
            return this.onEvent.Call(event)
        }
        return 0
    }

    /**
     * Logs error messages to the debug output without external dependencies.
     * @param {Error} err - The error object to log.
     */
    _SafeLog(err) {
        ; Use OutputDebug to avoid dependency on Logger class
        OutputDebug("Kyuri Hook Error: " . err.Message . " (" . err.Line . ")")
    }
}
