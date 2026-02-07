#Requires AutoHotkey v2.0

/**
 * @file Assert.ahk
 * @description Provides standardized assertion methods following xUnit patterns.
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
 * Class: Assert
 * Provides standardized assertion methods following xUnit patterns.
 * This class is part of the Infrastructure layer and has no external dependencies.
 */
class Assert {
    /**
     * Method: Equal
     * Checks if two values are equal (Case-insensitive for strings).
     * @param {Any} expected - The target value.
     * @param {Any} actual - The produced value.
     * @param {String} message - Optional custom error description.
     */
    static Equal(expected, actual, message := "") {
        ; Standard xUnit naming 'Equal'
        if !(expected = actual) {
            this._Fail("Equal", expected, actual, message)
        }
    }

    /**
     * Method: StrictEqual
     * Checks if two values are equal (Case-sensitive for strings).
     * @param {Any} expected - The target value.
     * @param {Any} actual - The produced value.
     * @param {String} message - Optional custom error description.
     */
    static StrictEqual(expected, actual, message := "") {
        ; Case-sensitive comparison using '=='
        if !(expected == actual) {
            this._Fail("StrictEqual", expected, actual, message)
        }
    }

    /**
     * Method: True
     * Asserts that a condition is true.
     * @param {Boolean} condition
     * @param {String} message
     */
    static True(condition, message := "") {
        if (!condition) {
            this._Fail("True", "True", "False", message)
        }
    }

    /**
     * Method: False
     * Asserts that a condition is false.
     * @param {Boolean} condition
     * @param {String} message
     */
    static False(condition, message := "") {
        if (condition) {
            this._Fail("False", "False", "True", message)
        }
    }

    /**
     * Method: NotEqual
     * Asserts that two values are not equal.
     */
    static NotEqual(notExpected, actual, message := "") {
        if (notExpected = actual) {
            this._Fail("NotEqual", "Not: " . notExpected, actual, message)
        }
    }

    /**
     * Method: _Fail (Internal)
     * Throws a formatted Error object when an assertion fails.
     */
    static _Fail(type, exp, act, msg) {
        detail := msg ? "`nMessage: " . msg : ""
        throw Error("Assert." . type . " Failed."
            . "`nExpected: [" . exp . "]"
            . "`nActual:   [" . act . "]" . detail)
    }
}
