# LuaKit 1.1.0: Array Element Access

## What's New in 1.1.0

### Individual Array Element Access 🎯

LuaKit 1.1.0 introduces direct array element access from Lua, making it easier to work with array properties:

```lua
-- Before (1.0.0): Get array, modify, set back
local colors = palette.colors
colors[1] = "red"
palette.colors = colors

-- Now (1.1.0): Direct element access!
palette.colors[1] = "red"
palette.colors[#palette.colors + 1] = "blue"  -- Append
```

### Features
- **Element Access**: Read and write individual array elements using familiar Lua syntax
- **Array Proxies**: Transparent proxy objects that maintain Swift-Lua bridging
- **Full Metamethod Support**: `__index`, `__newindex`, `__len`, `__ipairs`, `__tostring`
- **Type Safety**: Maintains type checking and validation for array elements
- **All Primitive Arrays**: Works with `[String]`, `[Int]`, `[Double]`, `[Bool]`

### Example
```swift
@LuaBridgeable
class ColorPalette: LuaBridgeable {
    public var colors: [String] = []
}
```

```lua
palette.colors = {"red", "green", "blue"}
palette.colors[2] = "lime"  -- Change green to lime
print(palette.colors[2])    -- "lime"

-- Iterate with ipairs
for i, color in ipairs(palette.colors) do
    print(i, color)
end
```

### Breaking Changes
None - this release is fully backward compatible.

### Installation
```swift
dependencies: [
    .package(url: "https://github.com/barryw/LuaKit", from: "1.1.0")
]
```

### Full Changelog
See [CHANGELOG.md](https://github.com/barryw/LuaKit/blob/main/CHANGELOG.md) for complete details.