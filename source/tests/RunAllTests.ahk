#Requires AutoHotkey v2.0
#Include ../lib/Logger.ahk
#Include ../lib/ServiceLocator.ahk
#Include ../lib/Assert.ahk
#Include ../lib/Ime.ahk
#Include ../lib/KeyEvent.ahk
#Include ../lib/Window.ahk
#Include ../lib/TestRunner.ahk

#Include AssertTest.ahk
#Include ImeTest.ahk
#Include KeyEventTest.ahk
#Include LoggerTest.ahk
#Include ServiceLocatorTest.ahk
#Include WindowTest.ahk

; Set up environment
; Allow log directory to be specified via command line argument
logDir := (A_Args.Length > 0) ? A_Args[1] : A_ScriptDir . "\logs"

if (!DirExist(logDir)) {
    DirCreate(logDir)
}

; Initialize Logger
_logger := Logger(logDir, 1000, 10)
ServiceLocator.Register("Logger", _logger)

; Initialize Runner
_runner := TestRunner(_logger)

; Run Suites
_runner.Run(AssertTest())
_runner.Run(ImeTest())
_runner.Run(KeyEventTest())
_runner.Run(LoggerTest())
_runner.Run(ServiceLocatorTest())
_runner.Run(WindowTest())

; Summary
_runner.PrintFinalSummary()
_logger.Flush("TEST")

; Exit with code based on results
totalFail := 0
for result in _runner.suiteResults {
    totalFail += result.Fail
}

if (totalFail > 0) {
    ExitApp(1)
} else {
    ExitApp(0)
}
