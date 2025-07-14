# Error Handling in LuaKit

This guide covers comprehensive error handling strategies when working with LuaKit, including syntax errors, runtime errors, type mismatches, and best practices for robust applications.

## Understanding LuaKit Errors

### Error Types

LuaKit defines several error types in the `LuaError` enum:

```swift
public enum LuaError: LocalizedError {
    case syntax(String)                              // Syntax errors in Lua code
    case runtime(String)                             // Runtime execution errors
    case typeMismatch(expected: String, got: String) // Type conversion errors
    case memoryAllocation                            // Memory allocation failures
    case scriptNotFound(String)                      // Script file not found
    case invalidArgument(String)                     // Invalid arguments
}
```

### Basic Error Handling

```swift
do {
    let result = try lua.execute("return 1 + 2")
    print("Success: \(result)")
} catch let error as LuaError {
    switch error {
    case .syntax(let message):
        print("Syntax error: \(message)")
    case .runtime(let message):
        print("Runtime error: \(message)")
    case .typeMismatch(let expected, let got):
        print("Type error: expected \(expected), got \(got)")
    default:
        print("Other error: \(error)")
    }
} catch {
    print("Unexpected error: \(error)")
}
```

## Handling Syntax Errors

### Common Syntax Errors

```swift
// Missing 'end' keyword
do {
    try lua.execute("""
        if true then
            print("Hello")
        -- Missing 'end'
    """)
} catch LuaError.syntax(let message) {
    print("Syntax error: \(message)")
    // Output: Syntax error: [string "..."]:3: 'end' expected (to close 'if' at line 1)
}

// Unmatched brackets
do {
    try lua.execute("local t = {1, 2, 3")  // Missing closing brace
} catch LuaError.syntax(let message) {
    print("Syntax error: \(message)")
    // Output: Syntax error: [string "local t = {1, 2, 3"]:1: '}' expected
}
```

### Extracting Error Information

```swift
extension LuaError {
    var lineNumber: Int? {
        guard case .syntax(let message) = self else { return nil }
        
        // Extract line number from error message
        // Format: [string "..."]:LINE: error description
        let pattern = #"\]:(\d+):"#
        
        if let range = message.range(of: pattern, options: .regularExpression),
           let match = message[range].dropFirst(2).dropLast().first {
            return Int(String(match))
        }
        
        return nil
    }
}

// Usage
do {
    try lua.execute("if true then")
} catch let error as LuaError {
    if let line = error.lineNumber {
        print("Error on line \(line)")
    }
}
```

## Handling Runtime Errors

### Common Runtime Errors

```swift
// Nil value access
do {
    try lua.execute("local x = nil; x.property = 5")
} catch LuaError.runtime(let message) {
    print("Runtime error: \(message)")
    // Output: attempt to index a nil value (local 'x')
}

// Undefined function
do {
    try lua.execute("nonExistentFunction()")
} catch LuaError.runtime(let message) {
    print("Runtime error: \(message)")
    // Output: attempt to call a nil value (global 'nonExistentFunction')
}

// Division by zero
do {
    try lua.execute("local x = 1/0; print(x)")
    // Note: Lua allows division by zero (results in inf)
} catch {
    // This actually won't error in Lua
}
```

### Stack Overflow Protection

```swift
// Infinite recursion
do {
    try lua.execute("""
        function infinite()
            infinite()
        end
        infinite()
    """)
} catch LuaError.runtime(let message) {
    if message.contains("stack overflow") {
        print("Stack overflow detected - check for infinite recursion")
    }
}
```

## Type Mismatch Errors

### Type Conversion Failures

```swift
// Setting wrong type
lua.globals["myNumber"] = "not a number"

do {
    let value: Int = try lua.executeReturning("return myNumber")
} catch LuaError.typeMismatch(let expected, let got) {
    print("Cannot convert \(got) to \(expected)")
    // Output: Cannot convert string to Int
}

// Array type mismatch
lua.globals["mixedArray"] = [1, "two", 3]

do {
    let numbers: [Int] = lua.globals["mixedArray"] ?? []
} catch {
    print("Array contains mixed types")
}
```

### Safe Type Conversion

```swift
extension LuaState {
    func getSafeGlobal<T>(_ name: String, default defaultValue: T) -> T {
        return globals[name] ?? defaultValue
    }
    
    func getGlobalString(_ name: String) -> String {
        if let string: String = globals[name] {
            return string
        } else if let number: Double = globals[name] {
            return String(number)
        } else if let bool: Bool = globals[name] {
            return bool ? "true" : "false"
        } else {
            return ""
        }
    }
}
```

## Validation and Prevention

### Script Validation

```swift
extension LuaState {
    /// Validates Lua syntax without executing
    func validate(_ code: String) -> Result<Void, LuaError> {
        do {
            // Load as function to check syntax
            try execute("return function() \n\(code)\n end")
            return .success(())
        } catch let error as LuaError {
            return .failure(error)
        } catch {
            return .failure(.runtime("Unknown validation error"))
        }
    }
}

// Usage
let script = """
    if x > 10 then
        print("Large")
    -- Missing 'end'
"""

switch lua.validate(script) {
case .success:
    print("Script is valid")
case .failure(let error):
    print("Invalid script: \(error)")
}
```

### Input Sanitization

```swift
extension String {
    /// Escapes string for safe use in Lua
    var luaEscaped: String {
        return self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}

// Safe string injection
let userInput = "User's \"input\" with\nnewlines"
let safeScript = """
    local message = "\(userInput.luaEscaped)"
    print(message)
"""
try lua.execute(safeScript)
```

## Error Recovery Strategies

### Fallback Values

```swift
func executeWithFallback(_ code: String, fallback: String = "") -> String {
    do {
        return try lua.execute(code)
    } catch LuaError.syntax(_) {
        print("Syntax error - using fallback")
        return fallback
    } catch LuaError.runtime(_) {
        print("Runtime error - using fallback")
        return fallback
    } catch {
        print("Unexpected error - using fallback")
        return fallback
    }
}
```

### Retry Logic

```swift
func executeWithRetry(_ code: String, maxAttempts: Int = 3) throws -> String {
    var lastError: Error?
    
    for attempt in 1...maxAttempts {
        do {
            return try lua.execute(code)
        } catch LuaError.runtime(let message) where message.contains("temporary") {
            // Retry temporary failures
            lastError = LuaError.runtime(message)
            print("Attempt \(attempt) failed, retrying...")
            Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
        } catch {
            // Don't retry other errors
            throw error
        }
    }
    
    throw lastError ?? LuaError.runtime("Max retries exceeded")
}
```

### Graceful Degradation

```swift
@LuaBridgeable
class ScriptableComponent: LuaBridgeable {
    var useScripting = true
    
    func performAction() {
        if useScripting {
            do {
                try lua.execute("performCustomAction()")
            } catch {
                print("Script failed, falling back to default behavior")
                useScripting = false
                performDefaultAction()
            }
        } else {
            performDefaultAction()
        }
    }
    
    private func performDefaultAction() {
        print("Performing default action")
    }
}
```

## Sandboxing for Safety

### Remove Dangerous Functions

```swift
func createSafeLuaEnvironment() throws -> LuaState {
    let lua = try LuaState()
    
    // Remove potentially dangerous functions
    try lua.execute("""
        -- File system access
        io = nil
        os.execute = nil
        os.remove = nil
        os.rename = nil
        
        -- Module loading
        require = nil
        loadfile = nil
        dofile = nil
        load = nil
        
        -- Keep safe functions
        os.time = os.time
        os.date = os.date
        os.clock = os.clock
    """)
    
    return lua
}
```

### Resource Limits

```swift
class LimitedLuaState {
    private let lua: LuaState
    private var executionCount = 0
    private let maxExecutions = 1000
    
    init() throws {
        lua = try LuaState()
        setupHooks()
    }
    
    private func setupHooks() {
        // This is conceptual - actual implementation would use Lua debug hooks
        // to limit execution time and memory usage
    }
    
    func execute(_ code: String) throws -> String {
        guard executionCount < maxExecutions else {
            throw LuaError.runtime("Execution limit exceeded")
        }
        
        executionCount += 1
        
        // Add timeout using GCD
        let result = try withTimeout(seconds: 5.0) {
            try self.lua.execute(code)
        }
        
        return result
    }
}

func withTimeout<T>(seconds: TimeInterval, operation: @escaping () throws -> T) throws -> T {
    // Timeout implementation
}
```

## Error Reporting

### User-Friendly Messages

```swift
struct ErrorReporter {
    static func userMessage(for error: Error) -> String {
        guard let luaError = error as? LuaError else {
            return "An unexpected error occurred."
        }
        
        switch luaError {
        case .syntax(let details):
            if let line = extractLineNumber(from: details) {
                return "Syntax error on line \(line). Please check your script."
            }
            return "Invalid script syntax. Please check for missing keywords or brackets."
            
        case .runtime(let details):
            if details.contains("nil value") {
                return "Attempted to use an undefined variable or function."
            } else if details.contains("stack overflow") {
                return "Script is too complex or has infinite loops."
            }
            return "Script execution failed. Please check your logic."
            
        case .typeMismatch(let expected, let got):
            return "Wrong value type. Expected \(expected) but got \(got)."
            
        case .memoryAllocation:
            return "Not enough memory to run the script."
            
        default:
            return error.localizedDescription
        }
    }
    
    private static func extractLineNumber(from error: String) -> Int? {
        // Implementation as shown earlier
        return nil
    }
}
```

### Logging for Debugging

```swift
protocol ErrorLogger {
    func log(_ error: Error, context: [String: Any])
}

class ConsoleErrorLogger: ErrorLogger {
    func log(_ error: Error, context: [String: Any]) {
        print("=== LuaKit Error ===")
        print("Error: \(error)")
        print("Context:")
        for (key, value) in context {
            print("  \(key): \(value)")
        }
        
        if let luaError = error as? LuaError {
            print("Type: \(type(of: luaError))")
            print("Description: \(luaError.localizedDescription)")
        }
        
        print("==================")
    }
}

// Usage
let logger = ConsoleErrorLogger()

do {
    try lua.execute(userScript)
} catch {
    logger.log(error, context: [
        "script": userScript,
        "timestamp": Date(),
        "user": currentUser?.id ?? "anonymous"
    ])
}
```

## Best Practices

### 1. Always Handle User Input

```swift
func executeUserScript(_ script: String) -> Result<String, Error> {
    // Validate first
    switch lua.validate(script) {
    case .failure(let error):
        return .failure(error)
    case .success:
        break
    }
    
    // Execute with error handling
    do {
        let result = try lua.execute(script)
        return .success(result)
    } catch {
        return .failure(error)
    }
}
```

### 2. Provide Context in Errors

```swift
enum ScriptError: LocalizedError {
    case luaError(LuaError, script: String, line: Int?)
    
    var errorDescription: String? {
        switch self {
        case .luaError(let error, let script, let line):
            var description = "Script error: \(error.localizedDescription)"
            if let line = line {
                description += " (line \(line))"
            }
            return description
        }
    }
}
```

### 3. Test Error Paths

```swift
class LuaKitTests: XCTestCase {
    func testSyntaxError() {
        let lua = try! LuaState()
        
        XCTAssertThrowsError(try lua.execute("if true")) { error in
            guard case LuaError.syntax = error else {
                XCTFail("Expected syntax error")
                return
            }
        }
    }
    
    func testRuntimeError() {
        let lua = try! LuaState()
        
        XCTAssertThrowsError(try lua.execute("unknownFunction()")) { error in
            guard case LuaError.runtime = error else {
                XCTFail("Expected runtime error")
                return
            }
        }
    }
}
```

## Next Steps

- See [LuaError API Reference](../API/LuaError.md) for complete error type documentation
- Explore [Examples](../../Examples/) for error handling patterns
- Learn about [Sandboxing](Sandboxing.md) for secure script execution