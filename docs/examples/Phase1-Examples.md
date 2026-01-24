# LuaKit 2.0 Phase 1 Examples

This document provides examples for Phase 1 features: **Extended Function Parameters (4-6 args)**.

---

## Table of Contents

1. [4-Parameter Functions](#4-parameter-functions)
2. [5-Parameter Functions](#5-parameter-functions)
3. [6-Parameter Functions](#6-parameter-functions)
4. [Void Return Functions](#void-return-functions)
5. [Real-World Examples](#real-world-examples)

---

## Overview

LuaKit 1.x supported registering Swift functions with up to 3 parameters. LuaKit 2.0 extends this to **6 parameters**, enabling more complex function signatures without manual argument handling.

```swift
// LuaKit 1.x - Maximum 3 parameters
lua.register(function: "add3") { (a: Int, b: Int, c: Int) -> Int in
    a + b + c
}

// LuaKit 2.0 - Now supports up to 6 parameters!
lua.register(function: "add6") { (a: Int, b: Int, c: Int, d: Int, e: Int, f: Int) -> Int in
    a + b + c + d + e + f
}
```

---

## 4-Parameter Functions

### Basic Usage

```swift
import LuaKit

let lua = try LuaState()

// Register a 4-parameter function
lua.register(function: "createRect") { (x: Double, y: Double, width: Double, height: Double) -> [String: Double] in
    return ["x": x, "y": y, "width": width, "height": height]
}

// Call from Lua
try lua.execute("""
    local rect = createRect(10.0, 20.0, 100.0, 50.0)
    print("Rectangle at (" .. rect.x .. ", " .. rect.y .. ")")
    print("Size: " .. rect.width .. " x " .. rect.height)
""")
// Output:
// Rectangle at (10.0, 20.0)
// Size: 100.0 x 50.0
```

### String Formatting

```swift
lua.register(function: "formatAddress") { (street: String, city: String, state: String, zip: String) -> String in
    return "\(street)\n\(city), \(state) \(zip)"
}

try lua.execute("""
    local address = formatAddress("123 Main St", "Springfield", "IL", "62701")
    print(address)
""")
// Output:
// 123 Main St
// Springfield, IL 62701
```

### Mixed Types

```swift
lua.register(function: "createUser") { (name: String, age: Int, email: String, active: Bool) -> [String: Any] in
    return [
        "name": name,
        "age": age,
        "email": email,
        "active": active,
        "createdAt": Date().timeIntervalSince1970
    ]
}

try lua.execute("""
    local user = createUser("Alice", 30, "alice@example.com", true)
    print("Created user: " .. user.name)
    print("Active: " .. tostring(user.active))
""")
```

---

## 5-Parameter Functions

### Database-Style Operations

```swift
lua.register(function: "insertRecord") {
    (table: String, id: Int, name: String, value: Double, category: String) -> Bool in

    print("INSERT INTO \(table) VALUES (\(id), '\(name)', \(value), '\(category)')")
    return true
}

try lua.execute("""
    local success = insertRecord("products", 1, "Widget", 29.99, "electronics")
    if success then
        print("Record inserted successfully")
    end
""")
```

### Game Entity Creation

```swift
lua.register(function: "spawnEntity") {
    (type: String, x: Double, y: Double, health: Int, team: String) -> Int in

    // In a real game, this would create an entity and return its ID
    print("Spawning \(type) at (\(x), \(y)) with \(health) HP for team \(team)")
    return Int.random(in: 1000...9999)  // Return entity ID
}

try lua.execute("""
    local enemyId = spawnEntity("goblin", 100.0, 200.0, 50, "enemy")
    local allyId = spawnEntity("knight", 50.0, 50.0, 100, "player")

    print("Spawned enemy ID: " .. enemyId)
    print("Spawned ally ID: " .. allyId)
""")
```

### Validation Function

```swift
lua.register(function: "validateForm") {
    (username: String, email: String, password: String, age: Int, country: String) -> [String: Any] in

    var errors: [String] = []

    if username.count < 3 {
        errors.append("Username must be at least 3 characters")
    }
    if !email.contains("@") {
        errors.append("Invalid email format")
    }
    if password.count < 8 {
        errors.append("Password must be at least 8 characters")
    }
    if age < 13 {
        errors.append("Must be at least 13 years old")
    }
    if country.isEmpty {
        errors.append("Country is required")
    }

    return [
        "valid": errors.isEmpty,
        "errors": errors
    ]
}

try lua.execute("""
    local result = validateForm("Al", "invalid", "short", 10, "")

    if not result.valid then
        print("Validation failed:")
        for i, err in ipairs(result.errors) do
            print("  - " .. err)
        end
    end
""")
// Output:
// Validation failed:
//   - Username must be at least 3 characters
//   - Invalid email format
//   - Password must be at least 8 characters
//   - Must be at least 13 years old
//   - Country is required
```

---

## 6-Parameter Functions

### Complex Calculations

```swift
lua.register(function: "calculatePayment") {
    (principal: Double, rate: Double, years: Int, downPayment: Double,
     taxRate: Double, insurancePerYear: Double) -> [String: Double] in

    let loanAmount = principal - downPayment
    let monthlyRate = rate / 100.0 / 12.0
    let numPayments = Double(years * 12)

    // Monthly principal + interest
    let monthlyPI = loanAmount * (monthlyRate * pow(1 + monthlyRate, numPayments)) /
                    (pow(1 + monthlyRate, numPayments) - 1)

    // Add taxes and insurance
    let monthlyTax = (principal * taxRate / 100.0) / 12.0
    let monthlyInsurance = insurancePerYear / 12.0

    let totalMonthly = monthlyPI + monthlyTax + monthlyInsurance
    let totalCost = totalMonthly * numPayments

    return [
        "monthlyPayment": totalMonthly,
        "principalAndInterest": monthlyPI,
        "monthlyTax": monthlyTax,
        "monthlyInsurance": monthlyInsurance,
        "totalCost": totalCost,
        "totalInterest": totalCost - loanAmount
    ]
}

try lua.execute("""
    local payment = calculatePayment(
        300000,     -- principal
        6.5,        -- interest rate %
        30,         -- years
        60000,      -- down payment
        1.2,        -- property tax rate %
        1200        -- insurance per year
    )

    print(string.format("Monthly Payment: $%.2f", payment.monthlyPayment))
    print(string.format("  P&I: $%.2f", payment.principalAndInterest))
    print(string.format("  Tax: $%.2f", payment.monthlyTax))
    print(string.format("  Insurance: $%.2f", payment.monthlyInsurance))
    print(string.format("Total Interest: $%.2f", payment.totalInterest))
""")
```

### Event Handler Registration

```swift
lua.register(function: "registerEventHandler") {
    (eventType: String, priority: Int, async: Bool,
     filter: String, timeout: Double, handler: String) -> Bool in

    print("""
    Registered handler:
      Event: \(eventType)
      Priority: \(priority)
      Async: \(async)
      Filter: \(filter)
      Timeout: \(timeout)s
      Handler: \(handler)
    """)
    return true
}

try lua.execute("""
    registerEventHandler(
        "player.damage",    -- event type
        10,                 -- priority
        true,               -- async
        "source=enemy",     -- filter
        5.0,                -- timeout
        "onPlayerDamage"    -- handler function name
    )
""")
```

### Graphics/UI Creation

```swift
lua.register(function: "createButton") {
    (x: Int, y: Int, width: Int, height: Int, label: String, style: String) -> Int in

    print("Creating button '\(label)' at (\(x), \(y)) size \(width)x\(height) style=\(style)")
    return Int.random(in: 1...1000)  // Return button ID
}

try lua.execute("""
    local btnOk = createButton(100, 200, 80, 30, "OK", "primary")
    local btnCancel = createButton(190, 200, 80, 30, "Cancel", "secondary")

    print("Created buttons: " .. btnOk .. ", " .. btnCancel)
""")
```

---

## Void Return Functions

All parameter counts also support void returns:

```swift
// 4 params, void return
lua.register(function: "logEvent") { (level: String, source: String, message: String, timestamp: Double) in
    let date = Date(timeIntervalSince1970: timestamp)
    print("[\(level)] [\(source)] \(message) at \(date)")
}

// 5 params, void return
lua.register(function: "sendEmail") {
    (to: String, from: String, subject: String, body: String, priority: String) in
    print("Sending \(priority) priority email to \(to)")
    print("Subject: \(subject)")
}

// 6 params, void return
lua.register(function: "drawLine") {
    (x1: Double, y1: Double, x2: Double, y2: Double, color: String, thickness: Double) in
    print("Drawing \(thickness)px \(color) line from (\(x1),\(y1)) to (\(x2),\(y2))")
}

try lua.execute("""
    logEvent("INFO", "GameEngine", "Level loaded", os.time())
    sendEmail("user@example.com", "noreply@app.com", "Welcome!", "Hello...", "high")
    drawLine(0, 0, 100, 100, "red", 2.0)
""")
```

---

## Real-World Examples

### HTTP Request Builder

```swift
lua.register(function: "httpRequest") {
    (method: String, url: String, headers: String, body: String,
     timeout: Double, retries: Int) -> [String: Any] in

    // Simulate HTTP request
    print("HTTP \(method) \(url)")
    print("Headers: \(headers)")
    print("Timeout: \(timeout)s, Retries: \(retries)")

    return [
        "status": 200,
        "body": "{\"success\": true}",
        "headers": ["Content-Type": "application/json"]
    ]
}

try lua.execute("""
    local response = httpRequest(
        "POST",
        "https://api.example.com/users",
        "Content-Type: application/json",
        '{"name": "Alice"}',
        30.0,
        3
    )

    print("Status: " .. response.status)
""")
```

### Audio System

```swift
lua.register(function: "playSound") {
    (soundId: String, volume: Double, pitch: Double, loop: Bool,
     x: Double, y: Double) -> Int in

    let posInfo = x != 0 || y != 0 ? " at (\(x), \(y))" : ""
    print("Playing '\(soundId)' vol=\(volume) pitch=\(pitch) loop=\(loop)\(posInfo)")
    return Int.random(in: 1...9999)  // Return sound instance ID
}

try lua.execute("""
    -- Play background music (no position)
    local musicId = playSound("bgm_forest", 0.7, 1.0, true, 0, 0)

    -- Play positional sound effect
    local sfxId = playSound("explosion", 1.0, 0.9, false, 150.0, 200.0)

    print("Music instance: " .. musicId)
    print("SFX instance: " .. sfxId)
""")
```

### Configuration Builder

```swift
lua.register(function: "configure") {
    (moduleName: String, enabled: Bool, logLevel: String,
     maxConnections: Int, timeout: Double, retryPolicy: String) -> Bool in

    print("""
    Configuring \(moduleName):
      Enabled: \(enabled)
      Log Level: \(logLevel)
      Max Connections: \(maxConnections)
      Timeout: \(timeout)s
      Retry Policy: \(retryPolicy)
    """)
    return true
}

try lua.execute("""
    -- Configure database module
    configure("database", true, "debug", 100, 30.0, "exponential")

    -- Configure cache module
    configure("cache", true, "info", 50, 5.0, "immediate")

    -- Configure disabled module
    configure("legacy", false, "error", 0, 0, "none")
""")
```

---

## Summary

| Parameters | Return Type | Method |
|------------|-------------|--------|
| 4 | `R: LuaConvertible` | `register(function:as:)` |
| 4 | `Void` | `register(function:as:)` |
| 5 | `R: LuaConvertible` | `register(function:as:)` |
| 5 | `Void` | `register(function:as:)` |
| 6 | `R: LuaConvertible` | `register(function:as:)` |
| 6 | `Void` | `register(function:as:)` |

All parameter types must conform to `LuaConvertible`:
- `Int`, `Double`, `Float`
- `String`
- `Bool`
- `[T]` where T: LuaConvertible
- `[String: T]` where T: LuaConvertible
- Custom types conforming to `LuaConvertible`
