#Requires AutoHotkey v2.0

/**
 * @class KeyEventTest
 * Validates the properties of the KeyEvent data class.
 */
class KeyEventTest {
    /**
     * @method Test_Constructor_ShouldSetPropertiesCorrectly
     */
    Test_Constructor_ShouldSetPropertiesCorrectly() {
        ; Case 1: Physical Key Down
        ev1 := KeyEvent("vk1D", true, true)
        Assert.Equal("vk1D", ev1.Name)
        Assert.True(ev1.IsDown)
        Assert.True(ev1.IsPhysical)

        ; Case 2: Injected Key Up
        ev2 := KeyEvent("a", false, false)
        Assert.Equal("a", ev2.Name)
        Assert.False(ev2.IsDown)
        Assert.False(ev2.IsPhysical)
    }

    /**
     * @method Test_Constructor_ShouldDefaultToPhysical
     */
    Test_Constructor_ShouldDefaultToPhysical() {
        ev := KeyEvent("Space", true)
        Assert.True(ev.IsPhysical, "Default should be physical (1).")
    }
}