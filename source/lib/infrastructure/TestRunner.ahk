#Requires AutoHotkey v2.0

/**
 * @file TestRunner.ahk
 * @description Basic xUnit-style test executor for AutoHotkey v2.
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
 * @class TestRunner
 * Basic xUnit-style test executor for AutoHotkey v2.
 * Collects and reports summaries per test suite.
 */
class TestRunner {
    /** @field {Logger} log - Application logger instance */
    log := ""
    /** @field {Array} suiteResults - Collection of {Name, Pass, Fail} objects */
    suiteResults := []

    /**
     * Constructor: __New
     * @param {Logger} logSvc
     */
    __New(logSvc) {
        this.log := logSvc
    }

    /**
     * Method: Run
     * Runs all methods starting with 'Test_' in the given class instance.
     * @param {Object} testSuite - Instance of a test class.
     * @returns {Boolean} - True if all tests in this suite passed.
     */
    Run(testSuite) {
        suiteName := Type(testSuite)
        this.log.Info(">>> Starting Test Suite: " . suiteName)

        passCount := 0
        failCount := 0

        ; Inspect the base (prototype) of the instance to find defined methods
        for propName in testSuite.Base.OwnProps() {
            if (SubStr(propName, 1, 5) == "Test_") {
                this.log.Info("  Running: " . propName)

                try {
                    if (HasMethod(testSuite, "Setup")) {
                        testSuite.Setup()
                    }

                    testSuite.%propName%()

                    passCount++
                    this.log.Info("    => [PASS]")
                } catch Error as e {
                    failCount++
                    this.log.Error("    => [FAIL]", e)
                } finally {
                    if (HasMethod(testSuite, "Teardown")) {
                        testSuite.Teardown()
                    }
                }
            }
        }

        ; Store result for the final summary
        this.suiteResults.Push({
            Name: suiteName,
            Pass: passCount,
            Fail: failCount
        })

        this.log.Info("--- " . suiteName . " Finished. Pass: " . passCount . ", Fail: " . failCount)
        return (failCount == 0)
    }

    /**
     * Method: PrintFinalSummary
     * Logs a formatted summary of all executed test suites.
     */
    PrintFinalSummary() {
        this.log.Info("========================================")
        this.log.Info("FINAL TEST SUMMARY")
        this.log.Info("========================================")

        totalPass := 0
        totalFail := 0

        for result in this.suiteResults {
            status := (result.Fail == 0) ? "[PASS]" : "[FAIL]"
            ; AHK v2 Format syntax: {Index:Format}. Use 's' for strings and negative width for left-alignment.
            line := Format("{1:-7s} {2:-25s} (Pass: {3}, Fail: {4})",
                status, result.Name, result.Pass, result.Fail)
            this.log.Info(line)
            
            totalPass += result.Pass
            totalFail += result.Fail
        }

        this.log.Info("----------------------------------------")
        this.log.Info(Format("TOTAL:  Pass: {1}, Fail: {2}", totalPass, totalFail))
        this.log.Info("========================================")
    }
}