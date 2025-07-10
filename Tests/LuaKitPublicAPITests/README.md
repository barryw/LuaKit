# LuaKit Public API Tests

This test target specifically tests LuaKit's public API by importing it WITHOUT `@testable`.

## Purpose

These tests ensure that:
1. All public APIs are actually accessible to external consumers
2. The @LuaBridgeable macro generates code that works with the public API
3. Array proxy functionality works when used as an external dependency

## Key Difference from Regular Tests

- Regular tests: `@testable import LuaKit` (access to internal members)
- Public API tests: `import LuaKit` (only public members accessible)

## Bug History

In LuaKit 1.1.0, the array element access feature was broken for consumers because:
- The `LuaArrayProxy` initializer was `internal` (default access level)
- The macro generated code that tried to create proxy instances
- This worked in tests (due to `@testable`) but failed for actual consumers
- The fix: Changed the initializer to `public` in version 1.1.1

## Running These Tests

```bash
swift test --filter ArrayProxyPublicAPITest
```

These tests would fail to compile if the array proxy initializers were not public.