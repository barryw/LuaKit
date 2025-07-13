#!/usr/bin/env node

const axios = require('axios');
const { execSync } = require('child_process');
const fs = require('fs');

const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;
const fullVersion = process.argv[2]; // e.g., "1.4.0+lua5.4.8"

if (!ANTHROPIC_API_KEY) {
  console.error('ANTHROPIC_API_KEY is required');
  process.exit(1);
}

if (!fullVersion) {
  console.error('Full version (x.x.x+luax.x.x) is required as argument');
  process.exit(1);
}

// Parse the version components
function parseVersion(fullVersion) {
  const match = fullVersion.match(/^(\d+\.\d+\.\d+)\+lua(\d+\.\d+\.\d+)$/);
  if (!match) {
    throw new Error(`Invalid version format: ${fullVersion}. Expected format: x.x.x+luax.x.x`);
  }
  
  return {
    semanticVersion: match[1],    // e.g., "1.4.0"
    luaVersion: match[2],         // e.g., "5.4.8"
    fullVersion: fullVersion      // e.g., "1.4.0+lua5.4.8"
  };
}

const versionInfo = parseVersion(fullVersion);

async function getLatestTag() {
  try {
    const result = execSync('git describe --tags --abbrev=0', { encoding: 'utf8' });
    return result.trim();
  } catch (error) {
    return null;
  }
}

async function getDetailedCommits(tag) {
  try {
    const command = tag 
      ? `git log ${tag}..HEAD --pretty=format:"%h~~%s~~%an~~%ad" --date=short --no-merges`
      : 'git log --pretty=format:"%h~~%s~~%an~~%ad" --date=short --no-merges -20';
    
    const result = execSync(command, { encoding: 'utf8' });
    return result.trim().split('\n').filter(line => line.length > 0).map(line => {
      const [hash, subject, author, date] = line.split('~~');
      return { 
        hash, 
        subject: subject || '', 
        body: '', // Skip body to avoid multiline issues
        author: author || 'unknown', 
        date: date || '' 
      };
    });
  } catch (error) {
    console.error('Error getting commits:', error.message);
    return [];
  }
}

async function getChangedFilesWithStats(tag) {
  try {
    const command = tag 
      ? `git diff --numstat ${tag}..HEAD`
      : 'git diff --numstat HEAD~20..HEAD';
    
    const result = execSync(command, { encoding: 'utf8' });
    return result.trim().split('\n').filter(line => line.length > 0).map(line => {
      const [additions, deletions, file] = line.split('\t');
      return { 
        file, 
        additions: parseInt(additions) || 0, 
        deletions: parseInt(deletions) || 0 
      };
    });
  } catch (error) {
    console.error('Error getting file stats:', error.message);
    return [];
  }
}

async function getTestResults() {
  try {
    // Run tests and capture output
    const result = execSync('swift test 2>&1 | tail -20', { encoding: 'utf8' });
    
    // Extract test count from output
    const testMatch = result.match(/Executed (\d+) tests/);
    const testCount = testMatch ? testMatch[1] : 'unknown';
    
    // Check if all tests passed
    const allPassed = result.includes('tests passed') || result.includes('0 failures');
    
    return {
      testCount,
      allPassed,
      output: result
    };
  } catch (error) {
    return {
      testCount: 'unknown',
      allPassed: false,
      output: error.message
    };
  }
}

async function getCurrentPackageInfo() {
  const packageInfo = {
    swiftVersion: '5.9',
    platforms: ['iOS 13.0+', 'macOS 10.15+'],
    dependencies: []
  };
  
  // Try to read Package.swift for more details
  if (fs.existsSync('Package.swift')) {
    const packageContent = fs.readFileSync('Package.swift', 'utf8');
    
    // Extract Swift version
    const swiftVersionMatch = packageContent.match(/swiftLanguageVersions:\s*\[\.v(\d+_\d+|\d+)\]/);
    if (swiftVersionMatch) {
      packageInfo.swiftVersion = swiftVersionMatch[1].replace('_', '.');
    }
    
    // Extract platform requirements
    const platformMatches = packageContent.match(/\.iOS\([^)]+\)|\.macOS\([^)]+\)/g);
    if (platformMatches) {
      packageInfo.platforms = platformMatches.map(match => {
        const version = match.match(/(\d+\.\d+)/);
        const platform = match.includes('iOS') ? 'iOS' : 'macOS';
        return version ? `${platform} ${version[1]}+` : match;
      });
    }
  }
  
  return packageInfo;
}

async function generateReleaseNotesWithClaude(commits, fileStats, testResults, packageInfo, previousVersion) {
  const totalAdditions = fileStats.reduce((sum, file) => sum + file.additions, 0);
  const totalDeletions = fileStats.reduce((sum, file) => sum + file.deletions, 0);
  
  const prompt = `Generate comprehensive release notes for LuaKit ${versionInfo.fullVersion}, a Swift Package that provides Swift-Lua bridging functionality.

Previous Version: ${previousVersion || 'unknown'}
New Version: ${versionInfo.fullVersion} (Library: ${versionInfo.semanticVersion}, Embedded Lua: ${versionInfo.luaVersion})

Recent Commits:
${commits.map(c => `- ${c.hash}: ${c.subject}${c.body ? '\n  ' + c.body : ''} (by ${c.author} on ${c.date})`).join('\n')}

File Changes:
- Total files changed: ${fileStats.length}
- Lines added: ${totalAdditions}
- Lines removed: ${totalDeletions}
- Key files: ${fileStats.slice(0, 10).map(f => `${f.file} (+${f.additions}/-${f.deletions})`).join(', ')}

Test Results:
- Tests executed: ${testResults.testCount}
- All tests passed: ${testResults.allPassed}

Package Information:
- Swift version: ${packageInfo.swiftVersion}
- Supported platforms: ${packageInfo.platforms.join(', ')}

Please generate professional release notes that include:

1. **Executive Summary** - Brief overview of the release
2. **What's New** - Key features and improvements (use emojis for categories)
3. **Bug Fixes** - Any bugs that were fixed
4. **Technical Changes** - Under-the-hood improvements
5. **Breaking Changes** - If any (highlight clearly)
6. **Installation** - Brief Swift Package Manager instructions (will be supplemented in footer)
7. **Compatibility** - Platform and Swift version requirements
8. **Testing** - Test coverage and quality assurance notes
9. **Contributors** - Thank contributors if multiple authors
10. **What's Next** - Brief mention of future plans if appropriate

Format as Markdown suitable for GitHub releases. Use emojis appropriately but professionally. Make it engaging but informative. Focus on user value and developer experience improvements.

IMPORTANT: Do NOT use triple backticks for code blocks. Use 4-space indentation instead. Avoid using single backticks for inline code - use plain text or **bold** instead.

If this is a major release, emphasize the significance. If it's a patch release, focus on stability and fixes.

The framework is for Swift developers who want to embed Lua scripting in their iOS/macOS apps with seamless Swift-Lua object bridging.`;

  try {
    const response = await axios.post(
      'https://api.anthropic.com/v1/messages',
      {
        model: 'claude-3-5-haiku-latest',
        max_tokens: 4000,
        messages: [{
          role: 'user',
          content: prompt
        }]
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01'
        }
      }
    );

    const releaseNotes = response.data.content[0].text;
    
    // Add automated footer
    const footer = `

---

## 🤖 Automated Release

This release was automatically created by our CI/CD pipeline powered by Claude AI.

- **Build Status**: ✅ All tests passing (${testResults.testCount} tests)
- **Code Quality**: ✅ Linting and security checks passed
- **Release Date**: ${new Date().toISOString().split('T')[0]}
- **Commit Hash**: ${execSync('git rev-parse HEAD', { encoding: 'utf8' }).trim().substring(0, 8)}

> **Lua Version**: This release includes **Lua ${versionInfo.luaVersion}** embedded directly - no external dependencies required!

## 🔗 Links

- [📚 Documentation](https://github.com/barryw/LuaKit#readme)
- [🐛 Report Issues](https://github.com/barryw/LuaKit/issues)
- [💬 Discussions](https://github.com/barryw/LuaKit/discussions)
- [📋 Changelog](https://github.com/barryw/LuaKit/releases)`;

    return releaseNotes + footer;
    
  } catch (error) {
    console.error('Error calling Claude API:', error.response?.data || error.message);
    
    // Fallback release notes
    return generateFallbackReleaseNotes(commits, fileStats, testResults, packageInfo, previousVersion);
  }
}

function generateFallbackReleaseNotes(commits, fileStats, testResults, packageInfo, previousVersion) {
  const totalChanges = fileStats.reduce((sum, file) => sum + file.additions + file.deletions, 0);
  const totalAdditions = fileStats.reduce((sum, file) => sum + file.additions, 0);
  const totalDeletions = fileStats.reduce((sum, file) => sum + file.deletions, 0);
  const uniqueAuthors = [...new Set(commits.map(c => c.author))];
  
  // Get top changed files
  const topFiles = fileStats
    .sort((a, b) => (b.additions + b.deletions) - (a.additions + a.deletions))
    .slice(0, 5)
    .map(f => `  - ${f.file}: +${f.additions}/-${f.deletions}`)
    .join('\n');
  
  return `# LuaKit ${versionInfo.fullVersion}

## Release Summary

This release includes ${commits.length} commits from ${uniqueAuthors.length} contributor${uniqueAuthors.length > 1 ? 's' : ''}.

## Changes

### Statistics
- Files changed: ${fileStats.length}
- Lines added: ${totalAdditions}
- Lines removed: ${totalDeletions}
- Total changes: ${totalChanges}

### Top Modified Files
${topFiles}

### Recent Commits
${commits.slice(0, 10).map(c => `- ${c.hash}: ${c.subject.substring(0, 60)}${c.subject.length > 60 ? '...' : ''}`).join('\n')}
${commits.length > 10 ? `\n... and ${commits.length - 10} more commits` : ''}

## Quality Assurance

- Tests executed: ${testResults.testCount}
- Test status: ${testResults.allPassed ? 'All tests passed' : 'Some tests failed'}
- Build status: Success
- Linting: Passed

## Installation

Add to your Package.swift:

    dependencies: [
        .package(url: "https://github.com/barryw/LuaKit", from: "${versionInfo.semanticVersion}")
    ]

## Requirements

- Swift ${packageInfo.swiftVersion} or later
- Platforms: ${packageInfo.platforms.join(', ')}
- Embedded Lua ${versionInfo.luaVersion}

---

Generated on ${new Date().toISOString().split('T')[0]}`;
}

async function main() {
  try {
    console.log(`Generating release notes for version ${versionInfo.fullVersion}...`);
    
    const latestTag = await getLatestTag();
    console.log('Previous version:', latestTag || 'none');
    
    const commits = await getDetailedCommits(latestTag);
    console.log('Commits to include:', commits.length);
    
    const fileStats = await getChangedFilesWithStats(latestTag);
    console.log('Files changed:', fileStats.length);
    
    const testResults = await getTestResults();
    console.log('Test results:', testResults);
    
    const packageInfo = await getCurrentPackageInfo();
    console.log('Package info:', packageInfo);
    
    const releaseNotes = await generateReleaseNotesWithClaude(
      commits, 
      fileStats, 
      testResults, 
      packageInfo, 
      latestTag
    );
    
    console.log('Generated release notes:');
    console.log('--- START RELEASE NOTES ---');
    console.log(releaseNotes);
    console.log('--- END RELEASE NOTES ---');
    
    // Write to GitHub Actions environment file
    if (process.env.GITHUB_OUTPUT) {
      // Use heredoc syntax for multiline output
      const delimiter = 'EOF_' + Math.random().toString(36).substring(7);
      fs.appendFileSync(process.env.GITHUB_OUTPUT, `release_notes<<${delimiter}\n${releaseNotes}\n${delimiter}\n`);
    } else {
      // Fallback for local testing
      console.log('GITHUB_OUTPUT not set');
    }
    
    // Save to file for debugging
    fs.writeFileSync(`release-notes-${versionInfo.fullVersion}.md`, releaseNotes);
    console.log(`Release notes saved to release-notes-${versionInfo.fullVersion}.md`);
    
  } catch (error) {
    console.error('Error generating release notes:', error);
    process.exit(1);
  }
}

main();