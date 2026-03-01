#Requires AutoHotkey v2.0
#Include ../lib/Logger.ahk
#Include ../lib/TestLogger.ahk
#Include ../lib/TestRunner.ahk
#Include ../lib/Assert.ahk
#Include ../lib/Yaml/Yaml.ahk

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

_targetIds := []
_options := YamlTestOptions()

; for VSCode Run and Debug
if (false) {
    _args := []
    _args.Push("--trace")
    _args.Push("--info")
    ;_args.Push("--stack")
    ;_args.Push("--varbose")
    ;_args.Push("--save-diff")
    ;_args.Push("--parser")
    ;_args.Push("--constructor")
    _args.Push("--dump")
    ;_targetIds := []
}
else {
    _args := A_Args
}

for arg in _args {
    if (arg == "--trace") {
        _options.Trace := true
    }
    else if (arg == "--info") {
        _options.TestInfo := true
    }
    else if (arg == "--stack") {
        _options.ErrorStack := true
    }
    else if (arg == "--varbose") {
        _options.Varbose := true
    }
    else if (arg == "--save-diff") {
        _options.SaveDiff := true
    }
    else if (arg == "--parser") {
        _options.Target |= YamlTestTarget.Parser
    }
    else if (arg == "--constructor") {
        _options.Target |= YamlTestTarget.Constructor
    }
    else if (arg == "--dump") {
        _options.Target |= YamlTestTarget.Dump
    }
    else {
        _targetIds.Push(String(arg))
    }
}
if (_options.Target == YamlTestTarget.None) {
    _options.Target := YamlTestTarget.All
}

_logger.Info("=== YAML Test Suite Execution Started ===")

try {
    if (_options.Target & YamlTestTarget.Parser) {
        _logger.Info("--- Running Parser Event Tests ---")
        _runner.Run(YamlParserTest(_logger, _options, _targetIds))
    }
    if (_options.Target & YamlTestTarget.Constructor) {
        _logger.Info("--- Running Constructor JSON Tests ---")
        _runner.Run(YamlConstructorTest(_logger, _options, _targetIds))
    }
    if (_options.Target & YamlTestTarget.Dump) {
        _logger.Info("--- Running Dump Round-Trip Tests ---")
        _runner.Run(YamlDumpTest(_logger, _options, _targetIds))
    }
} catch YamlError as _e {
    _logger.Error("Critical error during test run: " . _e.Message . "line=" . _e.line . "column=" . _e.column)
} catch Any as _e {
    _logger.Error("Critical error during test run: " . _e.Message)
}

_logger.Info("========================================")
_logger.Info("FINAL TEST SUMMARY")
_logger.Info("========================================")