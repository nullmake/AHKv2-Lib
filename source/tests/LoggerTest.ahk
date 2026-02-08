#Requires AutoHotkey v2.0

/**
 * @class LoggerTest
 * Validates the buffering and rotation logic of the Logger class.
 */
class LoggerTest {
    /** @field {String} testDir - Isolated directory for log testing */
    testDir := A_ScriptDir . "\temp_log"
    /** @field {Logger} logger - Instance under test */
    logger := ""

    /**
     * @method Setup
     * Create a clean temporary directory for each test.
     */
    Setup() {
        if (DirExist(this.testDir)) {
            DirDelete(this.testDir, true)
        }
        DirCreate(this.testDir)
        ; Initialize Logger directly pointing to the test directory
        this.logger := Logger(this.testDir, 5, 3) ; maxEntries: 5, maxFiles: 3
    }

    /**
     * @method Test_Buffer_ShouldRespectMaxEntries
     */
    Test_Buffer_ShouldRespectMaxEntries() {
        loop 10 {
            this.logger.Info("Message " . A_Index)
        }

        Assert.Equal(5, this.logger.buffer.Length, "Buffer should be capped at 5.")
        Assert.True(InStr(this.logger.buffer[1], "Message 6"), "First entry should be the 6th message.")
    }

    /**
     * @method Test_Rotation_ShouldRespectMaxFiles
     */
    Test_Rotation_ShouldRespectMaxFiles() {
        ; 1. Create 5 flushes (exceeding maxFiles: 3)
        loop 5 {
            this.logger.Info("Log batch " . A_Index)
            this.logger.Flush("TEST" . A_Index)
            Sleep(1100) ; Ensure timestamp-based filenames are unique
        }

        ; 2. Count generated files in the test directory directly
        fileCount := 0
        loop files, this.testDir . "\kyuri_*.log" {
            fileCount++
        }

        Assert.Equal(3, fileCount, "Should only keep the latest 3 log files.")
    }

    /**
     * @method Teardown
     * Cleanup the temporary directory.
     */
    Teardown() {
        this.logger := ""
        if (DirExist(this.testDir)) {
            DirDelete(this.testDir, true)
        }
    }
}
