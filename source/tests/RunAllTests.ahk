#Requires AutoHotkey v2.0
; --- Library Includes ---
#Include ../lib/Logger.ahk
#Include ../lib/ServiceLocator.ahk
#Include ../lib/Assert.ahk
#Include ../lib/Ime.ahk
#Include ../lib/KeyEvent.ahk
#Include ../lib/Window.ahk
#Include ../lib/TestRunner.ahk

; --- Yaml Library ---
#Include ../lib/Yaml/_Errors.ahk
#Include ../lib/Yaml/_Events.ahk
#Include ../lib/Yaml/_Nodes.ahk
#Include ../lib/Yaml/_Scanner.ahk
#Include ../lib/Yaml/_Parser.ahk
#Include ../lib/Yaml/Yaml.ahk

; --- Test Suite Includes ---
#Include AssertTest.ahk
#Include ImeTest.ahk
#Include KeyEventTest.ahk
#Include LoggerTest.ahk
#Include ServiceLocatorTest.ahk
#Include WindowTest.ahk
#Include Yaml/ScannerTest.ahk
#Include Yaml/ParserTest.ahk
#Include Yaml/ConstructorTest.ahk
#Include Yaml/YamlTest.ahk
#Include Yaml/EventCanonicalizer.ahk
#Include Yaml/YamlTestSuiteTest.ahk

; --- Setup Environment ---
logDir := (A_Args.Length > 0) ? A_Args[1] : A_ScriptDir . "\logs"
if (!DirExist(logDir)) {
    DirCreate(logDir)
}

_logger := Logger(logDir, 1000, 10)
ServiceLocator.Register("Logger", _logger)
_runner := TestRunner(_logger)

; --- Run Suites ---
_runner.Run(AssertTest())
_runner.Run(ImeTest())
_runner.Run(KeyEventTest())
_runner.Run(LoggerTest())
_runner.Run(ServiceLocatorTest())
_runner.Run(WindowTest())
_runner.Run(ScannerTest())
_runner.Run(ParserTest())
_runner.Run(ConstructorTest())
_runner.Run(YamlTest())
_runner.Run(YamlTestSuiteTest(_logger))

; --- Finalize ---
_runner.PrintFinalSummary()
_logger.Flush("TEST")

totalFail := 0
for result in _runner.suiteResults {
    totalFail += result.Fail
}
ExitApp(totalFail > 0)
