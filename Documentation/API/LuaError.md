# LuaError

Error types that can be thrown by LuaKit operations.

## Declaration

```swift
public enum LuaError: LocalizedError {
    case syntax(String)
    case runtime(String)
    case typeMismatch(expected: String, got: String)
    case memoryAllocation
    case scriptNotFound(String)
    case invalidArgument(String)
}
```

## Cases

### syntax(_:)

Indicates a Lua syntax error in the provided code.

```swift
case syntax(String)
```

**Associated Value**: Error message describing the syntax error

**Common Causes**:
- Missing `end` keywords
- Unmatched parentheses or brackets
- Invalid Lua syntax
- Typos in keywords

**Example**:
```swift
do {
    try lua.execute("if true then print('hello'")  // Missing 'end'
} catch LuaError.syntax(let message) {
    print("Syntax error: \(message)")
    // Output: Syntax error: [string "if true then print('hello'"]:1: 'end' expected
}
```

### runtime(_:)

Indicates an error that occurred during Lua code execution.

```swift
case runtime(String)
```

**Associated Value**: Error message describing the runtime error

**Common Causes**:
- Calling nil values
- Accessing undefined variables
- Type errors in operations
- Stack overflow
- Custom Lua errors

**Example**:
```swift
do {
    try lua.execute("nonexistent_function()")
} catch LuaError.runtime(let message) {
    print("Runtime error: \(message)")
    // Output: Runtime error: attempt to call a nil value (global 'nonexistent_function')
}
```

### typeMismatch(expected:got:)

Indicates a type conversion error between Swift and Lua.

```swift
case typeMismatch(expected: String, got: String)
```

**Associated Values**:
- `expected`: The Swift type that was expected
- `got`: The actual Lua type encountered

**Common Causes**:
- Trying to get a String when Lua has a number
- Expecting an object but getting nil
- Array type mismatches

**Example**:
```swift
do {
    lua.globals["myValue"] = "not a number"
    let number: Int = try lua.executeReturning("return myValue")
} catch LuaError.typeMismatch(let expected, let got) {
    print("Type mismatch: expected \(expected), got \(got)")
    // Output: Type mismatch: expected Int, got string
}
```

### memoryAllocation

Indicates that Lua could not allocate memory.

```swift
case memoryAllocation
```

**Common Causes**:
- System out of memory
- Lua state creation failed
- Memory limits exceeded

**Example**:
```swift
do {
    let lua = try LuaState()
} catch LuaError.memoryAllocation {
    print("Failed to create Lua state: out of memory")
}
```

### scriptNotFound(_:)

Indicates that a requested script file was not found.

```swift
case scriptNotFound(String)
```

**Associated Value**: Path to the missing script file

**Note**: This error is not thrown by core LuaKit but may be used by extensions.

### invalidArgument(_:)

Indicates an invalid argument was passed to a LuaKit function.

```swift
case invalidArgument(String)
```

**Associated Value**: Description of the invalid argument

**Note**: This error is not thrown by core LuaKit but may be used by extensions.

## Error Descriptions

`LuaError` conforms to `LocalizedError`, providing human-readable error descriptions:

```swift
extension LuaError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .syntax(let message):
            return "Lua syntax error: \(message)"
        case .runtime(let message):
            return "Lua runtime error: \(message)"
        case .typeMismatch(let expected, let got):
            return "Type mismatch: expected \(expected), got \(got)"
        case .memoryAllocation:
            return "Failed to allocate memory for Lua state"
        case .scriptNotFound(let path):
            return "Script not found: \(path)"
        case .invalidArgument(let message):
            return "Invalid argument: \(message)"
        }
    }
}
```

## Error Handling Patterns

### Basic Error Handling

```swift
do {
    let result = try lua.execute(userScript)
    print("Success: \(result)")
} catch {
    print("Error: \(error.localizedDescription)")
}
```

### Specific Error Handling

```swift
do {
    try lua.execute(userScript)
} catch LuaError.syntax(let message) {
    // Show syntax error to user with line number
    showSyntaxError(message)
} catch LuaError.runtime(let message) {
    // Log runtime error and possibly recover
    logger.error("Lua runtime error: \(message)")
    // Attempt recovery...
} catch LuaError.typeMismatch(let expected, let got) {
    // Handle type conversion issues
    print("Cannot convert \(got) to \(expected)")
} catch {
    // Handle unexpected errors
    print("Unexpected error: \(error)")
}
```

### Error Recovery

```swift
func executeScriptSafely(_ script: String) -> String {
    do {
        return try lua.execute(script)
    } catch LuaError.syntax(let message) {
        return "Syntax error: Please check your script. \(message)"
    } catch LuaError.runtime(let message) {
        // Try to extract useful info from the error
        if message.contains("nil value") {
            return "Error: Trying to use an undefined variable or function"
        }
        return "Runtime error: \(message)"
    } catch {
        return "An unexpected error occurred"
    }
}
```

### Validation Before Execution

```swift
func validateScript(_ script: String) -> Result<Void, LuaError> {
    do {
        // Try to load without executing
        try lua.execute("return function() \(script) end")
        return .success(())
    } catch let error as LuaError {
        return .failure(error)
    } catch {
        return .failure(.runtime("Unknown error"))
    }
}
```

## Best Practices

### 1. Always Handle Errors

Never ignore potential errors when executing user-provided scripts:

```swift
// ❌ Bad
try! lua.execute(userScript)

// ✅ Good
do {
    try lua.execute(userScript)
} catch {
    handleError(error)
}
```

### 2. Provide User-Friendly Messages

```swift
func friendlyError(from error: Error) -> String {
    guard let luaError = error as? LuaError else {
        return "An unexpected error occurred"
    }
    
    switch luaError {
    case .syntax(let msg):
        // Extract line number if present
        if let match = msg.range(of: #"]:(\d+):"#, options: .regularExpression) {
            let lineNum = String(msg[match])
            return "Syntax error on line \(lineNum)"
        }
        return "Please check your script syntax"
        
    case .runtime(let msg):
        if msg.contains("stack overflow") {
            return "Script is too complex or has infinite recursion"
        }
        return "Script error: \(msg)"
        
    case .typeMismatch(let expected, _):
        return "Wrong value type, expected: \(expected)"
        
    default:
        return error.localizedDescription
    }
}
```

### 3. Log Errors for Debugging

```swift
func executeWithLogging(_ script: String) throws {
    do {
        try lua.execute(script)
    } catch {
        logger.error("Script execution failed", metadata: [
            "script": .string(script),
            "error": .string(error.localizedDescription)
        ])
        throw error
    }
}
```

### 4. Sandbox User Scripts

Prevent runtime errors by sandboxing:

```swift
func setupSandbox() throws {
    try lua.execute("""
        -- Remove dangerous functions
        os.execute = nil
        io = nil
        loadfile = nil
        dofile = nil
        
        -- Add safety checks
        local original_require = require
        require = function(module)
            if module == "os" or module == "io" then
                error("Module '" .. module .. "' is not allowed")
            end
            return original_require(module)
        end
    """)
}
```