//
//  LuaArrayProxy.swift
//  LuaKit
//
//  Provides a proxy for Swift arrays that allows individual element access from Lua
//

import Foundation
import Lua

/// A proxy object that allows Lua to access and modify individual elements of a Swift array
public class LuaArrayProxy<Element: LuaConvertible> {
    private weak var owner: AnyObject?
    private let propertyName: String
    private let getter: () -> [Element]
    private let setter: ([Element]) -> Void
    private let validator: (([Element]) -> Result<Void, PropertyValidationError>)?
    
    init(owner: AnyObject,
         propertyName: String,
         getter: @escaping () -> [Element],
         setter: @escaping ([Element]) -> Void,
         validator: (([Element]) -> Result<Void, PropertyValidationError>)? = nil) {
        self.owner = owner
        self.propertyName = propertyName
        self.getter = getter
        self.setter = setter
        self.validator = validator
    }
    
    // MARK: - Array Access Methods
    
    func getElement(at index: Int) -> Element? {
        let array = getter()
        guard index > 0 && index <= array.count else { return nil }
        return array[index - 1]  // Convert from Lua 1-based to Swift 0-based
    }
    
    func setElement(at index: Int, to value: Element) throws {
        var array = getter()
        
        // Bounds checking
        guard index > 0 else {
            throw PropertyValidationError("Array index must be positive, got \(index)")
        }
        
        // Allow setting one past the end (appending)
        if index > array.count + 1 {
            throw PropertyValidationError("Array index \(index) out of bounds (size: \(array.count))")
        }
        
        // Prepare the new array
        let oldArray = array
        if index == array.count + 1 {
            array.append(value)
        } else {
            array[index - 1] = value
        }
        
        // Validate if needed
        if let validator = validator {
            switch validator(array) {
            case .success:
                break
            case .failure(let error):
                throw error
            }
        }
        
        // Apply the change
        setter(array)
        
        // Notify owner of change if it implements property change notifications
        if let bridgeable = owner as? LuaBridgeable {
            bridgeable.luaPropertyDidChange(propertyName, from: oldArray as Any, to: array as Any)
        }
    }
    
    func getLength() -> Int {
        return getter().count
    }
    
    func toArray() -> [Element] {
        return getter()
    }
    
    // MARK: - Shared Implementation
    
    public var description: String {
        let array = getter()
        return "LuaArrayProxy<\(Element.self)>(\(propertyName): \(array.count) elements)"
    }
}

// MARK: - Concrete String Array Proxy

public final class LuaStringArrayProxy: LuaArrayProxy<String>, LuaBridgeable {
    public static func luaNew(_ L: OpaquePointer) -> Int32 {
        // Array proxies are not directly constructible from Lua
        return luaError(L, "LuaStringArrayProxy cannot be constructed directly")
    }
    
    public static func registerConstructor(_ L: OpaquePointer, name: String) {
        // No constructor needed
    }
    
    public static func registerMethods(_ L: OpaquePointer) {
        // __index metamethod for element access
        lua_pushstring(L, "__index")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Get the proxy object
            guard let proxy = LuaStringArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            
            // Check if key is a number (array index)
            if lua_type(L, 2) == LUA_TNUMBER {
                let index = Int(lua_tointeger(L, 2))
                if let element = proxy.getElement(at: index) {
                    String.push(element, to: L)
                    return 1
                } else {
                    lua_pushnil(L)
                    return 1
                }
            }
            
            // Check for special methods
            if let key = String.pull(from: L, at: 2) {
                switch key {
                case "length", "count":
                    lua_pushinteger(L, lua_Integer(proxy.getLength()))
                    return 1
                case "toArray":
                    // Return the array directly
                    [String].push(proxy.toArray(), to: L)
                    return 1
                default:
                    lua_pushnil(L)
                    return 1
                }
            }
            
            lua_pushnil(L)
            return 1
        }, 0)
        lua_settable(L, -3)
        
        // __newindex metamethod for element assignment
        lua_pushstring(L, "__newindex")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Get the proxy object
            guard let proxy = LuaStringArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            
            // Index must be a number
            guard lua_type(L, 2) == LUA_TNUMBER else {
                return luaError(L, "Array index must be a number")
            }
            
            let index = Int(lua_tointeger(L, 2))
            
            // Get the new value
            guard let newValue = String.pull(from: L, at: 3) else {
                return luaError(L, "Invalid value type for array element")
            }
            
            // Set the element
            do {
                try proxy.setElement(at: index, to: newValue)
            } catch let error as PropertyValidationError {
                return luaError(L, error.message)
            } catch {
                return luaError(L, "Failed to set array element: \(error)")
            }
            
            return 0
        }, 0)
        lua_settable(L, -3)
        
        // __len metamethod for # operator
        lua_pushstring(L, "__len")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let proxy = LuaStringArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            lua_pushinteger(L, lua_Integer(proxy.getLength()))
            return 1
        }, 0)
        lua_settable(L, -3)
        
        // __ipairs metamethod for iteration
        lua_pushstring(L, "__ipairs")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Push iterator function
            lua_pushcclosure(L, { L in
                guard let L = L else { return 0 }
                
                // Get the proxy (first upvalue of ipairs)
                guard let proxy = LuaStringArrayProxy.checkUserdata(L, at: 1) else {
                    return luaError(L, "Invalid array proxy")
                }
                
                // Get current index
                let currentIndex = Int(lua_tointeger(L, 2))
                let nextIndex = currentIndex + 1
                
                // Check if we have more elements
                if let element = proxy.getElement(at: nextIndex) {
                    lua_pushinteger(L, lua_Integer(nextIndex))
                    String.push(element, to: L)
                    return 2
                } else {
                    lua_pushnil(L)
                    return 1
                }
            }, 0)
            
            // Push the proxy object (state)
            lua_pushvalue(L, 1)
            
            // Push initial index (0)
            lua_pushinteger(L, 0)
            
            return 3
        }, 0)
        lua_settable(L, -3)
        
        // __tostring metamethod
        lua_pushstring(L, "__tostring")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let proxy = LuaStringArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            let array = proxy.toArray()
            let elementStrings = array.map { "\"\($0)\"" }
            let arrayString = "[\(elementStrings.joined(separator: ", "))]"
            lua_pushstring(L, arrayString)
            return 1
        }, 0)
        lua_settable(L, -3)
    }
}

// MARK: - Concrete Int Array Proxy

public final class LuaIntArrayProxy: LuaArrayProxy<Int>, LuaBridgeable {
    public static func luaNew(_ L: OpaquePointer) -> Int32 {
        // Array proxies are not directly constructible from Lua
        return luaError(L, "LuaIntArrayProxy cannot be constructed directly")
    }
    
    public static func registerConstructor(_ L: OpaquePointer, name: String) {
        // No constructor needed
    }
    
    public static func registerMethods(_ L: OpaquePointer) {
        // __index metamethod for element access
        lua_pushstring(L, "__index")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Get the proxy object
            guard let proxy = LuaIntArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            
            // Check if key is a number (array index)
            if lua_type(L, 2) == LUA_TNUMBER {
                let index = Int(lua_tointeger(L, 2))
                if let element = proxy.getElement(at: index) {
                    Int.push(element, to: L)
                    return 1
                } else {
                    lua_pushnil(L)
                    return 1
                }
            }
            
            // Check for special methods
            if let key = String.pull(from: L, at: 2) {
                switch key {
                case "length", "count":
                    lua_pushinteger(L, lua_Integer(proxy.getLength()))
                    return 1
                case "toArray":
                    // Return the array directly
                    [Int].push(proxy.toArray(), to: L)
                    return 1
                default:
                    lua_pushnil(L)
                    return 1
                }
            }
            
            lua_pushnil(L)
            return 1
        }, 0)
        lua_settable(L, -3)
        
        // __newindex metamethod for element assignment
        lua_pushstring(L, "__newindex")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Get the proxy object
            guard let proxy = LuaIntArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            
            // Index must be a number
            guard lua_type(L, 2) == LUA_TNUMBER else {
                return luaError(L, "Array index must be a number")
            }
            
            let index = Int(lua_tointeger(L, 2))
            
            // Get the new value
            guard let newValue = Int.pull(from: L, at: 3) else {
                return luaError(L, "Invalid value type for array element")
            }
            
            // Set the element
            do {
                try proxy.setElement(at: index, to: newValue)
            } catch let error as PropertyValidationError {
                return luaError(L, error.message)
            } catch {
                return luaError(L, "Failed to set array element: \(error)")
            }
            
            return 0
        }, 0)
        lua_settable(L, -3)
        
        // __len metamethod for # operator
        lua_pushstring(L, "__len")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let proxy = LuaIntArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            lua_pushinteger(L, lua_Integer(proxy.getLength()))
            return 1
        }, 0)
        lua_settable(L, -3)
        
        // __ipairs metamethod for iteration
        lua_pushstring(L, "__ipairs")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Push iterator function
            lua_pushcclosure(L, { L in
                guard let L = L else { return 0 }
                
                // Get the proxy (first upvalue of ipairs)
                guard let proxy = LuaIntArrayProxy.checkUserdata(L, at: 1) else {
                    return luaError(L, "Invalid array proxy")
                }
                
                // Get current index
                let currentIndex = Int(lua_tointeger(L, 2))
                let nextIndex = currentIndex + 1
                
                // Check if we have more elements
                if let element = proxy.getElement(at: nextIndex) {
                    lua_pushinteger(L, lua_Integer(nextIndex))
                    Int.push(element, to: L)
                    return 2
                } else {
                    lua_pushnil(L)
                    return 1
                }
            }, 0)
            
            // Push the proxy object (state)
            lua_pushvalue(L, 1)
            
            // Push initial index (0)
            lua_pushinteger(L, 0)
            
            return 3
        }, 0)
        lua_settable(L, -3)
        
        // __tostring metamethod
        lua_pushstring(L, "__tostring")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let proxy = LuaIntArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            let array = proxy.toArray()
            let elementStrings = array.map { String($0) }
            let arrayString = "[\(elementStrings.joined(separator: ", "))]"
            lua_pushstring(L, arrayString)
            return 1
        }, 0)
        lua_settable(L, -3)
    }
}

// MARK: - Concrete Double Array Proxy

public final class LuaDoubleArrayProxy: LuaArrayProxy<Double>, LuaBridgeable {
    public static func luaNew(_ L: OpaquePointer) -> Int32 {
        // Array proxies are not directly constructible from Lua
        return luaError(L, "LuaDoubleArrayProxy cannot be constructed directly")
    }
    
    public static func registerConstructor(_ L: OpaquePointer, name: String) {
        // No constructor needed
    }
    
    public static func registerMethods(_ L: OpaquePointer) {
        // __index metamethod for element access
        lua_pushstring(L, "__index")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Get the proxy object
            guard let proxy = LuaDoubleArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            
            // Check if key is a number (array index)
            if lua_type(L, 2) == LUA_TNUMBER {
                let index = Int(lua_tointeger(L, 2))
                if let element = proxy.getElement(at: index) {
                    Double.push(element, to: L)
                    return 1
                } else {
                    lua_pushnil(L)
                    return 1
                }
            }
            
            // Check for special methods
            if let key = String.pull(from: L, at: 2) {
                switch key {
                case "length", "count":
                    lua_pushinteger(L, lua_Integer(proxy.getLength()))
                    return 1
                case "toArray":
                    // Return the array directly
                    [Double].push(proxy.toArray(), to: L)
                    return 1
                default:
                    lua_pushnil(L)
                    return 1
                }
            }
            
            lua_pushnil(L)
            return 1
        }, 0)
        lua_settable(L, -3)
        
        // __newindex metamethod for element assignment
        lua_pushstring(L, "__newindex")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Get the proxy object
            guard let proxy = LuaDoubleArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            
            // Index must be a number
            guard lua_type(L, 2) == LUA_TNUMBER else {
                return luaError(L, "Array index must be a number")
            }
            
            let index = Int(lua_tointeger(L, 2))
            
            // Get the new value
            guard let newValue = Double.pull(from: L, at: 3) else {
                return luaError(L, "Invalid value type for array element")
            }
            
            // Set the element
            do {
                try proxy.setElement(at: index, to: newValue)
            } catch let error as PropertyValidationError {
                return luaError(L, error.message)
            } catch {
                return luaError(L, "Failed to set array element: \(error)")
            }
            
            return 0
        }, 0)
        lua_settable(L, -3)
        
        // __len metamethod for # operator
        lua_pushstring(L, "__len")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let proxy = LuaDoubleArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            lua_pushinteger(L, lua_Integer(proxy.getLength()))
            return 1
        }, 0)
        lua_settable(L, -3)
        
        // __ipairs metamethod for iteration
        lua_pushstring(L, "__ipairs")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Push iterator function
            lua_pushcclosure(L, { L in
                guard let L = L else { return 0 }
                
                // Get the proxy (first upvalue of ipairs)
                guard let proxy = LuaDoubleArrayProxy.checkUserdata(L, at: 1) else {
                    return luaError(L, "Invalid array proxy")
                }
                
                // Get current index
                let currentIndex = Int(lua_tointeger(L, 2))
                let nextIndex = currentIndex + 1
                
                // Check if we have more elements
                if let element = proxy.getElement(at: nextIndex) {
                    lua_pushinteger(L, lua_Integer(nextIndex))
                    Double.push(element, to: L)
                    return 2
                } else {
                    lua_pushnil(L)
                    return 1
                }
            }, 0)
            
            // Push the proxy object (state)
            lua_pushvalue(L, 1)
            
            // Push initial index (0)
            lua_pushinteger(L, 0)
            
            return 3
        }, 0)
        lua_settable(L, -3)
        
        // __tostring metamethod
        lua_pushstring(L, "__tostring")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let proxy = LuaDoubleArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            let array = proxy.toArray()
            let elementStrings = array.map { String($0) }
            let arrayString = "[\(elementStrings.joined(separator: ", "))]"
            lua_pushstring(L, arrayString)
            return 1
        }, 0)
        lua_settable(L, -3)
    }
}

// MARK: - Concrete Bool Array Proxy

public final class LuaBoolArrayProxy: LuaArrayProxy<Bool>, LuaBridgeable {
    public static func luaNew(_ L: OpaquePointer) -> Int32 {
        // Array proxies are not directly constructible from Lua
        return luaError(L, "LuaBoolArrayProxy cannot be constructed directly")
    }
    
    public static func registerConstructor(_ L: OpaquePointer, name: String) {
        // No constructor needed
    }
    
    public static func registerMethods(_ L: OpaquePointer) {
        // __index metamethod for element access
        lua_pushstring(L, "__index")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Get the proxy object
            guard let proxy = LuaBoolArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            
            // Check if key is a number (array index)
            if lua_type(L, 2) == LUA_TNUMBER {
                let index = Int(lua_tointeger(L, 2))
                if let element = proxy.getElement(at: index) {
                    Bool.push(element, to: L)
                    return 1
                } else {
                    lua_pushnil(L)
                    return 1
                }
            }
            
            // Check for special methods
            if let key = String.pull(from: L, at: 2) {
                switch key {
                case "length", "count":
                    lua_pushinteger(L, lua_Integer(proxy.getLength()))
                    return 1
                case "toArray":
                    // Return the array directly
                    [Bool].push(proxy.toArray(), to: L)
                    return 1
                default:
                    lua_pushnil(L)
                    return 1
                }
            }
            
            lua_pushnil(L)
            return 1
        }, 0)
        lua_settable(L, -3)
        
        // __newindex metamethod for element assignment
        lua_pushstring(L, "__newindex")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Get the proxy object
            guard let proxy = LuaBoolArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            
            // Index must be a number
            guard lua_type(L, 2) == LUA_TNUMBER else {
                return luaError(L, "Array index must be a number")
            }
            
            let index = Int(lua_tointeger(L, 2))
            
            // Get the new value
            guard let newValue = Bool.pull(from: L, at: 3) else {
                return luaError(L, "Invalid value type for array element")
            }
            
            // Set the element
            do {
                try proxy.setElement(at: index, to: newValue)
            } catch let error as PropertyValidationError {
                return luaError(L, error.message)
            } catch {
                return luaError(L, "Failed to set array element: \(error)")
            }
            
            return 0
        }, 0)
        lua_settable(L, -3)
        
        // __len metamethod for # operator
        lua_pushstring(L, "__len")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let proxy = LuaBoolArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            lua_pushinteger(L, lua_Integer(proxy.getLength()))
            return 1
        }, 0)
        lua_settable(L, -3)
        
        // __ipairs metamethod for iteration
        lua_pushstring(L, "__ipairs")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            
            // Push iterator function
            lua_pushcclosure(L, { L in
                guard let L = L else { return 0 }
                
                // Get the proxy (first upvalue of ipairs)
                guard let proxy = LuaBoolArrayProxy.checkUserdata(L, at: 1) else {
                    return luaError(L, "Invalid array proxy")
                }
                
                // Get current index
                let currentIndex = Int(lua_tointeger(L, 2))
                let nextIndex = currentIndex + 1
                
                // Check if we have more elements
                if let element = proxy.getElement(at: nextIndex) {
                    lua_pushinteger(L, lua_Integer(nextIndex))
                    Bool.push(element, to: L)
                    return 2
                } else {
                    lua_pushnil(L)
                    return 1
                }
            }, 0)
            
            // Push the proxy object (state)
            lua_pushvalue(L, 1)
            
            // Push initial index (0)
            lua_pushinteger(L, 0)
            
            return 3
        }, 0)
        lua_settable(L, -3)
        
        // __tostring metamethod
        lua_pushstring(L, "__tostring")
        lua_pushcclosure(L, { L in
            guard let L = L else { return 0 }
            guard let proxy = LuaBoolArrayProxy.checkUserdata(L, at: 1) else {
                return luaError(L, "Invalid array proxy")
            }
            let array = proxy.toArray()
            let elementStrings = array.map { $0 ? "true" : "false" }
            let arrayString = "[\(elementStrings.joined(separator: ", "))]"
            lua_pushstring(L, arrayString)
            return 1
        }, 0)
        lua_settable(L, -3)
    }
}