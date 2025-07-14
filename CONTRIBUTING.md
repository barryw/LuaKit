# Contributing to LuaKit

Thank you for your interest in contributing to LuaKit! This guide will help you get started.

## Getting Started

1. Fork the repository on GitHub
2. Clone your fork locally
3. Create a new branch for your feature or fix
4. Make your changes
5. Submit a pull request

## Development Setup

### Prerequisites

- Xcode 15.0 or later
- Swift 5.9 or later
- macOS 12.0 or later (for development)

### Building the Project

```bash
# Clone the repository
git clone https://github.com/yourusername/LuaKit.git
cd LuaKit

# Build the project
swift build

# Run tests
swift test
```

### Running Tests

```bash
# Run all tests
swift test

# Run tests with coverage
swift test --enable-code-coverage

# Run specific test
swift test --filter LuaStateTests
```

## Code Style

### Swift Style

We follow standard Swift conventions:

- Use 4 spaces for indentation (not tabs)
- Follow Swift API Design Guidelines
- Keep lines under 120 characters when possible
- Use meaningful variable and function names

### SwiftLint

The project uses SwiftLint for code style enforcement:

```bash
# Install SwiftLint (if not already installed)
brew install swiftlint

# Run SwiftLint
swiftlint

# Auto-fix issues
swiftlint --fix
```

### Documentation

- Add documentation comments for all public APIs
- Use `///` for single-line documentation
- Use `/** */` for multi-line documentation
- Include examples in documentation when helpful

Example:
```swift
/// Executes a Lua script and returns the output
/// 
/// - Parameter code: The Lua code to execute
/// - Returns: Output from print statements
/// - Throws: `LuaError.syntax` or `LuaError.runtime`
public func execute(_ code: String) throws -> String {
    // Implementation
}
```

## Making Changes

### Before You Start

1. Check existing issues and pull requests
2. Open an issue to discuss significant changes
3. For bugs, include reproduction steps
4. For features, explain the use case

### Commit Messages

Follow conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `test`: Test additions or fixes
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `chore`: Maintenance tasks

Examples:
```
feat(bridging): add support for Dictionary types
fix(macro): handle internal visibility correctly
docs(api): add LuaValue documentation
test(arrays): add array proxy tests
```

### Pull Request Process

1. Update documentation for any API changes
2. Add tests for new functionality
3. Ensure all tests pass
4. Update CHANGELOG.md if applicable
5. Ensure SwiftLint passes
6. Submit PR against the `main` branch

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Tests pass locally
- [ ] New tests added
- [ ] Documentation updated

## Related Issues
Fixes #(issue number)
```

## Testing Guidelines

### Unit Tests

- Write tests for all new functionality
- Maintain or improve code coverage
- Use descriptive test names
- Follow Arrange-Act-Assert pattern

Example:
```swift
func testExecuteReturnsOutput() throws {
    // Arrange
    let lua = try LuaState()
    
    // Act
    let output = try lua.execute("print('Hello')")
    
    // Assert
    XCTAssertEqual(output, "Hello\n")
}
```

### Integration Tests

- Test interactions between components
- Test real-world usage scenarios
- Include performance tests for critical paths

## Project Structure

```
LuaKit/
├── Sources/
│   ├── Lua/              # Embedded Lua C source
│   ├── LuaKit/           # Main Swift framework
│   └── LuaMacros/        # Swift macro implementations
├── Tests/
│   ├── LuaKitTests/      # Unit tests
│   └── LuaKitPublicAPITests/  # Public API tests
├── Documentation/        # Documentation files
├── Examples/            # Example code
└── Package.swift        # Package manifest
```

## Areas for Contribution

### Current Needs

- Performance optimizations
- Additional type bridging support
- More comprehensive examples
- Documentation improvements
- Bug fixes

### Future Features

- Async/await support improvements
- Enhanced debugging tools
- Additional platform support
- Performance profiling tools

## Debugging

### Debug Mode

Enable debug mode for detailed output:

```swift
LuaFunction.debugMode = true
```

### Common Issues

1. **SwiftSyntax compilation timeout**: Build in release mode
2. **Memory leaks**: Check for reference cycles
3. **Type conversion errors**: Verify supported types

## Release Process

Releases are automated through CI/CD:

1. All commits to `main` trigger version analysis
2. Semantic versioning based on changes
3. Automated release notes generation
4. GitHub release creation

## Getting Help

- Open an issue for bugs or features
- Join discussions for questions
- Check existing documentation
- Review closed issues for solutions

## Code of Conduct

- Be respectful and inclusive
- Welcome newcomers
- Provide constructive feedback
- Focus on what is best for the community

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Recognition

Contributors will be:
- Listed in release notes
- Credited in commit messages
- Acknowledged in the README (for significant contributions)

Thank you for contributing to LuaKit!