#Requires AutoHotkey v2.0

/**
 * @file ServiceLocator.ahk
 * @description Provides a centralized registry for application services.
 * @author nullmake
 * @license Apache-2.0
 * 
 * Copyright 2026 nullmake
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * @class ServiceLocator
 * Provides a centralized registry for application services with dynamic property access.
 */
class ServiceLocator {
    /** @field {Map} services - Internal storage for service instances */
    static services := Map()

    /**
     * @method Register
     * Registers a service instance and dynamically creates a shortcut property.
     * @param {String} name - The service identifier (e.g., "Config")
     * @param {Object} serviceInstance - The instance to register
     */
    static Register(name, serviceInstance) {
        this.services[name] := serviceInstance

        ; Dynamically define a property on the class if it doesn't exist.
        ; This allows access via ServiceLocator.Name instead of ServiceLocator.Get("Name").
        if !this.HasProp(name) {
            this.DefineProp(name, {
                get: (sl) => sl.Get(name)
            })
        }
    }

    /**
     * @method Get
     * Retrieves a registered service instance.
     * @param {String} name - The service identifier
     * @returns {Object} The service instance
     */
    static Get(name) {
        if !this.services.Has(name) {
            throw Error("Service not registered: " . name)
        }
        return this.services[name]
    }

    /**
     * @method Reset
     * Clears all registered services and removes dynamic properties.
     * Primarily used for unit testing to ensure isolation.
     */
    static Reset() {
        for name, _ in this.services.Clone() {
            if (this.HasProp(name)) {
                this.DeleteProp(name)
            }
        }
        this.services.Clear()
    }
}