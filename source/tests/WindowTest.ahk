#Requires AutoHotkey v2.0

/**
 * @class WindowTest
 * Validates the Window utility interface.
 */
class WindowTest {
    /**
     * @method Test_InterfaceExists
     */
    Test_InterfaceExists() {
        Assert.True(HasMethod(Window, "Next"), "Next() should exist.")
        Assert.True(HasMethod(Window, "Prev"), "Prev() should exist.")
    }
}