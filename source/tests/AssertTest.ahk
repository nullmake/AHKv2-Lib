#Requires AutoHotkey v2.0

/**
 * @class AssertTest
 * Validates the core assertion logic.
 */
class AssertTest {
    /**
     * @method Test_Equal_ShouldPassWhenValuesAreEqual
     */
    Test_Equal_ShouldPassWhenValuesAreEqual() {
        Assert.Equal(1, 1)
        Assert.Equal("abc", "ABC", "String comparison should be case-insensitive by default.")
    }

    /**
     * @method Test_Equal_ShouldFailWhenValuesAreDifferent
     */
    Test_Equal_ShouldFailWhenValuesAreDifferent() {
        try {
            Assert.Equal(1, 2)
            Assert.Fail("Should have thrown an error.")
        } catch Error {
            ; Success
        }
    }

    /**
     * @method Test_StrictEqual_ShouldBeCaseSensitive
     */
    Test_StrictEqual_ShouldBeCaseSensitive() {
        Assert.StrictEqual("abc", "abc")
        try {
            Assert.StrictEqual("abc", "ABC")
            Assert.Fail("StrictEqual should be case-sensitive.")
        } catch Error {
            ; Success
        }
    }

    /**
     * @method Test_TrueAndFalse
     */
    Test_TrueAndFalse() {
        Assert.True(1 == 1)
        Assert.False(1 == 2)
    }

    /**
     * @method Test_NotEqual
     */
    Test_NotEqual() {
        Assert.NotEqual(1, 2)
        try {
            Assert.NotEqual("a", "a")
            Assert.Fail("Should have failed for equal values.")
        } catch Error {
            ; Success
        }
    }
}