# LuaKit 2.0 Phase 2 Examples

This document provides extensive examples for Phase 2 features: **LuaCallable**, **Nested Collections**, and **LuaTable Iteration**.

---

## Table of Contents

1. [LuaCallable - Calling Lua Functions from Swift](#luacallable---calling-lua-functions-from-swift)
   - [Basic Function Calls](#basic-function-calls)
   - [Functions with Arguments](#functions-with-arguments)
   - [Path-Based Function Lookup](#path-based-function-lookup)
   - [Error Handling](#callable-error-handling)
   - [Storing and Reusing Callables](#storing-and-reusing-callables)

2. [Nested Collections](#nested-collections)
   - [Nested Arrays](#nested-arrays)
   - [Dictionaries with Array Values](#dictionaries-with-array-values)
   - [Complex Nested Structures](#complex-nested-structures)
   - [Round-Trip Preservation](#round-trip-preservation)

3. [LuaTable Iteration](#luatable-iteration)
   - [Basic Iteration](#basic-iteration)
   - [Keys and Values Properties](#keys-and-values-properties)
   - [Table Properties](#table-properties)
   - [Filtering and Transforming](#filtering-and-transforming)
   - [Working with Mixed Tables](#working-with-mixed-tables)

---

## LuaCallable - Calling Lua Functions from Swift

`LuaCallable` allows you to get a reference to a Lua function and call it from Swift with full type safety.

### Basic Function Calls

```swift
import LuaKit

let lua = try LuaState()

// Define some Lua functions
try lua.execute("""
    function sayHello()
        return "Hello from Lua!"
    end

    function getNumber()
        return 42
    end

    function isReady()
        return true
    end
""")

// Get function references
let sayHello = try lua.getFunction("sayHello")
let getNumber = try lua.getFunction("getNumber")
let isReady = try lua.getFunction("isReady")

// Call with typed returns
let greeting: String = try sayHello.call()
print(greeting)  // Output: Hello from Lua!

let number: Int = try getNumber.call()
print(number)  // Output: 42

let ready: Bool = try isReady.call()
print(ready)  // Output: true
```

### Functions with Arguments

`LuaCallable` supports 0-6 parameters:

```swift
let lua = try LuaState()

try lua.execute("""
    -- 1 parameter
    function double(x)
        return x * 2
    end

    -- 2 parameters
    function add(a, b)
        return a + b
    end

    -- 3 parameters
    function clamp(value, min, max)
        if value < min then return min end
        if value > max then return max end
        return value
    end

    -- 4 parameters
    function createPoint(x, y, z, label)
        return {x = x, y = y, z = z, label = label}
    end

    -- 5 parameters
    function formatRecord(id, name, value, category, active)
        return string.format("[%d] %s: %.2f (%s) %s",
            id, name, value, category, active and "ON" or "OFF")
    end

    -- 6 parameters
    function buildQuery(table, field, op, value, orderBy, limit)
        return string.format("SELECT * FROM %s WHERE %s %s %s ORDER BY %s LIMIT %d",
            table, field, op, tostring(value), orderBy, limit)
    end
""")

// 1 parameter
let double = try lua.getFunction("double")
let doubled: Int = try double.call(21)
print(doubled)  // Output: 42

// 2 parameters
let add = try lua.getFunction("add")
let sum: Int = try add.call(10, 20)
print(sum)  // Output: 30

// 3 parameters
let clamp = try lua.getFunction("clamp")
let clamped: Int = try clamp.call(150, 0, 100)
print(clamped)  // Output: 100

// 4 parameters
let createPoint = try lua.getFunction("createPoint")
let point: [String: Any] = try createPoint.call(1.0, 2.0, 3.0, "origin")
print(point)  // Output: ["x": 1.0, "y": 2.0, "z": 3.0, "label": "origin"]

// 5 parameters
let formatRecord = try lua.getFunction("formatRecord")
let record: String = try formatRecord.call(1, "Widget", 29.99, "electronics", true)
print(record)  // Output: [1] Widget: 29.99 (electronics) ON

// 6 parameters
let buildQuery = try lua.getFunction("buildQuery")
let query: String = try buildQuery.call("users", "age", ">", 18, "name", 10)
print(query)  // Output: SELECT * FROM users WHERE age > 18 ORDER BY name LIMIT 10
```

### Void Return Functions

Use `callVoid()` when you don't need a return value:

```swift
let lua = try LuaState()

try lua.execute("""
    results = {}

    function logMessage(level, message)
        table.insert(results, "[" .. level .. "] " .. message)
    end

    function processData(a, b, c, d)
        table.insert(results, a + b + c + d)
    end
""")

let logMessage = try lua.getFunction("logMessage")
try logMessage.callVoid("INFO", "Application started")
try logMessage.callVoid("DEBUG", "Loading configuration")

let processData = try lua.getFunction("processData")
try processData.callVoid(1, 2, 3, 4)

// Check results
let results = lua.globals["results"] as? [Any]
print(results ?? [])  // Output: ["[INFO] Application started", "[DEBUG] Loading configuration", 10]
```

### Path-Based Function Lookup

Access functions inside tables using dot notation:

```swift
let lua = try LuaState()

try lua.execute("""
    -- Create module with functions
    Math = {
        add = function(a, b) return a + b end,
        subtract = function(a, b) return a - b end,
        multiply = function(a, b) return a * b end,
        divide = function(a, b)
            if b == 0 then error("Division by zero") end
            return a / b
        end
    }

    -- Nested modules
    Game = {
        Player = {
            create = function(name, level)
                return {name = name, level = level, health = 100}
            end,
            levelUp = function(player)
                player.level = player.level + 1
                return player.level
            end
        },
        Enemy = {
            spawn = function(type, x, y)
                return {type = type, x = x, y = y, alive = true}
            end
        }
    }

    -- Deeply nested
    App = {
        Services = {
            Database = {
                connect = function(host, port)
                    return "Connected to " .. host .. ":" .. port
                end
            }
        }
    }
""")

// Access module functions
let mathAdd = try lua.getFunction("Math.add")
let mathDivide = try lua.getFunction("Math.divide")

let sum: Int = try mathAdd.call(10, 20)
print(sum)  // Output: 30

let quotient: Double = try mathDivide.call(10.0, 4.0)
print(quotient)  // Output: 2.5

// Access nested module functions
let createPlayer = try lua.getFunction("Game.Player.create")
let spawnEnemy = try lua.getFunction("Game.Enemy.spawn")

let player: [String: Any] = try createPlayer.call("Hero", 1)
print(player)  // Output: ["name": "Hero", "level": 1, "health": 100]

let enemy: [String: Any] = try spawnEnemy.call("goblin", 100.0, 200.0)
print(enemy)  // Output: ["type": "goblin", "x": 100.0, "y": 200.0, "alive": true]

// Access deeply nested functions
let dbConnect = try lua.getFunction("App.Services.Database.connect")
let status: String = try dbConnect.call("localhost", 5432)
print(status)  // Output: Connected to localhost:5432
```

### Callable Error Handling

Handle errors gracefully:

```swift
let lua = try LuaState()

try lua.execute("""
    function safeDivide(a, b)
        if b == 0 then
            error("Cannot divide by zero!")
        end
        return a / b
    end

    function validateAge(age)
        if age < 0 then
            error("Age cannot be negative")
        end
        if age > 150 then
            error("Age seems unrealistic")
        end
        return true
    end
""")

let safeDivide = try lua.getFunction("safeDivide")
let validateAge = try lua.getFunction("validateAge")

// Successful calls
do {
    let result: Double = try safeDivide.call(10.0, 2.0)
    print("10 / 2 = \(result)")  // Output: 10 / 2 = 5.0
} catch {
    print("Error: \(error)")
}

// Error handling
do {
    let _: Double = try safeDivide.call(10.0, 0.0)
} catch let error as LuaError {
    switch error {
    case .runtime(let message):
        print("Runtime error: \(message)")
        // Output: Runtime error: ...Cannot divide by zero!
    default:
        print("Other error: \(error)")
    }
}

// Multiple validation errors
for age in [-5, 200, 25] {
    do {
        let _: Bool = try validateAge.call(age)
        print("Age \(age) is valid")
    } catch let error as LuaError {
        if case .runtime(let message) = error {
            print("Age \(age) failed: \(message)")
        }
    }
}
// Output:
// Age -5 failed: ...Age cannot be negative
// Age 200 failed: ...Age seems unrealistic
// Age 25 is valid

// Check if function exists
do {
    let _ = try lua.getFunction("nonExistent")
} catch LuaError.functionNotFound(let message) {
    print("Function not found: \(message)")
}
```

### Storing and Reusing Callables

`LuaCallable` can be stored and called multiple times:

```swift
let lua = try LuaState()

try lua.execute("""
    counter = 0
    function increment()
        counter = counter + 1
        return counter
    end

    function getCounter()
        return counter
    end

    function resetCounter()
        counter = 0
    end
""")

// Store function references
let increment = try lua.getFunction("increment")
let getCounter = try lua.getFunction("getCounter")
let resetCounter = try lua.getFunction("resetCounter")

// Use them multiple times
for _ in 1...5 {
    let _: Int = try increment.call()
}

let value: Int = try getCounter.call()
print("Counter: \(value)")  // Output: Counter: 5

try resetCounter.callVoid()
let afterReset: Int = try getCounter.call()
print("After reset: \(afterReset)")  // Output: After reset: 0

// Store in a class
class ScriptManager {
    let lua: LuaState
    let onUpdate: LuaCallable
    let onRender: LuaCallable

    init() throws {
        lua = try LuaState()
        try lua.execute("""
            frameCount = 0
            function onUpdate(deltaTime)
                frameCount = frameCount + 1
                return frameCount
            end

            function onRender()
                return "Rendering frame " .. frameCount
            end
        """)

        onUpdate = try lua.getFunction("onUpdate")
        onRender = try lua.getFunction("onRender")
    }

    func update(dt: Double) throws -> Int {
        return try onUpdate.call(dt)
    }

    func render() throws -> String {
        return try onRender.call()
    }
}

let manager = try ScriptManager()
for i in 1...3 {
    let frame: Int = try manager.update(dt: 0.016)
    let output: String = try manager.render()
    print("Frame \(frame): \(output)")
}
// Output:
// Frame 1: Rendering frame 1
// Frame 2: Rendering frame 2
// Frame 3: Rendering frame 3
```

---

## Nested Collections

LuaKit 2.0 fully supports nested arrays and dictionaries with array values.

### Nested Arrays

```swift
let lua = try LuaState()

// Push nested arrays to Lua
let matrix: [[Int]] = [
    [1, 2, 3],
    [4, 5, 6],
    [7, 8, 9]
]
lua.globals["matrix"] = matrix

// Access in Lua
try lua.execute("""
    print("Matrix dimensions: " .. #matrix .. " x " .. #matrix[1])

    -- Print the matrix
    for i, row in ipairs(matrix) do
        local rowStr = ""
        for j, val in ipairs(row) do
            rowStr = rowStr .. val .. " "
        end
        print(rowStr)
    end

    -- Calculate sum
    local sum = 0
    for i, row in ipairs(matrix) do
        for j, val in ipairs(row) do
            sum = sum + val
        end
    end
    matrixSum = sum
""")
// Output:
// Matrix dimensions: 3 x 3
// 1 2 3
// 4 5 6
// 7 8 9

print("Sum: \(lua.globals["matrixSum"] as? Int ?? 0)")  // Output: Sum: 45

// Read nested arrays back
let retrievedMatrix = lua.globals["matrix"] as? [[Int]]
print(retrievedMatrix ?? [])  // Output: [[1, 2, 3], [4, 5, 6], [7, 8, 9]]

// Deeper nesting
let cube: [[[Int]]] = [
    [[1, 2], [3, 4]],
    [[5, 6], [7, 8]]
]
lua.globals["cube"] = cube

try lua.execute("""
    print("Cube[1][1][1] = " .. cube[1][1][1])  -- 1
    print("Cube[2][2][2] = " .. cube[2][2][2])  -- 8
""")
```

### String Arrays

```swift
let lua = try LuaState()

// 2D string arrays
let grid: [[String]] = [
    ["A1", "B1", "C1"],
    ["A2", "B2", "C2"],
    ["A3", "B3", "C3"]
]
lua.globals["grid"] = grid

try lua.execute("""
    -- Access grid cells
    print("Center cell: " .. grid[2][2])  -- B2

    -- Modify and create new row
    grid[4] = {"A4", "B4", "C4"}
""")

// Nested string arrays (e.g., paragraphs of sentences)
let document: [[String]] = [
    ["Hello world.", "This is a test."],
    ["Second paragraph.", "More text here."]
]
lua.globals["document"] = document

try lua.execute("""
    for i, paragraph in ipairs(document) do
        print("Paragraph " .. i .. ":")
        for j, sentence in ipairs(paragraph) do
            print("  " .. sentence)
        end
    end
""")
```

### Dictionaries with Array Values

```swift
let lua = try LuaState()

// Dictionary with string array values
let tags: [String: [String]] = [
    "fruits": ["apple", "banana", "cherry"],
    "colors": ["red", "green", "blue"],
    "sizes": ["small", "medium", "large"]
]
lua.globals["tags"] = tags

try lua.execute("""
    -- Access arrays in dictionary
    print("Fruits: " .. table.concat(tags.fruits, ", "))
    print("First color: " .. tags.colors[1])

    -- Add new category
    tags.numbers = {"one", "two", "three"}
""")
// Output:
// Fruits: apple, banana, cherry
// First color: red

// Dictionary with integer array values
let scores: [String: [Int]] = [
    "alice": [95, 87, 92],
    "bob": [88, 91, 85],
    "charlie": [90, 93, 89]
]
lua.globals["scores"] = scores

try lua.execute("""
    -- Calculate averages
    for name, grades in pairs(scores) do
        local sum = 0
        for _, grade in ipairs(grades) do
            sum = sum + grade
        end
        local avg = sum / #grades
        print(name .. ": " .. string.format("%.1f", avg))
    end
""")

// Read back
let retrievedScores = lua.globals["scores"] as? [String: [Int]]
print(retrievedScores?["alice"] ?? [])  // Output: [95, 87, 92]
```

### Complex Nested Structures

```swift
let lua = try LuaState()

// Complex nested structure
let gameData: [String: Any] = [
    "players": [
        ["name": "Alice", "scores": [100, 200, 150]],
        ["name": "Bob", "scores": [180, 220, 190]]
    ],
    "levels": [
        ["id": 1, "enemies": ["goblin", "orc"]],
        ["id": 2, "enemies": ["dragon", "troll", "witch"]]
    ],
    "settings": [
        "difficulty": "hard",
        "volumes": [0.8, 0.6, 1.0]  // music, sfx, voice
    ]
]
lua.globals["gameData"] = gameData

try lua.execute("""
    -- Access nested data
    print("First player: " .. gameData.players[1].name)
    print("Their scores: " .. table.concat(gameData.players[1].scores, ", "))

    -- Access level enemies
    print("Level 2 enemies:")
    for _, enemy in ipairs(gameData.levels[2].enemies) do
        print("  - " .. enemy)
    end

    -- Access settings
    print("Difficulty: " .. gameData.settings.difficulty)
    print("Music volume: " .. gameData.settings.volumes[1])
""")
// Output:
// First player: Alice
// Their scores: 100, 200, 150
// Level 2 enemies:
//   - dragon
//   - troll
//   - witch
// Difficulty: hard
// Music volume: 0.8
```

### Round-Trip Preservation

Data structure is preserved when passing to Lua and back:

```swift
let lua = try LuaState()

// Original data
let original: [[Int]] = [[1, 2, 3], [4, 5, 6]]
lua.globals["data"] = original

// Modify in Lua
try lua.execute("""
    -- Double all values
    for i, row in ipairs(data) do
        for j, val in ipairs(row) do
            data[i][j] = val * 2
        end
    end
""")

// Read back
let modified = lua.globals["data"] as? [[Int]]
print(modified ?? [])  // Output: [[2, 4, 6], [8, 10, 12]]

// Type preservation with function calls
try lua.execute("""
    function processMatrix(m)
        -- Add 1 to each element
        for i, row in ipairs(m) do
            for j, val in ipairs(row) do
                m[i][j] = val + 1
            end
        end
        return m
    end
""")

let processMatrix = try lua.getFunction("processMatrix")
let input: [[Int]] = [[10, 20], [30, 40]]
let output: [[Int]] = try processMatrix.call(input)
print(output)  // Output: [[11, 21], [31, 41]]
```

---

## LuaTable Iteration

`LuaTable` now conforms to `Sequence`, enabling Swift iteration patterns.

### Basic Iteration

```swift
let lua = try LuaState()

try lua.execute("""
    config = {
        host = "localhost",
        port = 8080,
        debug = true,
        timeout = 30.5
    }
""")

let configTable = lua.getTable("config")!

// Iterate with for-in
print("Configuration:")
for (key, value) in configTable {
    print("  \(key): \(value)")
}
// Output:
// Configuration:
//   host: string("localhost")
//   port: integer(8080)
//   debug: boolean(true)
//   timeout: number(30.5)

// Iterate array-like table
try lua.execute("numbers = {10, 20, 30, 40, 50}")
let numbersTable = lua.getTable("numbers")!

print("Numbers:")
for (key, value) in numbersTable {
    print("  [\(key)] = \(value)")
}
// Output:
// Numbers:
//   [integer(1)] = integer(10)
//   [integer(2)] = integer(20)
//   ...
```

### Keys and Values Properties

```swift
let lua = try LuaState()

try lua.execute("""
    user = {
        name = "Alice",
        email = "alice@example.com",
        age = 30
    }
""")

let userTable = lua.getTable("user")!

// Get all keys
let keys = userTable.keys
print("Keys: \(keys)")
// Output: Keys: [string("name"), string("email"), string("age")]

// Get all values
let values = userTable.values
print("Values: \(values)")
// Output: Values: [string("Alice"), string("alice@example.com"), integer(30)]

// Convert to string keys for processing
let stringKeys = keys.compactMap { key -> String? in
    if case .string(let s) = key { return s }
    return nil
}
print("String keys: \(stringKeys)")
// Output: String keys: ["name", "email", "age"]
```

### Table Properties

```swift
let lua = try LuaState()

try lua.execute("""
    emptyTable = {}
    smallTable = {1, 2, 3}
    largeTable = {}
    for i = 1, 100 do
        largeTable[i] = i * 2
    end
""")

// Count property
let empty = lua.getTable("emptyTable")!
let small = lua.getTable("smallTable")!
let large = lua.getTable("largeTable")!

print("Empty count: \(empty.count)")   // Output: 0
print("Small count: \(small.count)")   // Output: 3
print("Large count: \(large.count)")   // Output: 100

// isEmpty property
print("Empty isEmpty: \(empty.isEmpty)")  // Output: true
print("Small isEmpty: \(small.isEmpty)")  // Output: false

// Contains methods
try lua.execute("""
    lookup = {
        apple = "red",
        banana = "yellow",
        grape = "purple"
    }
""")

let lookup = lua.getTable("lookup")!
print("Has 'apple': \(lookup.contains(key: "apple"))")     // Output: true
print("Has 'orange': \(lookup.contains(key: "orange"))")   // Output: false

// For arrays, check index
try lua.execute("arr = {'a', 'b', 'c'}")
let arr = lua.getTable("arr")!
print("Has index 1: \(arr.contains(index: 1))")  // Output: true
print("Has index 5: \(arr.contains(index: 5))")  // Output: false
```

### Filtering and Transforming

```swift
let lua = try LuaState()

try lua.execute("""
    products = {
        {name = "Apple", price = 1.20, category = "fruit"},
        {name = "Bread", price = 2.50, category = "bakery"},
        {name = "Milk", price = 3.00, category = "dairy"},
        {name = "Banana", price = 0.80, category = "fruit"},
        {name = "Cheese", price = 5.00, category = "dairy"}
    }
""")

let productsTable = lua.getTable("products")!

// Filter to get fruit products
let fruits = productsTable.compactMap { (_, value) -> [String: Any]? in
    guard case .table(let product) = value else { return nil }
    if (product["category"] as? String) == "fruit" {
        return product.toDictionary()
    }
    return nil
}
print("Fruits: \(fruits)")

// Calculate total price
var total = 0.0
for (_, value) in productsTable {
    if case .table(let product) = value {
        if let price = product["price"] as? Double {
            total += price
        }
    }
}
print("Total: $\(total)")  // Output: Total: $12.5

// Extract all names
let names = productsTable.compactMap { (_, value) -> String? in
    guard case .table(let product) = value else { return nil }
    return product["name"] as? String
}
print("Products: \(names.joined(separator: ", "))")
// Output: Products: Apple, Bread, Milk, Banana, Cheese
```

### Working with Mixed Tables

Lua tables can have both array and dictionary parts:

```swift
let lua = try LuaState()

try lua.execute("""
    mixed = {
        "first",           -- [1]
        "second",          -- [2]
        "third",           -- [3]
        name = "myTable",  -- string key
        count = 3          -- string key
    }
""")

let mixed = lua.getTable("mixed")!

print("Total entries: \(mixed.count)")

// Separate numeric and string keys
var arrayPart: [(Int, String)] = []
var dictPart: [(String, Any)] = []

for (key, value) in mixed {
    switch key {
    case .integer(let i):
        if case .string(let s) = value {
            arrayPart.append((Int(i), s))
        }
    case .string(let k):
        switch value {
        case .string(let s):
            dictPart.append((k, s))
        case .integer(let i):
            dictPart.append((k, Int(i)))
        default:
            break
        }
    default:
        break
    }
}

print("Array part: \(arrayPart)")
// Output: Array part: [(1, "first"), (2, "second"), (3, "third")]

print("Dict part: \(dictPart)")
// Output: Dict part: [("name", "myTable"), ("count", 3)]
```

### Practical Example: Processing Lua Configuration

```swift
let lua = try LuaState()

// Load a configuration file
try lua.execute("""
    config = {
        server = {
            host = "api.example.com",
            port = 443,
            ssl = true
        },
        database = {
            hosts = {"db1.local", "db2.local", "db3.local"},
            port = 5432,
            poolSize = 10
        },
        features = {
            darkMode = true,
            beta = false,
            experimental = {"feature1", "feature2"}
        },
        logging = {
            level = "debug",
            outputs = {"console", "file", "remote"}
        }
    }
""")

// Process configuration
func processConfig(_ table: LuaTable, indent: String = "") {
    for (key, value) in table {
        let keyStr: String
        switch key {
        case .string(let s): keyStr = s
        case .integer(let i): keyStr = "[\(i)]"
        default: continue
        }

        switch value {
        case .string(let s):
            print("\(indent)\(keyStr): \"\(s)\"")
        case .integer(let i):
            print("\(indent)\(keyStr): \(i)")
        case .boolean(let b):
            print("\(indent)\(keyStr): \(b)")
        case .number(let n):
            print("\(indent)\(keyStr): \(n)")
        case .table(let nested):
            print("\(indent)\(keyStr):")
            processConfig(nested, indent: indent + "  ")
        default:
            print("\(indent)\(keyStr): <\(value)>")
        }
    }
}

let config = lua.getTable("config")!
print("Configuration:")
processConfig(config)

// Output:
// Configuration:
// server:
//   host: "api.example.com"
//   port: 443
//   ssl: true
// database:
//   hosts:
//     [1]: "db1.local"
//     [2]: "db2.local"
//     [3]: "db3.local"
//   port: 5432
//   poolSize: 10
// ...
```

---

## Complete Example: Plugin System

Here's a complete example combining all Phase 2 features:

```swift
import LuaKit

class PluginSystem {
    let lua: LuaState
    private var plugins: [String: LuaCallable] = [:]

    init() throws {
        lua = try LuaState()
        setupEnvironment()
    }

    private func setupEnvironment() {
        // Register plugin API
        lua.register(function: "registerPlugin") { [weak self] (name: String) -> Bool in
            guard let self = self else { return false }

            // Get the plugin's init function
            do {
                let initFunc = try self.lua.getFunction("\(name).init")
                self.plugins[name] = initFunc
                print("Registered plugin: \(name)")
                return true
            } catch {
                print("Failed to register \(name): \(error)")
                return false
            }
        }
    }

    func loadPlugin(_ code: String) throws {
        try lua.execute(code)
    }

    func initializePlugins(config: [String: [String: Any]]) throws {
        // Convert config to nested structure for Lua
        for (pluginName, pluginConfig) in config {
            if let initFunc = plugins[pluginName] {
                // Pass configuration as nested dictionary
                let _: Bool = try initFunc.call(pluginConfig)
                print("Initialized \(pluginName)")
            }
        }
    }

    func listPlugins() {
        let pluginsTable = lua.getTable("_plugins") ?? lua.getTable("plugins")

        if let table = pluginsTable {
            print("Loaded plugins:")
            for (key, value) in table {
                print("  - \(key): \(value)")
            }
        }
    }
}

// Usage
let system = try PluginSystem()

// Load a plugin
try system.loadPlugin("""
    Logger = {
        level = "info",
        outputs = {},

        init = function(config)
            Logger.level = config.level or "info"
            Logger.outputs = config.outputs or {"console"}
            print("Logger initialized with level: " .. Logger.level)
            return true
        end,

        log = function(level, message)
            if Logger.shouldLog(level) then
                for _, output in ipairs(Logger.outputs) do
                    print("[" .. output .. "] " .. level .. ": " .. message)
                end
            end
        end,

        shouldLog = function(level)
            local levels = {debug = 1, info = 2, warn = 3, error = 4}
            return (levels[level] or 0) >= (levels[Logger.level] or 0)
        end
    }

    registerPlugin("Logger")
""")

// Initialize with nested config
try system.initializePlugins(config: [
    "Logger": [
        "level": "debug",
        "outputs": ["console", "file"]
    ]
])

// Call plugin function
let logFunc = try system.lua.getFunction("Logger.log")
try logFunc.callVoid("info", "Application started")
try logFunc.callVoid("debug", "Loading modules...")
```

---

## Summary

| Feature | Purpose | Key APIs |
|---------|---------|----------|
| **LuaCallable** | Call Lua functions from Swift | `getFunction()`, `call()`, `callVoid()` |
| **Nested Collections** | Pass complex data structures | `[[T]]`, `[String: [T]]` |
| **LuaTable Iteration** | Enumerate table contents | `for-in`, `keys`, `values`, `count` |

These features enable:
- Bi-directional function calling between Swift and Lua
- Complex data structure exchange
- Configuration file processing
- Plugin and scripting systems
