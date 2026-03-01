#Requires AutoHotkey v2.0

/**
 * Bitmask flags for identifying which components to test.
 */
class YamlTestTarget {
    static None => 0
    static Parser => 0x1
    static Constructor => 0x2
    static Dump => 0x4
    static All => 0xFF
}

/**
 * Configuration options for the YAML Test Suite runner.
 */
class YamlTestOptions {
    /** @field {Integer} Target - Bitmask of components to test */
    Target := YamlTestTarget.None

    /** @field {Boolean} Trace - Enable detailed tracing of the parsing process */
    Trace := false

    /** @field {Boolean} TestInfo - Include input YAML and intermediate results in failure logs */
    TestInfo := false

    /** @field {Boolean} ErrorStack - Include full AHK stack trace in failure logs */
    ErrorStack := false

    /** @field {Boolean} Varbose - Enable extremely detailed logging (to debug console) */
    Varbose := false

    /** @field {Boolean} SaveDiff - Save/compare failure results against previous run */
    SaveDiff := false
}
