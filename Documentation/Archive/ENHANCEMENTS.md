# LuaKit 1.3.0 Enhancements

This document describes the 15 major enhancements added to LuaKit 1.3.0, making Swift-Lua bridging more powerful and developer-friendly.

## Table of Contents

1. [Support for Methods Returning Different Types](#1-support-for-methods-returning-different-types)
2. [Collection/Array Method Syntax](#2-collectionarray-method-syntax)
3. [Method Aliases](#3-method-aliases)
4. [Automatic Factory Methods](#4-automatic-factory-methods)
5. [Property Validation Attributes](#5-property-validation-attributes)
6. [Automatic Enum Bridging](#6-automatic-enum-bridging)
7. [Relationship Annotations](#7-relationship-annotations)
8. [Global Function Registration](#8-global-function-registration)
9. [Async/Await Support](#9-asyncawait-support)
10. [Debug Helpers](#10-debug-helpers)
11. [Documentation Attributes](#11-documentation-attributes)
12. [Method Chaining Support](#12-method-chaining-support)
13. [Type Conversion Helpers](#13-type-conversion-helpers)
14. [Namespace Support](#14-namespace-support)
15. [Better Error Messages](#15-better-error-messages)

---

## 1. Support for Methods Returning Different Types

The enhanced macro system now properly handles methods that return types other than the class type itself.

```swift
@LuaBridgeable
public class Project: LuaBridgeable {
    public func getImages() -> [Image] { }        // Returns array
    public func findImage(name: String) -> Image? { } // Returns optional
    public func getImageCount() -> Int { }        // Returns Int
    public func hasImages() -> Bool { }           // Returns Bool
    public func getCreationDate() -> Date { }     // Returns Date
    public func getProjectURL() -> URL? { }       // Returns optional URL
}
```

## 2. Collection/Array Method Syntax

Use `@LuaCollection` to automatically generate collection management methods:

```swift
@LuaBridgeable
public class Project: LuaBridgeable {
    @LuaCollection("images")
    public var images: [Image] = []
    
    @LuaCollection("tags")
    public var tags: [String] = []
}
```

This automatically generates:
- `addImages(item)` / `addTags(item)`
- `removeImages(item)` / `removeTags(item)`
- `getImagesAt(index)` / `getTagsAt(index)`
- `getImagesCount()` / `getTagsCount()`
- `clearImages()` / `clearTags()`

## 3. Method Aliases

Create method aliases for backward compatibility or convenience:

```swift
@LuaBridgeable
public class Image: LuaBridgeable {
    @LuaAlias("drawLine", "line")
    public func drawLineNew(x1: Int, y1: Int, x2: Int, y2: Int, color: Int) { }
    
    @LuaAlias("clear", "cls")
    public func clearScreen() { }
}
```

In Lua:
```lua
img:drawLine(0, 0, 100, 100, 1)  -- Works
img:line(0, 0, 100, 100, 1)      -- Also works
img:clearScreen()                  -- Works
img:clear()                        -- Also works
img:cls()                          -- Also works
```

## 4. Automatic Factory Methods

Mark methods as factory methods with `@LuaFactory`:

```swift
@LuaBridgeable
public class ImageFactory: LuaBridgeable {
    @LuaFactory
    public func createImage(name: String, width: Int, height: Int) -> Image { }
    
    @LuaFactory
    public func createSprite(name: String) -> Image { }
}
```

## 5. Property Validation Attributes

Add validation to properties with `@LuaProperty`:

```swift
@LuaBridgeable
public class ValidatedImage: LuaBridgeable {
    @LuaProperty(readOnly: true)
    public let id: UUID = UUID()
    
    @LuaProperty(validator: "validateName")
    public var name: String
    
    @LuaProperty(min: 1, max: 320)
    public var width: Int
    
    @LuaProperty(min: 1, max: 240)
    public var height: Int
    
    @LuaProperty(regex: "^#[0-9A-Fa-f]{6}$")
    public var backgroundColor: String = "#000000"
    
    public func validateName(_ value: String) -> Bool {
        return !value.isEmpty && value.count <= 50
    }
}
```

## 6. Automatic Enum Bridging

Enums are automatically bridged to Lua:

```swift
public enum ImageType: String, CaseIterable, LuaEnumBridgeable {
    case sprite = "sprite"
    case bob = "bob"
    case bitmap = "bitmap"
    case font = "font"
}

// Register in Lua
lua.registerEnum(ImageType.self, as: "ImageType")
```

In Lua:
```lua
local img = TypedImage.new("test", ImageType.sprite)
print(img.type)  -- "sprite"

-- Validation
if validateImageType(userInput) then
    img.type = userInput
end
```

## 7. Relationship Annotations

Define relationships between objects:

```swift
@LuaBridgeable
public class Project: LuaBridgeable {
    @LuaRelationship(type: .oneToMany, inverse: "project")
    public var images: [Image] = []
    
    @LuaRelationship(type: .oneToMany, cascade: .delete)
    public var palettes: [Palette] = []
}
```

## 8. Global Function Registration

Register global functions and namespaces easily:

```swift
// Register globals
lua.registerGlobal("PI", 3.14159)
lua.registerGlobal("appName", "MyApp")
lua.registerFunction("multiply") { (a: Int, b: Int) in a * b }

// Register multiple at once
lua.registerGlobals([
    "version": "1.0.0",
    "maxPlayers": 4,
    "serverURL": "https://api.example.com"
])

// Create namespaces
let math = lua.registerNamespace("math")
math.register("add", LuaFunction { (a: Int, b: Int) in a + b })
math.register("subtract", LuaFunction { (a: Int, b: Int) in a - b })
```

## 9. Async/Await Support

Bridge async Swift methods to Lua callbacks:

```swift
@LuaBridgeable
public class AsyncOperations: LuaBridgeable {
    @LuaAsync
    public func loadImage(url: String) async throws -> Image { }
    
    @LuaAsync
    public func exportProject(_ project: Project) async -> Bool { }
}
```

In Lua:
```lua
local async = AsyncOps.new()
async:loadImage("https://example.com/image.png", function(image, error)
    if error then
        print("Error:", error)
    else
        print("Image loaded:", image.name)
    end
end)
```

## 10. Debug Helpers

Enable debug mode for detailed logging:

```swift
@LuaBridgeable(debug: true)
public class DebuggedClass: LuaBridgeable {
    // All method calls and property access will be logged
}

// Global debug configuration
lua.setDebugMode(true)
lua.setDebugLogLevel(.verbose)

// Get performance and memory reports
print(lua.getPerformanceReport())
print(lua.getMemoryReport())
```

## 11. Documentation Attributes

Add documentation to your Lua API:

```swift
@LuaBridgeable
public class DocumentedAPI: LuaBridgeable {
    @LuaDoc("Sets a pixel at the given coordinates")
    @LuaParam("x", "X coordinate (1-based)")
    @LuaParam("y", "Y coordinate (1-based)")
    @LuaParam("color", "Color index (0-255)")
    public func setPixel(x: Int, y: Int, color: Int) { }
}
```

## 12. Method Chaining Support

Enable fluent interfaces:

```swift
@LuaBridgeable
public class ChainableGraphics: LuaBridgeable {
    @LuaChainable
    public func setColor(_ color: Int) -> Self { }
    
    @LuaChainable
    public func drawPixel(x: Int, y: Int) -> Self { }
    
    @LuaChainable
    public func drawLine(x1: Int, y1: Int, x2: Int, y2: Int) -> Self { }
}
```

In Lua:
```lua
graphics:setColor(5):drawPixel(10, 10):drawLine(0, 0, 50, 50)
```

## 13. Type Conversion Helpers

Automatic type conversion with custom converters:

```swift
// Built-in conversions for common types
extension Date: LuaConvertible { }
extension URL: LuaConvertible { }
extension UUID: LuaConvertible { }
extension Data: LuaConvertible { }

// Custom conversion
@LuaBridgeable
public class ConversionExample: LuaBridgeable {
    @LuaConvert(from: String.self, using: "StringToUUID")
    public func findById(id: UUID) -> Bool { }
}
```

## 14. Namespace Support

Organize your API with namespaces:

```swift
@LuaNamespace("graphics")
public class DrawingTools {
    public static func createGradient(startColor: String, endColor: String) -> [String] { }
    public static func createPattern(type: String) -> String { }
}

@LuaNamespace("audio")
public class AudioTools {
    public static func loadSound(name: String) -> Bool { }
    public static func playSound(name: String, volume: Double) { }
}
```

In Lua:
```lua
local gradient = graphics.createGradient("#FF0000", "#00FF00")
audio.playSound("beep", 0.5)
```

## 15. Better Error Messages

Enhanced error messages with detailed context:

```lua
-- Before:
-- Error: bad argument #1

-- After:
-- Error: Invalid argument #1 to 'Image:drawLine'
-- Expected: integer
-- Got: string ("not a number")
-- Parameter 'x1'
-- Hint: Ensure all coordinates are numeric values
```

## Migration Guide

To use these enhancements in your existing LuaKit projects:

1. Update your `@LuaBridgeable` macros to use the enhanced version:
   ```swift
   @LuaBridgeable(debug: true)  // Enable debug mode
   ```

2. Add validation to properties:
   ```swift
   @LuaProperty(min: 0, max: 100)
   public var percentage: Int
   ```

3. Register enums:
   ```swift
   lua.registerEnum(MyEnum.self)
   ```

4. Use type-safe global registration:
   ```swift
   lua.registerGlobal("config", myConfig)
   ```

## Best Practices

1. **Use Property Validation**: Always validate user input from Lua
2. **Enable Debug Mode**: During development for better diagnostics
3. **Document Your API**: Use `@LuaDoc` and `@LuaParam` attributes
4. **Type Conversion**: Leverage automatic conversions for common types
5. **Error Context**: Provide helpful error messages with hints

## Performance Considerations

- Debug mode adds overhead; disable in production
- Property validation has minimal impact
- Type conversions are optimized for common types
- Async operations use efficient callback mechanisms

## Examples

See `Examples/EnhancementsExample.swift` for complete working examples of all features.