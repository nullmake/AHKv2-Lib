#Requires AutoHotkey v2.0
#Include ../lib/Logger.ahk
#Include ../lib/TestLogger.ahk
#Include ../lib/TestRunner.ahk
#Include ../lib/Assert.ahk
#Include ../lib/ServiceLocator.ahk
#Include ../lib/Window.ahk
#Include ../lib/KeyEvent.ahk
#Include ../lib/Ime.ahk
#Include ../lib/Yaml/Yaml.ahk

#Include AssertTest.ahk
#Include ImeTest.ahk
#Include KeyEventTest.ahk
#Include LoggerTest.ahk
#Include ServiceLocatorTest.ahk
#Include WindowTest.ahk

#Include Yaml/EventCanonicalizer.ahk
#Include Yaml/JsonStringifier.ahk
#include Yaml/YamlTestOptions.ahk
#Include Yaml/YamlTestSuiteTestBase.ahk
#include yaml/YamlConstructorTest.ahk
#include yaml/YamlDumpTest.ahk
#include yaml/YamlLayoutProcessorTest.ahk
#include yaml/YamlParserTest.ahk
#include yaml/YamlRawScannerTest.ahk

_logger := TestLogger(A_ScriptDir "\logs")
_runner := TestRunner(_logger)

_logger.Info("=== Test Execution Started ===")

try {
    _runner.Run(AssertTest())
    _runner.Run(ImeTest())
    _runner.Run(KeyEventTest())
    _runner.Run(LoggerTest())
    _runner.Run(ServiceLocatorTest())
    _runner.Run(WindowTest())
    _runner.Run(YamlParserTest(_logger))
    _runner.Run(YamlConstructorTest(_logger))
    _runner.Run(YamlDumpTest(_logger))
}
catch Any as _e {
    _logger.Error("Critical error during test run: " . _e.Message)
}

_runner.PrintFinalSummary()