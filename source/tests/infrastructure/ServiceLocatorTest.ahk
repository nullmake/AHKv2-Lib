#Requires AutoHotkey v2.0

/**
 * @class ServiceLocatorTest
 * Validates the service registration and discovery logic.
 */
class ServiceLocatorTest {
    /**
     * @method Setup
     * Ensures a clean state before each test.
     */
    Setup() {
        ServiceLocator.Reset()
    }

    /**
     * @method Test_RegisterAndGet_ShouldWorkCorrectly
     */
    Test_RegisterAndGet_ShouldWorkCorrectly() {
        mockService := { Data: "Hello" }
        ServiceLocator.Register("TestSvc", mockService)
        
        result := ServiceLocator.Get("TestSvc")
        Assert.Equal(mockService, result, "Should retrieve the same instance that was registered.")
    }

    /**
     * @method Test_DynamicPropertyAccess_ShouldWorkCorrectly
     */
    Test_DynamicPropertyAccess_ShouldWorkCorrectly() {
        mockService := { Value: 123 }
        ServiceLocator.Register("MySvc", mockService)
        
        ; Test dynamic property access (shortcut)
        Assert.Equal(123, ServiceLocator.MySvc.Value, "Should allow access via dynamic property.")
    }

    /**
     * @method Test_GetUnregistered_ShouldThrowError
     */
    Test_GetUnregistered_ShouldThrowError() {
        try {
            ServiceLocator.Get("NonExistent")
            Assert.Fail("Should have thrown an error for unregistered service.")
        } catch Error as e {
            Assert.True(InStr(e.Message, "Service not registered"), "Error message should be descriptive.")
        }
    }

    /**
     * @method Test_Reset_ShouldClearAllServices
     */
    Test_Reset_ShouldClearAllServices() {
        ServiceLocator.Register("Temp", {})
        ServiceLocator.Reset()
        
        Assert.False(ServiceLocator.HasProp("Temp"), "Dynamic property should be removed after Reset.")
        
        try {
            ServiceLocator.Get("Temp")
            Assert.Fail("Service mapping should be cleared after Reset.")
        } catch {
            ; Success
        }
    }

    /**
     * @method Teardown
     * Clean up after tests.
     */
    Teardown() {
        ServiceLocator.Reset()
    }
}