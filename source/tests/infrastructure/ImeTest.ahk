#Requires AutoHotkey v2.0

/**
 * @class ImeTest
 * Validates the Ime utility interface.
 */
class ImeTest {
    /**
     * @method Test_InterfaceExists
     */
    Test_InterfaceExists() {
        Assert.True(HasMethod(Ime, "GetStatus"), "GetStatus() should exist.")
        Assert.True(HasMethod(Ime, "SetStatus"), "SetStatus() should exist.")
    }

    /**
     * @method Test_GetStatus_ReturnsNumeric
     */
    Test_GetStatus_ReturnsNumeric() {
        status := Ime.GetStatus()
        Assert.True(IsNumber(status), "GetStatus should return a numeric value.")
    }
}