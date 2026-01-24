# LuaKit 2.0 Phase 3 Examples

This document provides extensive examples for the Phase 3 features: **LuaCallback**, **LuaCoroutine**, and **Table Serialization**.

---

## Table of Contents

1. [LuaCallback - Storing Lua Functions](#luacallback---storing-lua-functions)
   - [Basic Usage](#basic-callback-usage)
   - [Event Handling Patterns](#event-handling-patterns)
   - [Callbacks with Arguments](#callbacks-with-arguments)
   - [Callbacks with Return Values](#callbacks-with-return-values)
   - [Error Handling](#callback-error-handling)
   - [Thread Safety](#callback-thread-safety)

2. [LuaCoroutine - Working with Coroutines](#luacoroutine---working-with-coroutines)
   - [Basic Coroutine Usage](#basic-coroutine-usage)
   - [Generator Patterns](#generator-patterns)
   - [Passing Values to Coroutines](#passing-values-to-coroutines)
   - [Multiple Coroutines](#multiple-coroutines)
   - [Coroutine Status Handling](#coroutine-status-handling)

3. [Table Serialization - JSON & Codable](#table-serialization---json--codable)
   - [Converting Tables to JSON](#converting-tables-to-json)
   - [Loading JSON into Lua](#loading-json-into-lua)
   - [Codable Integration](#codable-integration)
   - [Configuration Files](#configuration-file-patterns)
   - [API Response Handling](#api-response-handling)

---

## LuaCallback - Storing Lua Functions

`LuaCallback` allows you to store Lua functions and call them later from Swift. This is perfect for event handlers, plugin systems, and callback-based APIs.

### Basic Callback Usage

```swift
import LuaKit

// Create a Lua state
let lua = try LuaState()

// Define a Lua function
try lua.execute("""
    function greet(name)
        return "Hello, " .. name .. "!"
    end
""")

// Get the function as a callback
let greetCallback = try lua.getCallback("greet")

// Call it later with an argument
let message: String = try greetCallback.call("World")
print(message)  // Output: Hello, World!
```

### Event Handling Patterns

A common use case is allowing Lua scripts to register event handlers:

```swift
import LuaKit

class GameEngine {
    private let lua: LuaState
    private var onUpdateCallback: LuaCallback?
    private var onCollisionCallback: LuaCallback?

    init() throws {
        lua = try LuaState()
        setupLuaBindings()
    }

    private func setupLuaBindings() {
        // Register Swift functions that Lua can call to set callbacks
        lua.register(function: "onUpdate") { [weak self] (callback: LuaCallback) in
            self?.onUpdateCallback = callback
        }

        lua.register(function: "onCollision") { [weak self] (callback: LuaCallback) in
            self?.onCollisionCallback = callback
        }
    }

    func loadScript(_ code: String) throws {
        try lua.execute(code)
    }

    func update(deltaTime: Double) {
        // Call the Lua update callback if registered
        if let callback = onUpdateCallback, callback.isValid {
            try? callback.callVoid(deltaTime)
        }
    }

    func handleCollision(objectA: String, objectB: String) {
        if let callback = onCollisionCallback, callback.isValid {
            try? callback.callVoid(objectA, objectB)
        }
    }
}

// Usage:
let engine = try GameEngine()

try engine.loadScript("""
    -- Register update handler
    onUpdate(function(dt)
        print("Frame update: " .. dt .. " seconds")
    end)

    -- Register collision handler
    onCollision(function(a, b)
        print("Collision between " .. a .. " and " .. b)
    end)
""")

// In your game loop:
engine.update(deltaTime: 0.016)  // Calls the Lua function
engine.handleCollision(objectA: "player", objectB: "enemy")
```

### Callbacks with Arguments

`LuaCallback` supports 0-4 arguments for `callVoid()` and 0-3 arguments for `call()`:

```swift
let lua = try LuaState()

// Function with no arguments
try lua.execute("function noArgs() print('Called!') end")
let noArgsCallback = try lua.getCallback("noArgs")
try noArgsCallback.callVoid()

// Function with one argument
try lua.execute("function oneArg(x) print('Got: ' .. x) end")
let oneArgCallback = try lua.getCallback("oneArg")
try oneArgCallback.callVoid(42)

// Function with two arguments
try lua.execute("function twoArgs(a, b) print(a .. ' + ' .. b) end")
let twoArgsCallback = try lua.getCallback("twoArgs")
try twoArgsCallback.callVoid("Hello", "World")

// Function with three arguments
try lua.execute("function threeArgs(a, b, c) return a + b + c end")
let threeArgsCallback = try lua.getCallback("threeArgs")
let sum: Int = try threeArgsCallback.call(1, 2, 3)
print(sum)  // Output: 6

// Function with four arguments (callVoid only)
try lua.execute("""
    function fourArgs(a, b, c, d)
        result = a * b * c * d
    end
""")
let fourArgsCallback = try lua.getCallback("fourArgs")
try fourArgsCallback.callVoid(2, 3, 4, 5)
print(lua.globals["result"] as? Int ?? 0)  // Output: 120
```

### Callbacks with Return Values

Use `call()` to get typed return values:

```swift
let lua = try LuaState()

// String return
try lua.execute("""
    function formatName(first, last)
        return first .. " " .. last
    end
""")
let formatCallback = try lua.getCallback("formatName")
let fullName: String = try formatCallback.call("John", "Doe")
print(fullName)  // Output: John Doe

// Integer return
try lua.execute("""
    function calculate(x, y)
        return x * y + 10
    end
""")
let calcCallback = try lua.getCallback("calculate")
let result: Int = try calcCallback.call(5, 3)
print(result)  // Output: 25

// Boolean return
try lua.execute("""
    function isValid(value)
        return value > 0 and value < 100
    end
""")
let validCallback = try lua.getCallback("isValid")
let valid: Bool = try validCallback.call(50)
print(valid)  // Output: true

// Double return
try lua.execute("""
    function average(a, b, c)
        return (a + b + c) / 3.0
    end
""")
let avgCallback = try lua.getCallback("average")
let avg: Double = try avgCallback.call(10.0, 20.0, 30.0)
print(avg)  // Output: 20.0
```

### Callback Error Handling

Handle errors gracefully when calling Lua functions:

```swift
let lua = try LuaState()

try lua.execute("""
    function mayFail(shouldError)
        if shouldError then
            error("Something went wrong!")
        end
        return "Success"
    end
""")

let callback = try lua.getCallback("mayFail")

// Successful call
do {
    let result: String = try callback.call(false)
    print(result)  // Output: Success
} catch {
    print("Error: \(error)")
}

// Failed call
do {
    let _: String = try callback.call(true)
} catch let error as LuaError {
    switch error {
    case .runtime(let message):
        print("Lua error: \(message)")  // Output: Lua error: ...Something went wrong!
    default:
        print("Other error: \(error)")
    }
}

// Check validity before calling
var localLua: LuaState? = try LuaState()
try localLua!.execute("function test() return 1 end")
let testCallback = try localLua!.getCallback("test")

print(testCallback.isValid)  // Output: true

localLua = nil  // Deallocate the Lua state

print(testCallback.isValid)  // Output: false

do {
    try testCallback.callVoid()
} catch LuaError.stateInvalid {
    print("Cannot call: Lua state was deallocated")
}
```

### Callback Thread Safety

`LuaCallback` is `@unchecked Sendable` and uses internal locking for thread safety:

```swift
import LuaKit

let lua = try LuaState()

try lua.execute("""
    counter = 0
    function increment()
        counter = counter + 1
        return counter
    end
""")

let callback = try lua.getCallback("increment")

// Safe to pass to async contexts
Task {
    let value: Int = try await withCheckedThrowingContinuation { continuation in
        do {
            let result: Int = try callback.call()
            continuation.resume(returning: result)
        } catch {
            continuation.resume(throwing: error)
        }
    }
    print("Counter: \(value)")
}

// Store in a Sendable context
let storedCallback: @Sendable () -> LuaCallback = { callback }
```

---

## LuaCoroutine - Working with Coroutines

`LuaCoroutine` provides a Swift-friendly interface for Lua coroutines, enabling cooperative multitasking and generator patterns.

### Basic Coroutine Usage

```swift
import LuaKit

let lua = try LuaState()

// Create a coroutine from code
let coro = try lua.createCoroutine("""
    print("Starting coroutine")
    coroutine.yield("first")
    print("Resumed!")
    coroutine.yield("second")
    print("Almost done")
    return "finished"
""")

// Check initial status
print(coro.status)  // Output: suspended

// Resume and get values
let v1: String = try coro.resume()
print(v1)  // Output: first
print(coro.status)  // Output: suspended

let v2: String = try coro.resume()
print(v2)  // Output: second
print(coro.status)  // Output: suspended

let v3: String = try coro.resume()
print(v3)  // Output: finished
print(coro.status)  // Output: dead
```

### Generator Patterns

Use coroutines to create lazy sequences:

```swift
let lua = try LuaState()

// Fibonacci generator
let fibGen = try lua.createCoroutine("""
    local a, b = 0, 1
    for i = 1, 20 do
        coroutine.yield(a)
        a, b = b, a + b
    end
    return -1  -- sentinel value
""")

print("First 10 Fibonacci numbers:")
var count = 0
while fibGen.status == .suspended && count < 10 {
    let num: Int = try fibGen.resume()
    if num >= 0 {
        print(num, terminator: " ")
        count += 1
    }
}
// Output: 0 1 1 2 3 5 8 13 21 34

// Range generator
let rangeGen = try lua.createCoroutine("""
    for i = 1, 100 do
        coroutine.yield(i * i)  -- yield squares
    end
    return 0
""")

// Get first 5 squares
var squares: [Int] = []
for _ in 0..<5 {
    let sq: Int = try rangeGen.resume()
    squares.append(sq)
}
print(squares)  // Output: [1, 4, 9, 16, 25]

// Prime number generator
let primeGen = try lua.createCoroutine("""
    local function isPrime(n)
        if n < 2 then return false end
        for i = 2, math.sqrt(n) do
            if n % i == 0 then return false end
        end
        return true
    end

    local n = 2
    while true do
        if isPrime(n) then
            coroutine.yield(n)
        end
        n = n + 1
    end
""")

// Get first 10 primes
var primes: [Int] = []
for _ in 0..<10 {
    let prime: Int = try primeGen.resume()
    primes.append(prime)
}
print(primes)  // Output: [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
```

### Passing Values to Coroutines

You can pass arguments when resuming a coroutine:

```swift
let lua = try LuaState()

// Initial arguments via varargs
let coro1 = try lua.createCoroutine("""
    local x, y = ...  -- receive initial arguments
    local result = x + y
    coroutine.yield(result)
    return result * 2
""")

let sum: Int = try coro1.resume(10, 20)
print(sum)  // Output: 30

let doubled: Int = try coro1.resume()
print(doubled)  // Output: 60

// Passing values on each resume
let accumulator = try lua.createCoroutine("""
    local total = 0
    while true do
        local value = coroutine.yield(total)
        if value then
            total = total + value
        end
    end
""")

// Start the coroutine
try accumulator.resumeVoid()

// Add values and get running total
var _: Int = try accumulator.resume(10)   // total = 10
var _: Int = try accumulator.resume(20)   // total = 30
let total: Int = try accumulator.resume(5)  // total = 35
print("Running total: \(total)")  // Output: Running total: 35

// Producer-consumer pattern
let producer = try lua.createCoroutine("""
    local data = {"apple", "banana", "cherry", "date"}
    for _, item in ipairs(data) do
        local processed = coroutine.yield(item)
        print("Processed: " .. (processed or "nothing"))
    end
    return "done"
""")

while producer.status == .suspended {
    let item: String = try producer.resume()
    if item != "done" {
        print("Received: \(item)")
        // In real code, you might process and send back a result
    }
}
```

### Multiple Coroutines

Run multiple coroutines concurrently:

```swift
let lua = try LuaState()

// Create multiple workers
let worker1 = try lua.createCoroutine("""
    for i = 1, 5 do
        coroutine.yield("Worker1: " .. i)
    end
    return "Worker1 done"
""")

let worker2 = try lua.createCoroutine("""
    for i = 1, 5 do
        coroutine.yield("Worker2: " .. (i * 10))
    end
    return "Worker2 done"
""")

// Interleave execution
while worker1.status == .suspended || worker2.status == .suspended {
    if worker1.status == .suspended {
        let msg: String = try worker1.resume()
        print(msg)
    }
    if worker2.status == .suspended {
        let msg: String = try worker2.resume()
        print(msg)
    }
}
// Output:
// Worker1: 1
// Worker2: 10
// Worker1: 2
// Worker2: 20
// ... etc

// Shared state between coroutines
lua.globals["sharedCounter"] = 0

let counter1 = try lua.createCoroutine("""
    for i = 1, 3 do
        sharedCounter = sharedCounter + 1
        coroutine.yield(sharedCounter)
    end
    return sharedCounter
""")

let counter2 = try lua.createCoroutine("""
    for i = 1, 3 do
        sharedCounter = sharedCounter + 10
        coroutine.yield(sharedCounter)
    end
    return sharedCounter
""")

// Interleave - they share the same global state
let v1: Int = try counter1.resume()  // 1
let v2: Int = try counter2.resume()  // 11
let v3: Int = try counter1.resume()  // 12
let v4: Int = try counter2.resume()  // 22
print("\(v1), \(v2), \(v3), \(v4)")  // Output: 1, 11, 12, 22
```

### Coroutine Status Handling

Properly handle coroutine lifecycle:

```swift
let lua = try LuaState()

let coro = try lua.createCoroutine("""
    coroutine.yield(1)
    coroutine.yield(2)
    return 3
""")

// Process until dead
func processCoroutine(_ coro: LuaCoroutine) throws {
    while coro.status == .suspended {
        let value: Int = try coro.resume()
        print("Got value: \(value)")
    }
    print("Coroutine finished with status: \(coro.status)")
}

try processCoroutine(coro)
// Output:
// Got value: 1
// Got value: 2
// Got value: 3
// Coroutine finished with status: dead

// Error handling in coroutines
let errorCoro = try lua.createCoroutine("""
    coroutine.yield("ok")
    error("Something went wrong!")
""")

do {
    let _: String = try errorCoro.resume()  // "ok"
    let _: String = try errorCoro.resume()  // throws!
} catch let error as LuaError {
    if case .coroutineError(let message) = error {
        print("Coroutine error: \(message)")
    }
}
print("Status after error: \(errorCoro.status)")  // dead
```

---

## Table Serialization - JSON & Codable

LuaKit provides seamless conversion between Lua tables and Swift data structures.

### Converting Tables to JSON

```swift
let lua = try LuaState()

// Simple table to JSON
try lua.execute("""
    config = {
        appName = "MyApp",
        version = "1.0.0",
        debug = true,
        maxConnections = 100
    }
""")

let configTable = lua.getTable("config")!
let json = try configTable.toJSON()
print(json)
// Output: {"appName":"MyApp","debug":true,"maxConnections":100,"version":"1.0.0"}

// Pretty-printed JSON
let prettyJson = try configTable.toJSON(prettyPrint: true)
print(prettyJson)
// Output:
// {
//   "appName" : "MyApp",
//   "debug" : true,
//   "maxConnections" : 100,
//   "version" : "1.0.0"
// }

// Nested tables
try lua.execute("""
    user = {
        name = "Alice",
        age = 30,
        address = {
            street = "123 Main St",
            city = "Springfield",
            zip = "12345"
        },
        tags = {"developer", "swift", "lua"}
    }
""")

let userTable = lua.getTable("user")!
let userJson = try userTable.toJSON(prettyPrint: true)
print(userJson)
// Output:
// {
//   "address" : {
//     "city" : "Springfield",
//     "street" : "123 Main St",
//     "zip" : "12345"
//   },
//   "age" : 30,
//   "name" : "Alice",
//   "tags" : ["developer", "swift", "lua"]
// }

// Convert to Swift dictionary
let userDict = userTable.toDictionary()
print(userDict["name"] as? String ?? "")  // Output: Alice

let address = userDict["address"] as? [String: Any]
print(address?["city"] as? String ?? "")  // Output: Springfield

// Convert array-like tables
try lua.execute("numbers = {10, 20, 30, 40, 50}")
let numbersTable = lua.getTable("numbers")!
let numbersArray = numbersTable.toArray()
print(numbersArray as Any)  // Output: Optional([10, 20, 30, 40, 50])
```

### Loading JSON into Lua

```swift
let lua = try LuaState()

// Load JSON string
let jsonString = """
{
    "name": "Bob",
    "scores": [95, 87, 92],
    "active": true,
    "metadata": {
        "created": "2024-01-15",
        "updated": "2024-01-20"
    }
}
"""

try lua.loadJSON(jsonString, as: "player")

// Access from Lua
try lua.execute("""
    print("Name: " .. player.name)
    print("First score: " .. player.scores[1])
    print("Created: " .. player.metadata.created)
""")

// Or access from Swift
let playerTable = lua.getTable("player")!
print(playerTable["name"] as? String ?? "")  // Output: Bob

// Load from Data
let jsonData = """
{"items": ["sword", "shield", "potion"], "gold": 500}
""".data(using: .utf8)!

try lua.loadJSON(jsonData, as: "inventory")

try lua.execute("""
    for i, item in ipairs(inventory.items) do
        print(i .. ": " .. item)
    end
    print("Gold: " .. inventory.gold)
""")
// Output:
// 1: sword
// 2: shield
// 3: potion
// Gold: 500

// Use loaded data in Lua logic
try lua.execute("""
    function canAfford(cost)
        return inventory.gold >= cost
    end

    function purchase(item, cost)
        if canAfford(cost) then
            table.insert(inventory.items, item)
            inventory.gold = inventory.gold - cost
            return true
        end
        return false
    end
""")

let purchaseFunc = try lua.getFunction("purchase")
let success: Bool = try purchaseFunc.call("helmet", 100)
print("Purchase successful: \(success)")  // Output: true
print("Remaining gold: \(lua.getTable("inventory")!["gold"] as? Int ?? 0)")  // Output: 400
```

### Codable Integration

Seamlessly work with Swift's Codable types:

```swift
import LuaKit

// Define Codable structs
struct Player: Codable, Equatable {
    let name: String
    let level: Int
    let health: Double
    let isAlive: Bool
}

struct GameState: Codable {
    struct Position: Codable {
        let x: Double
        let y: Double
    }

    let player: Player
    let position: Position
    let inventory: [String]
    let score: Int
}

let lua = try LuaState()

// Encode Swift struct to Lua table
let player = Player(name: "Hero", level: 10, health: 85.5, isAlive: true)
try lua.encode(player, as: "currentPlayer")

// Access in Lua
try lua.execute("""
    print("Player: " .. currentPlayer.name)
    print("Level: " .. currentPlayer.level)
    print("Health: " .. currentPlayer.health)

    -- Modify in Lua
    currentPlayer.level = currentPlayer.level + 1
    currentPlayer.health = 100.0
""")

// Decode back to Swift
let updatedPlayer = try lua.decode("currentPlayer", as: Player.self)
print(updatedPlayer.level)   // Output: 11
print(updatedPlayer.health)  // Output: 100.0

// Complex nested structures
let gameState = GameState(
    player: Player(name: "Alice", level: 5, health: 100, isAlive: true),
    position: GameState.Position(x: 10.5, y: 20.3),
    inventory: ["sword", "shield", "potion"],
    score: 1500
)

try lua.encode(gameState, as: "game")

// Use in Lua
try lua.execute("""
    print("Player at (" .. game.position.x .. ", " .. game.position.y .. ")")
    print("Score: " .. game.score)
    print("Inventory:")
    for i, item in ipairs(game.inventory) do
        print("  " .. i .. ". " .. item)
    end

    -- Update score
    game.score = game.score + 100
""")

// Decode updated state
let savedState = try lua.decode("game", as: GameState.self)
print("Updated score: \(savedState.score)")  // Output: 1600

// Arrays of Codable types
struct Item: Codable {
    let id: Int
    let name: String
    let value: Int
}

let items = [
    Item(id: 1, name: "Sword", value: 100),
    Item(id: 2, name: "Shield", value: 75),
    Item(id: 3, name: "Potion", value: 25)
]

// Encode array
let itemsData = try JSONEncoder().encode(items)
try lua.loadJSON(itemsData, as: "shopItems")

try lua.execute("""
    local totalValue = 0
    for _, item in ipairs(shopItems) do
        print(item.name .. ": " .. item.value .. " gold")
        totalValue = totalValue + item.value
    end
    print("Total value: " .. totalValue)
""")
```

### Configuration File Patterns

Load and save configuration using JSON:

```swift
import LuaKit
import Foundation

class ConfigManager {
    private let lua: LuaState
    private let configPath: URL

    init(configPath: URL) throws {
        self.lua = try LuaState()
        self.configPath = configPath
    }

    func loadConfig() throws {
        if FileManager.default.fileExists(atPath: configPath.path) {
            let data = try Data(contentsOf: configPath)
            try lua.loadJSON(data, as: "config")
        } else {
            // Create default config
            try lua.execute("""
                config = {
                    window = {
                        width = 1920,
                        height = 1080,
                        fullscreen = false
                    },
                    audio = {
                        masterVolume = 0.8,
                        musicVolume = 0.6,
                        sfxVolume = 1.0
                    },
                    controls = {
                        jump = "space",
                        attack = "left_click"
                    }
                }
            """)
        }
    }

    func saveConfig() throws {
        let configTable = lua.getTable("config")!
        let json = try configTable.toJSON(prettyPrint: true)
        try json.write(to: configPath, atomically: true, encoding: .utf8)
    }

    func updateConfig(_ code: String) throws {
        try lua.execute(code)
        try saveConfig()
    }

    func getWindowSize() -> (width: Int, height: Int) {
        let config = lua.getTable("config")!
        let window = config["window"] as? [String: Any] ?? [:]
        return (
            width: window["width"] as? Int ?? 800,
            height: window["height"] as? Int ?? 600
        )
    }
}

// Usage
let configURL = FileManager.default.temporaryDirectory.appendingPathComponent("config.json")
let configManager = try ConfigManager(configPath: configURL)

try configManager.loadConfig()
let size = configManager.getWindowSize()
print("Window: \(size.width)x\(size.height)")

// Update from Lua script
try configManager.updateConfig("""
    config.window.fullscreen = true
    config.audio.masterVolume = 0.5
""")
```

### API Response Handling

Process API responses with Lua scripting:

```swift
import LuaKit

class APIProcessor {
    private let lua: LuaState

    init() throws {
        lua = try LuaState()
        setupProcessors()
    }

    private func setupProcessors() {
        // Define Lua processing functions
        try? lua.execute("""
            -- Transform API response
            function processUsers(data)
                local result = {}
                for _, user in ipairs(data.users) do
                    table.insert(result, {
                        displayName = user.firstName .. " " .. user.lastName,
                        email = user.email,
                        isAdmin = user.role == "admin"
                    })
                end
                return result
            end

            -- Filter and sort
            function filterActiveUsers(users, minAge)
                local active = {}
                for _, user in ipairs(users) do
                    if user.active and user.age >= minAge then
                        table.insert(active, user)
                    end
                end
                -- Sort by age
                table.sort(active, function(a, b) return a.age < b.age end)
                return active
            end

            -- Aggregate data
            function calculateStats(orders)
                local stats = {
                    totalOrders = #orders,
                    totalRevenue = 0,
                    averageOrderValue = 0
                }
                for _, order in ipairs(orders) do
                    stats.totalRevenue = stats.totalRevenue + order.amount
                end
                if stats.totalOrders > 0 then
                    stats.averageOrderValue = stats.totalRevenue / stats.totalOrders
                end
                return stats
            end
        """)
    }

    func processAPIResponse(_ json: String) throws -> [String: Any] {
        // Load the API response
        try lua.loadJSON(json, as: "apiResponse")

        // Process with Lua
        try lua.execute("""
            processedData = processUsers(apiResponse)
        """)

        // Return as dictionary
        return lua.getTable("processedData")?.toDictionary() ?? [:]
    }

    func getStats(ordersJson: String) throws -> (total: Int, revenue: Double, average: Double) {
        try lua.loadJSON(ordersJson, as: "orders")
        try lua.execute("stats = calculateStats(orders)")

        let stats = lua.getTable("stats")!
        return (
            total: stats["totalOrders"] as? Int ?? 0,
            revenue: stats["totalRevenue"] as? Double ?? 0,
            average: stats["averageOrderValue"] as? Double ?? 0
        )
    }
}

// Usage
let processor = try APIProcessor()

let usersJson = """
{
    "users": [
        {"firstName": "John", "lastName": "Doe", "email": "john@example.com", "role": "admin"},
        {"firstName": "Jane", "lastName": "Smith", "email": "jane@example.com", "role": "user"}
    ]
}
"""

let processed = try processor.processAPIResponse(usersJson)
print(processed)

let ordersJson = """
[
    {"id": 1, "amount": 99.99},
    {"id": 2, "amount": 149.50},
    {"id": 3, "amount": 75.00}
]
"""

let stats = try processor.getStats(ordersJson: ordersJson)
print("Total orders: \(stats.total)")
print("Revenue: $\(stats.revenue)")
print("Average: $\(stats.average)")
```

---

## Complete Example: Game Save System

Here's a complete example combining all Phase 3 features:

```swift
import LuaKit
import Foundation

class GameSaveSystem {
    private let lua: LuaState

    // Callbacks for save events
    private var onSaveCallback: LuaCallback?
    private var onLoadCallback: LuaCallback?

    init() throws {
        lua = try LuaState()
        setupBindings()
    }

    private func setupBindings() {
        // Allow Lua to register save/load callbacks
        lua.register(function: "onSave") { [weak self] (callback: LuaCallback) in
            self?.onSaveCallback = callback
        }

        lua.register(function: "onLoad") { [weak self] (callback: LuaCallback) in
            self?.onLoadCallback = callback
        }

        // Setup save system functions
        try? lua.execute("""
            -- Game state
            gameState = {
                player = {
                    name = "Hero",
                    level = 1,
                    health = 100,
                    position = {x = 0, y = 0}
                },
                inventory = {},
                quests = {},
                playTime = 0
            }

            -- Auto-save coroutine
            function createAutoSaver(intervalSeconds)
                return coroutine.create(function()
                    while true do
                        gameState.playTime = gameState.playTime + intervalSeconds
                        coroutine.yield({
                            action = "autosave",
                            time = gameState.playTime
                        })
                    end
                end)
            end

            -- Level up handler
            function levelUp()
                gameState.player.level = gameState.player.level + 1
                gameState.player.health = 100 + (gameState.player.level * 10)
                return gameState.player.level
            end

            -- Add item
            function addItem(item)
                table.insert(gameState.inventory, item)
            end
        """)
    }

    func saveGame(to url: URL) throws {
        // Notify Lua that save is happening
        if let callback = onSaveCallback, callback.isValid {
            try callback.callVoid()
        }

        // Get game state as JSON
        let stateTable = lua.getTable("gameState")!
        let json = try stateTable.toJSON(prettyPrint: true)
        try json.write(to: url, atomically: true, encoding: .utf8)

        print("Game saved!")
    }

    func loadGame(from url: URL) throws {
        let data = try Data(contentsOf: url)
        try lua.loadJSON(data, as: "gameState")

        // Notify Lua that load completed
        if let callback = onLoadCallback, callback.isValid {
            try callback.callVoid()
        }

        print("Game loaded!")
    }

    func startAutoSave(interval: Int) throws -> LuaCoroutine {
        try lua.execute("autoSaver = createAutoSaver(\(interval))")
        return try lua.createCoroutine(from: "autoSaver")
    }

    func runScript(_ code: String) throws {
        try lua.execute(code)
    }

    var playerLevel: Int {
        lua.getTable("gameState")?["player"] as? [String: Any]?
            .flatMap { $0["level"] as? Int } ?? 1
    }
}

// Usage example
let saveSystem = try GameSaveSystem()

// Setup callbacks
try saveSystem.runScript("""
    onSave(function()
        print("Preparing to save...")
    end)

    onLoad(function()
        print("Game loaded! Welcome back, " .. gameState.player.name)
    end)
""")

// Add some items
try saveSystem.runScript("""
    addItem({name = "Sword", damage = 10})
    addItem({name = "Shield", defense = 5})
    levelUp()
    levelUp()
""")

print("Player level: \(saveSystem.playerLevel)")  // Output: 3

// Save game
let saveURL = FileManager.default.temporaryDirectory.appendingPathComponent("save.json")
try saveSystem.saveGame(to: saveURL)

// Modify state
try saveSystem.runScript("gameState.player.level = 1")
print("After reset: \(saveSystem.playerLevel)")  // Output: 1

// Load game
try saveSystem.loadGame(from: saveURL)
print("After load: \(saveSystem.playerLevel)")  // Output: 3
```

---

## Summary

Phase 3 adds three powerful features:

| Feature | Purpose | Key Methods |
|---------|---------|-------------|
| **LuaCallback** | Store Lua functions for later use | `getCallback()`, `call()`, `callVoid()` |
| **LuaCoroutine** | Cooperative multitasking | `createCoroutine()`, `resume()`, `status` |
| **Table Serialization** | JSON/Codable interop | `toJSON()`, `loadJSON()`, `encode()`, `decode()` |

These features enable sophisticated patterns like:
- Event-driven architectures with Lua callbacks
- Lazy evaluation with coroutine generators
- Configuration management with JSON
- Type-safe data exchange with Codable
- Game save/load systems
- API response processing
