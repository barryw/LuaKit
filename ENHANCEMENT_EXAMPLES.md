# LuaKit Enhancement Examples

This document provides concrete implementation examples for each of the 15 requested enhancements.

## 1. Methods Returning Different Types

### Example: Result Type Support

```swift
@LuaBridgeable
public class FileManager {
    public func readFile(_ path: String) -> Result<String, FileError> {
        do {
            let content = try String(contentsOfFile: path)
            return .success(content)
        } catch {
            return .failure(FileError.notFound(path))
        }
    }
}

// In Lua:
local result, error = fileManager:readFile("config.txt")
if result then
    print("Content: " .. result)
else
    print("Error: " .. error)
end
```

### Example: Optional Return Types

```swift
@LuaBridgeable
public class Database {
    public func findUser(id: Int) -> User? {
        return users[id]
    }
}

// In Lua:
local user = db:findUser(123)
if user then
    print("Found user: " .. user.name)
else
    print("User not found")
end
```

### Example: Tuple Return Types

```swift
@LuaBridgeable
public class Calculator {
    public func divmod(_ a: Int, _ b: Int) -> (quotient: Int, remainder: Int) {
        return (a / b, a % b)
    }
}

// In Lua:
local quotient, remainder = calc:divmod(10, 3)
print("10 / 3 = " .. quotient .. " remainder " .. remainder)
```

## 2. Collection/Array Method Syntax

```swift
@LuaBridgeable
public class Library {
    @LuaCollection
    public var books: [Book] = []
    
    // The macro automatically generates collection methods
}

// In Lua:
library.books:append(book1)
library.books:append(book2)

print("Total books: " .. library.books.count)

for i = 1, library.books.count do
    local book = library.books:get(i)
    print(i .. ": " .. book.title)
end

-- Array-like syntax also supported
library.books[1] = newBook
local firstBook = library.books[1]

-- Iterator support
for book in library.books:iter() do
    print(book.title)
end
```

## 3. Method Aliases

```swift
@LuaBridgeable
public class Image {
    @LuaAlias("getPixel")
    public func pixelAt(x: Int, y: Int) -> Color {
        return pixels[y * width + x]
    }
    
    @LuaAlias("setPixel")
    public func setPixelAt(x: Int, y: Int, color: Color) {
        pixels[y * width + x] = color
    }
}

// In Lua - both names work:
local color1 = image:pixelAt(10, 20)
local color2 = image:getPixel(10, 20)  -- Same as above

image:setPixelAt(10, 20, red)
image:setPixel(10, 20, red)  -- Same as above
```

## 4. Automatic Factory Methods

```swift
@LuaBridgeable
@LuaFactory("fromSize", "fromFile", "fromData")
public class Image {
    public static func fromSize(width: Int, height: Int) -> Image? {
        guard width > 0 && height > 0 else { return nil }
        return Image(width: width, height: height)
    }
    
    public static func fromFile(_ path: String) -> Image? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            return nil
        }
        return Image(data: data)
    }
    
    public static func fromData(_ data: Data) -> Image? {
        // Decode image from data
        return Image(data: data)
    }
}

// In Lua:
local img1 = Image.fromSize(800, 600)
local img2 = Image.fromFile("/path/to/image.png")
local img3 = Image.fromData(imageData)

-- Traditional constructor still works
local img4 = Image.new(800, 600)
```

## 5. Property Validation Attributes

```swift
@LuaBridgeable
public class Player {
    @LuaProperty(min: 0, max: 100)
    public var health: Int = 100
    
    @LuaProperty(min: 0)
    public var score: Int = 0
    
    @LuaProperty(pattern: "^[a-zA-Z0-9_]{3,16}$")
    public var username: String = ""
    
    @LuaProperty(validator: "validateEmail")
    public var email: String = ""
    
    public func validateEmail(_ value: String) -> Result<Void, ValidationError> {
        if value.contains("@") && value.contains(".") {
            return .success(())
        }
        return .failure(ValidationError("Invalid email format"))
    }
}

// In Lua:
player.health = 150  -- Error: Value 150 exceeds maximum of 100
player.health = -10  -- Error: Value -10 is below minimum of 0
player.username = "ab"  -- Error: Value does not match pattern
player.email = "invalid"  -- Error: Invalid email format
```

## 6. Automatic Enum Bridging

```swift
public enum GameState: String, CaseIterable, LuaEnumBridgeable {
    case menu = "menu"
    case playing = "playing"
    case paused = "paused"
    case gameOver = "game_over"
}

@LuaBridgeable
public class Game {
    public var state: GameState = .menu
    
    public func setState(_ newState: GameState) {
        state = newState
    }
}

// Automatic enum registration
state.register(GameState.self, as: "GameState")

// In Lua:
-- Enum values are available as constants
game.state = GameState.playing
game:setState(GameState.paused)

-- String conversion works automatically
game.state = "game_over"  -- Converts from string

-- Can iterate over all cases
for name, value in pairs(GameState) do
    print(name .. " = " .. value)
end
```

## 7. Relationship Annotations

```swift
@LuaBridgeable
public class Author {
    public var name: String
    
    @LuaRelationship(type: .oneToMany, target: Book.self, inverse: "author")
    public var books: [Book] = []
}

@LuaBridgeable
public class Book {
    public var title: String
    
    @LuaRelationship(type: .manyToOne, target: Author.self, inverse: "books")
    public var author: Author?
}

// The macro generates relationship management code

// In Lua:
local author = Author.new("J.K. Rowling")
local book = Book.new("Harry Potter")

-- Setting relationship updates both sides
book.author = author
-- author.books now contains book

-- Or from the other side
author.books:append(book2)
-- book2.author is now set to author

-- Removing also updates both sides
author.books:remove(book)
-- book.author is now nil
```

## 8. Global Function Registration

```swift
// In your app setup:
let state = try LuaState()

// Register simple global functions
state.registerGlobal("getCurrentTime") { 
    Date().timeIntervalSince1970 
}

state.registerGlobal("random") { 
    Double.random(in: 0...1) 
}

// Register functions with parameters
state.registerGlobal("clamp") { (value: Double, min: Double, max: Double) in
    return Swift.max(min, Swift.min(max, value))
}

state.registerGlobal("formatCurrency") { (amount: Double) in
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    return formatter.string(from: NSNumber(value: amount)) ?? ""
}

// In Lua:
print(getCurrentTime())  -- 1693526400.123
print(random())  -- 0.73829
print(clamp(150, 0, 100))  -- 100
print(formatCurrency(1234.56))  -- $1,234.56
```

## 9. Async/Await Support

```swift
@LuaBridgeable
public class NetworkClient {
    @LuaAsync
    public func fetchJSON(_ url: String) async throws -> [String: Any] {
        let data = try await URLSession.shared.data(from: URL(string: url)!).0
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }
    
    @LuaAsync
    public func downloadFile(_ url: String, to path: String) async throws -> Bool {
        let data = try await URLSession.shared.data(from: URL(string: url)!).0
        try data.write(to: URL(fileURLWithPath: path))
        return true
    }
}

// In Lua - callback style:
client:fetchJSON("https://api.example.com/data", function(result, error)
    if error then
        print("Error: " .. error)
    else
        print("Got data: " .. result.name)
    end
end)

-- Promise-style also supported:
client:downloadFile("https://example.com/file.zip", "/tmp/file.zip")
    :andThen(function(success)
        print("Download complete!")
    end)
    :catch(function(error)
        print("Download failed: " .. error)
    end)
```

## 10. Debug Helpers

```swift
@LuaBridgeable(debug: true)
public class GameEngine {
    public var fps: Double = 60.0
    
    public func update(deltaTime: Double) {
        // Debug mode automatically logs method calls
    }
}

// Enable debug logging
GameEngine.debugEnabled = true

// In Lua:
engine:update(0.016)
-- Console output:
-- [DEBUG] GameEngine.update called with arguments: (0.016)
-- [DEBUG] GameEngine.update returned in 0.23ms

engine.fps = 30
-- Console output:
-- [DEBUG] GameEngine.fps setter called with value: 30
-- [DEBUG] Property 'fps' changed from 60.0 to 30.0
```

## 11. Documentation Attributes

```swift
@LuaBridgeable
@LuaDoc("Represents a 2D point in space")
public class Point {
    @LuaDoc("The X coordinate")
    public var x: Double
    
    @LuaDoc("The Y coordinate")  
    public var y: Double
    
    @LuaDoc("Calculates the distance to another point")
    @LuaParam("other", "The point to measure distance to")
    @LuaReturn("The Euclidean distance between the two points")
    public func distanceTo(_ other: Point) -> Double {
        let dx = other.x - x
        let dy = other.y - y
        return sqrt(dx * dx + dy * dy)
    }
}

// Documentation is accessible at runtime
// In Lua:
print(Point.__doc__)
-- Output: "Represents a 2D point in space"

print(Point.distanceTo.__doc__)
-- Output: "Calculates the distance to another point"

-- Can also get parameter info
for param, desc in pairs(Point.distanceTo.__params__) do
    print(param .. ": " .. desc)
end
-- Output: "other: The point to measure distance to"
```

## 12. Method Chaining Support

```swift
@LuaBridgeable
public class QueryBuilder {
    private var conditions: [String] = []
    private var orderBy: String?
    private var limitValue: Int?
    
    @LuaChainable
    public func where(_ condition: String) -> Self {
        conditions.append(condition)
        return self
    }
    
    @LuaChainable
    public func orderBy(_ field: String) -> Self {
        self.orderBy = field
        return self
    }
    
    @LuaChainable
    public func limit(_ count: Int) -> Self {
        self.limitValue = count
        return self
    }
    
    public func execute() -> [Record] {
        // Execute query
    }
}

// In Lua - fluent interface:
local results = QueryBuilder.new()
    :where("age > 18")
    :where("status = 'active'")
    :orderBy("name")
    :limit(10)
    :execute()
```

## 13. Type Conversion Helpers

```swift
// Define custom type conversions
@LuaConvert(
    from: { hex in Color(hex: hex) },
    to: { color in color.hexString }
)
public struct Color {
    let r, g, b: Double
    
    init(hex: String) {
        // Parse hex string
    }
    
    var hexString: String {
        // Convert to hex
    }
}

@LuaBridgeable
public class Canvas {
    @LuaConvert(using: DateConverter.self)
    public var lastModified: Date
    
    public func fill(with color: Color) {
        // Color is automatically converted from string in Lua
    }
}

// Custom converter
struct DateConverter: LuaTypeConverter {
    static func toLua(_ date: Date) -> Double {
        return date.timeIntervalSince1970
    }
    
    static func fromLua(_ timestamp: Double) -> Date {
        return Date(timeIntervalSince1970: timestamp)
    }
}

// In Lua:
canvas:fill("#FF0000")  -- Automatically converted to Color
canvas.lastModified = os.time()  -- Automatically converted to Date
```

## 14. Namespace Support

```swift
@LuaNamespace("Graphics")
enum GraphicsAPI {
    @LuaBridgeable
    class Color {
        public var r, g, b, a: Double
    }
    
    @LuaBridgeable  
    class Image {
        public var width, height: Int
    }
    
    @LuaBridgeable
    class Shader {
        public var vertexSource: String
        public var fragmentSource: String
    }
    
    // Namespace-level functions
    static func createGradient(from: Color, to: Color) -> Image {
        // Implementation
    }
}

@LuaNamespace("Audio")
enum AudioAPI {
    @LuaBridgeable
    class Sound {
        public func play() { }
        public func stop() { }
    }
    
    static var masterVolume: Double = 1.0
}

// In Lua:
local red = Graphics.Color.new(1, 0, 0, 1)
local img = Graphics.Image.new(800, 600)
local gradient = Graphics.createGradient(red, blue)

local sound = Audio.Sound.new("music.mp3")
Audio.masterVolume = 0.5
sound:play()
```

## 15. Better Error Messages

```swift
// Enhanced error reporting with context
@LuaBridgeable
public class Calculator {
    public func divide(_ a: Double, by b: Double) throws -> Double {
        guard b != 0 else {
            throw LuaError.runtime(
                "Division by zero",
                context: "Calculator.divide",
                suggestion: "Check that the divisor is not zero"
            )
        }
        return a / b
    }
}

// Type mismatch errors with helpful messages
// In Lua:
calc:divide("10", 2)
-- Error: Type mismatch in Calculator.divide parameter 1: expected Number, got String
-- Suggestion: Convert the string to a number using tonumber()

// Method not found with suggestions
calc:devide(10, 2)  -- Note the typo
-- Error: Method 'devide' not found on Calculator
-- Did you mean: divide, divided, divideBy?

// Argument count mismatch
calc:divide(10)
-- Error: Wrong number of arguments for Calculator.divide
-- Expected: 2 arguments (dividend: Number, divisor: Number)
-- Got: 1 argument
```

## Complete Example: Game Entity System

Here's how all features work together:

```swift
// Namespace for game entities
@LuaNamespace("Game")
enum GameAPI {
    // Enum for entity states
    public enum EntityState: String, CaseIterable, LuaEnumBridgeable {
        case idle, moving, attacking, dead
    }
    
    // Base entity class with all features
    @LuaBridgeable(debug: true)
    @LuaDoc("Base class for all game entities")
    public class Entity {
        @LuaDoc("Unique identifier for the entity")
        public let id: Int
        
        @LuaProperty(min: 0, max: 100)
        @LuaDoc("Current health (0-100)")
        public var health: Int = 100
        
        @LuaProperty(pattern: "^[a-zA-Z0-9 ]{1,32}$")
        @LuaDoc("Display name")
        public var name: String
        
        @LuaCollection
        @LuaDoc("Inventory items")
        public var inventory: [Item] = []
        
        @LuaDoc("Current state of the entity")
        public var state: EntityState = .idle
        
        @LuaFactory("spawn")
        public static func spawn(at position: Point) -> Entity? {
            // Factory method for spawning
        }
        
        @LuaChainable
        @LuaDoc("Move the entity to a position")
        public func moveTo(_ position: Point) -> Self {
            state = .moving
            // Movement logic
            return self
        }
        
        @LuaAsync
        @LuaDoc("Attack another entity")
        public func attack(_ target: Entity) async throws -> AttackResult {
            state = .attacking
            // Async attack logic
        }
        
        @LuaAlias("hurt")
        @LuaDoc("Deal damage to the entity")
        public func takeDamage(_ amount: Int) -> Bool {
            health = max(0, health - amount)
            if health == 0 {
                state = .dead
                return true
            }
            return false
        }
    }
}

// In Lua:
-- Use namespace
local entity = Game.Entity.spawn(Point.new(10, 20))

-- Chain methods
entity:moveTo(Point.new(30, 40))
     :moveTo(Point.new(50, 60))

-- Use validated properties
entity.name = "Hero"
entity.health = 150  -- Error: exceeds maximum

-- Use collections
entity.inventory:append(sword)
print("Items: " .. entity.inventory.count)

-- Async operations
entity:attack(enemy, function(result, error)
    if error then
        print("Attack failed: " .. error)
    else
        print("Damage dealt: " .. result.damage)
    end
end)
```

This comprehensive example system demonstrates how all 15 enhancements work together to create a powerful, type-safe, and user-friendly Lua binding system.