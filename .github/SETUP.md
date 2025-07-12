# CI/CD Pipeline Setup Guide

This guide will help you set up the automated CI/CD pipeline for LuaKit with AI-powered release management.

## 🔑 Required Secrets

### 1. Anthropic API Key (Required)

The pipeline uses Claude AI to analyze changes and generate release notes.

#### Getting an Anthropic API Key:
1. Go to [Anthropic Console](https://console.anthropic.com/)
2. Sign up or log in to your account
3. Navigate to "API Keys" section
4. Create a new API key
5. Copy the API key (starts with `sk-ant-`)

#### Adding to GitHub:
1. Go to your repository on GitHub
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**
4. Name: `ANTHROPIC_API_KEY`
5. Value: Your API key (e.g., `sk-ant-api-key-here`)
6. Click **Add secret**

### 2. Optional Secrets

#### Codecov Token (Optional - for code coverage)
1. Go to [Codecov](https://codecov.io/)
2. Sign up with your GitHub account
3. Add your repository
4. Copy the upload token
5. Add as `CODECOV_TOKEN` in repository secrets

#### Slack Webhook (Optional - for notifications)
1. Create a Slack app in your workspace
2. Add Incoming Webhooks feature
3. Create a webhook URL for your channel
4. Add as `SLACK_WEBHOOK` in repository secrets

## 🚀 Activation Steps

### 1. Commit Pipeline Files

The pipeline files are already created in your repository:
```
.github/
├── workflows/
│   ├── ci-cd.yml           # Main CI/CD pipeline
│   └── test-ci-setup.yml   # Setup testing workflow
└── scripts/
    ├── analyze-version.js  # AI version analysis
    ├── generate-release-notes.js # AI release notes
    └── package.json        # Dependencies
```

### 2. Test the Setup

1. **Manual Test**: Go to Actions tab → "Test CI Setup" → "Run workflow"
2. **Check Results**: Verify all steps complete successfully
3. **Review Logs**: Ensure SwiftLint and build tools work correctly

### 3. Enable Full Pipeline

1. **Add API Key**: Ensure `ANTHROPIC_API_KEY` is configured
2. **Push to Main**: Any push to main branch will trigger full pipeline
3. **Monitor**: Watch the Actions tab for pipeline execution

## 🔧 Pipeline Behavior

### Automatic Releases

The pipeline will automatically create releases when:
- ✅ Push to `main` branch
- ✅ All tests pass
- ✅ Code quality checks pass
- ✅ AI determines changes warrant a release

### Version Determination

Claude AI analyzes:
- **Commit messages** for feature/fix/breaking change keywords
- **Changed files** and their significance
- **Code diff statistics** to assess impact
- **Previous version** to calculate appropriate bump

#### Version Format: `x.x.x+luax.x.x`

All versions follow this strict format:
- **Library Version**: Semantic versioning (MAJOR.MINOR.PATCH)
  - `MAJOR`: Breaking changes, major API changes
  - `MINOR`: New features, backward-compatible enhancements  
  - `PATCH`: Bug fixes, documentation, minor improvements
- **Lua Version**: Embedded Lua version (e.g., `+lua5.4.8`)

Examples:
- `1.4.0+lua5.4.8` - Minor feature release with Lua 5.4.8
- `2.0.0+lua5.4.8` - Major breaking changes with Lua 5.4.8
- `1.3.1+lua5.4.8` - Patch release with Lua 5.4.8

This ensures consumers always know:
- ✅ Which library features they're getting
- ✅ Which Lua version is embedded
- ✅ Compatibility expectations

### Release Creation

When a release is warranted:
1. **Version calculated** using semantic versioning with Lua suffix
2. **Tag created** with format `X.Y.Z+luaX.Y.Z` (e.g., `1.4.0+lua5.4.8`)
3. **Release notes generated** with comprehensive details including Lua version info
4. **Artifacts built** and attached to release
5. **Package.swift compatibility** ensured for consumers
6. **Notifications sent** (if configured)

## 📊 Monitoring

### GitHub Actions

- **Actions Tab**: View all pipeline runs
- **Workflow Runs**: Click individual runs for detailed logs
- **Artifacts**: Download build outputs and reports

### Quality Metrics

- **Test Results**: All test outcomes and coverage
- **Code Quality**: SwiftLint violations and improvements
- **Security**: Vulnerability scans and dependency checks
- **Performance**: Build times and optimization opportunities

## 🛠️ Customization

### Adjusting Release Criteria

Edit `.github/scripts/analyze-version.js`:
```javascript
// Modify these patterns to change release criteria
const hasFeatures = commits.some(commit => 
  commit.toLowerCase().includes('feat') || 
  commit.toLowerCase().includes('add') ||
  commit.toLowerCase().includes('new')
);
```

### Customizing Release Notes

Edit `.github/scripts/generate-release-notes.js`:
```javascript
// Modify the prompt to change release note style
const prompt = `Generate release notes that include:
1. Executive Summary
2. What's New
3. Bug Fixes
...`;
```

### Code Quality Rules

Edit `.swiftlint.yml`:
```yaml
# Adjust these values to change quality standards
line_length:
  warning: 120
  error: 200

function_body_length:
  warning: 50
  error: 100
```

## 🚨 Troubleshooting

### Common Issues

#### 1. "ANTHROPIC_API_KEY not found"
- ✅ **Solution**: Add the API key to repository secrets
- 🔍 **Check**: Settings → Secrets → Actions → ANTHROPIC_API_KEY

#### 2. "SwiftLint command not found"
- ✅ **Solution**: The pipeline installs SwiftLint automatically
- 🔍 **Check**: Review the "lint-and-format" job logs

#### 3. "Tests failing in CI"
- ✅ **Solution**: Tests should pass locally first
- 🔍 **Check**: Run `swift test` locally before pushing

#### 4. "No release created"
- ✅ **Solution**: AI may determine changes don't warrant release
- 🔍 **Check**: Review version analysis logs for reasoning

### Getting Help

1. **Review Logs**: Check GitHub Actions logs for specific errors
2. **Test Locally**: Run scripts locally with proper environment variables
3. **Create Issue**: Include relevant logs and error messages
4. **Check Status**: Verify all required secrets are configured

## 🔮 Advanced Features

### Manual Release Trigger

To force a release regardless of AI analysis:
```bash
# Create and push a tag manually (always include Lua version)
git tag -a "1.4.0+lua5.4.8" -m "Manual release 1.4.0 with Lua 5.4.8"
git push origin "1.4.0+lua5.4.8"
```

**Important**: Always use the `x.x.x+luax.x.x` format for consistency!

### Branch-Specific Behavior

- **`main`**: Full CI/CD with releases
- **`develop`**: Build and test only
- **Feature branches**: Test on pull request only

### Custom Workflows

Add your own workflows in `.github/workflows/`:
```yaml
name: Custom Check
on:
  pull_request:
jobs:
  custom:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: Your custom step
        run: echo "Custom logic here"
```

## ✅ Verification Checklist

Before going live:
- [ ] ANTHROPIC_API_KEY added to repository secrets
- [ ] Test workflow runs successfully
- [ ] SwiftLint configuration works with your code style
- [ ] All existing tests pass in CI environment
- [ ] Build succeeds for both macOS and iOS platforms
- [ ] Review pipeline permissions and security settings

---

*The CI/CD pipeline is designed to be zero-maintenance once configured. It will intelligently manage releases while maintaining high code quality standards.*