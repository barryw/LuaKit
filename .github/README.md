# LuaKit CI/CD Pipeline

This directory contains the automated CI/CD pipeline for LuaKit, powered by GitHub Actions and Claude AI for intelligent release management.

## 🚀 Pipeline Overview

The CI/CD pipeline automatically:

1. **🔨 Builds and Tests** - Compiles for macOS and iOS, runs all tests
2. **🔍 Quality Checks** - Linting, formatting, and security scans
3. **🤖 AI Analysis** - Uses Claude to analyze changes and determine versions
4. **📝 Release Generation** - Automatically creates releases with AI-generated notes
5. **📦 Artifact Publishing** - Builds and publishes release artifacts
6. **📢 Notifications** - Sends status updates to Slack

## 📁 Files Structure

```
.github/
├── workflows/
│   └── ci-cd.yml              # Main CI/CD pipeline
├── scripts/
│   ├── analyze-version.js     # Claude-powered version analysis
│   ├── generate-release-notes.js # AI-generated release notes
│   └── package.json          # Node.js dependencies
└── README.md                 # This file
```

## 🔧 Pipeline Configuration

### Environment Variables Required

Set these in your GitHub repository secrets:

| Secret | Description | Required |
|--------|-------------|----------|
| `ANTHROPIC_API_KEY` | Claude AI API key for intelligent analysis | ✅ Yes |
| `GITHUB_TOKEN` | Automatically provided by GitHub Actions | ✅ Auto |
| `CODECOV_TOKEN` | For code coverage reporting | 🔹 Optional |
| `SLACK_WEBHOOK` | For Slack notifications | 🔹 Optional |

### Triggers

The pipeline runs on:
- **Push to `main`** - Full CI/CD with potential release
- **Push to `develop`** - Build and test only
- **Pull Requests to `main`** - Build, test, and quality checks

## 🤖 AI-Powered Release Management

### Version Analysis

The `analyze-version.js` script uses Claude to:

- **Analyze commits** since the last release
- **Examine changed files** and their significance
- **Determine release necessity** based on change impact
- **Calculate semantic version** (MAJOR.MINOR.PATCH)
- **Provide reasoning** for version decisions

#### Semantic Versioning Logic

- **MAJOR** (X.0.0) - Breaking changes, major API changes
- **MINOR** (0.X.0) - New features, backward-compatible enhancements
- **PATCH** (0.0.X) - Bug fixes, documentation, minor improvements

#### Skip Release Conditions

No release is created for:
- Only documentation changes
- CI/CD file modifications
- Code formatting/linting fixes
- Minor refactoring without functional changes

### Release Notes Generation

The `generate-release-notes.js` script creates comprehensive release notes including:

- **📋 Executive Summary** - High-level overview
- **✨ What's New** - Features and improvements with emojis
- **🐛 Bug Fixes** - Issues resolved
- **⚡ Technical Changes** - Under-the-hood improvements
- **💥 Breaking Changes** - API changes (if any)
- **📦 Installation** - Swift Package Manager instructions
- **🧪 Quality Metrics** - Test results and statistics
- **👥 Contributors** - Recognition of contributors

## 🔍 Quality Gates

### Build Requirements

All must pass for release:
- ✅ macOS build successful
- ✅ iOS Simulator build successful
- ✅ All tests passing (currently 65+ tests)
- ✅ SwiftLint checks passed
- ✅ Security scan clean

### Code Quality Standards

- **Line Length**: 120 characters (warning), 200 (error)
- **Function Length**: 50 lines (warning), 100 (error)
- **Cyclomatic Complexity**: 10 (warning), 20 (error)
- **Test Coverage**: Reported to Codecov
- **Security**: No secrets or vulnerabilities detected

## 📊 Pipeline Stages

### 1. Build and Test
```yaml
- Checkout code with full history
- Setup Xcode (latest stable)
- Cache Swift Package Manager dependencies
- Build for macOS (release configuration)
- Build for iOS Simulator
- Run tests with coverage
- Upload coverage to Codecov
- Archive build artifacts
```

### 2. Lint and Format
```yaml
- Setup SwiftLint
- Run linting with GitHub Actions reporter
- Check Swift formatting (if available)
- Validate code quality standards
```

### 3. Security Scan
```yaml
- Scan for secrets in code (GitLeaks)
- Check dependencies for vulnerabilities
- Generate security report
- Upload security artifacts
```

### 4. Auto Release (Main Branch Only)
```yaml
- Analyze changes with Claude AI
- Determine if release is needed
- Calculate semantic version
- Generate comprehensive release notes
- Create and push git tag
- Create GitHub release
- Build release artifacts
- Upload release assets
```

### 5. Notifications
```yaml
- Send success notification to Slack
- Include release information
- Send failure alerts with details
- Provide links to logs and artifacts
```

## 🛠️ Local Development

### Running Scripts Locally

1. **Install dependencies**:
   ```bash
   cd .github/scripts
   npm install
   ```

2. **Set environment variables**:
   ```bash
   export ANTHROPIC_API_KEY="your-claude-api-key"
   export GITHUB_TOKEN="your-github-token"
   ```

3. **Run version analysis**:
   ```bash
   node analyze-version.js
   ```

4. **Generate release notes**:
   ```bash
   node generate-release-notes.js "1.4.0"
   ```

### Testing SwiftLint Rules

```bash
# Install SwiftLint
brew install swiftlint

# Run linting
swiftlint lint

# Auto-fix issues
swiftlint --fix
```

## 🔧 Configuration Customization

### Modifying Version Logic

Edit `analyze-version.js` to customize:
- Commit message patterns
- File change significance
- Version bump criteria
- Release skip conditions

### Customizing Release Notes

Edit `generate-release-notes.js` to modify:
- Release note sections
- Formatting and styling
- Information included
- Fallback behavior

### Adjusting Quality Gates

Edit `.swiftlint.yml` to customize:
- Code style rules
- Complexity thresholds
- Naming conventions
- Custom rule patterns

## 📈 Monitoring and Metrics

### Available Reports

- **Build Status**: Pass/fail for each platform
- **Test Coverage**: Detailed coverage reports via Codecov
- **Code Quality**: SwiftLint violations and trends
- **Security**: Vulnerability scans and dependency analysis
- **Performance**: Build times and test execution metrics

### Accessing Logs

1. **GitHub Actions**: Repository → Actions tab
2. **Individual Runs**: Click on specific workflow run
3. **Step Details**: Expand each step for detailed logs
4. **Artifacts**: Download build artifacts and reports

## 🚨 Troubleshooting

### Common Issues

1. **Claude API Failures**
   - Check API key validity
   - Verify API rate limits
   - Review error logs for specific issues
   - Fallback logic will trigger automatically

2. **Build Failures**
   - Check Xcode version compatibility
   - Verify Swift Package dependencies
   - Review compilation errors in logs

3. **Test Failures**
   - Individual test failure details in logs
   - Check for environment-specific issues
   - Verify test data and fixtures

4. **Release Creation Failures**
   - Check GitHub token permissions
   - Verify tag creation permissions
   - Review release note generation logs

### Emergency Procedures

1. **Disable Auto-Release**
   - Comment out the `auto-release` job in `ci-cd.yml`
   - Push change to temporarily disable releases

2. **Manual Release**
   - Run scripts locally with proper environment
   - Create release manually through GitHub UI
   - Use generated release notes as template

3. **Rollback Release**
   - Delete problematic tag and release
   - Fix issues and re-trigger pipeline
   - Update version numbers if needed

## 🔮 Future Enhancements

Planned improvements:
- **Multi-platform builds** (Linux, Windows via Swift on other platforms)
- **Performance benchmarking** with historical tracking
- **Automated changelog** maintenance
- **Dependency update automation** with compatibility testing
- **Enhanced security scanning** with SARIF reports
- **Integration testing** with sample projects

## 📞 Support

For pipeline issues:
1. Check the troubleshooting section above
2. Review GitHub Actions logs
3. Create an issue with pipeline logs attached
4. Contact maintainers for urgent issues

---

*This CI/CD pipeline is designed to maintain high code quality while automating the release process. The AI-powered version analysis ensures appropriate versioning and comprehensive release documentation.*