#!/usr/bin/env node

const axios = require('axios');
const { execSync } = require('child_process');
const fs = require('fs');

const ANTHROPIC_API_KEY = process.env.ANTHROPIC_API_KEY;
const GITHUB_TOKEN = process.env.GITHUB_TOKEN;

if (!ANTHROPIC_API_KEY) {
  console.error('ANTHROPIC_API_KEY is required');
  process.exit(1);
}

async function getLatestTag() {
  try {
    const result = execSync('git describe --tags --abbrev=0', { encoding: 'utf8' });
    return result.trim();
  } catch (error) {
    console.log('No previous tags found');
    return null;
  }
}

async function getCommitsSinceTag(tag) {
  try {
    const command = tag 
      ? `git log ${tag}..HEAD --oneline --no-merges`
      : 'git log --oneline --no-merges -10'; // Last 10 commits if no tag
    
    const result = execSync(command, { encoding: 'utf8' });
    return result.trim().split('\n').filter(line => line.length > 0);
  } catch (error) {
    console.error('Error getting commits:', error.message);
    return [];
  }
}

async function getChangedFiles(tag) {
  try {
    const command = tag 
      ? `git diff --name-only ${tag}..HEAD`
      : 'git diff --name-only HEAD~10..HEAD';
    
    const result = execSync(command, { encoding: 'utf8' });
    return result.trim().split('\n').filter(line => line.length > 0);
  } catch (error) {
    console.error('Error getting changed files:', error.message);
    return [];
  }
}

async function getCurrentVersion() {
  const packageSwiftPath = 'Package.swift';
  const readmePath = 'README.md';
  
  let version = '1.3.0'; // Default fallback
  
  // Try to extract version from Package.swift
  if (fs.existsSync(packageSwiftPath)) {
    const packageContent = fs.readFileSync(packageSwiftPath, 'utf8');
    const versionMatch = packageContent.match(/version:\s*"([^"]+)"/);
    if (versionMatch) {
      version = versionMatch[1];
    }
  }
  
  // Try to extract version from README.md
  if (fs.existsSync(readmePath)) {
    const readmeContent = fs.readFileSync(readmePath, 'utf8');
    const versionMatch = readmeContent.match(/from:\s*"([^"]+)"/);
    if (versionMatch) {
      version = versionMatch[1];
    }
  }
  
  // Strip any existing lua suffix to get clean semantic version
  version = version.replace(/\+lua[\d.]+$/, '');
  
  return version;
}

function getLuaVersion() {
  try {
    const luaHeaderPath = 'Sources/Lua/include/lua.h';
    if (fs.existsSync(luaHeaderPath)) {
      const headerContent = fs.readFileSync(luaHeaderPath, 'utf8');
      
      // Extract version components from Lua header
      const majorMatch = headerContent.match(/#define\s+LUA_VERSION_MAJOR\s+"(\d+)"/);
      const minorMatch = headerContent.match(/#define\s+LUA_VERSION_MINOR\s+"(\d+)"/);
      const releaseMatch = headerContent.match(/#define\s+LUA_VERSION_RELEASE\s+"(\d+)"/);
      
      if (majorMatch && minorMatch && releaseMatch) {
        return `${majorMatch[1]}.${minorMatch[1]}.${releaseMatch[1]}`;
      }
    }
  } catch (error) {
    console.log('Could not parse Lua version from header, using fallback');
  }
  
  // Fallback to known version
  return '5.4.8';
}

function formatVersionWithLua(semanticVersion) {
  const luaVersion = getLuaVersion();
  return `${semanticVersion}+lua${luaVersion}`;
}

async function analyzeWithClaude(commits, changedFiles, currentVersion) {
  const prompt = `Analyze the following changes to a Swift Package (LuaKit - Swift-Lua bridging framework) and determine if a new release should be created and what the semantic version should be.

Current Version: ${currentVersion}

Recent Commits:
${commits.join('\n')}

Changed Files:
${changedFiles.join('\n')}

Please analyze these changes and determine:

1. Should a new release be created? (yes/no)
2. What should the new semantic version be? (follow semver: MAJOR.MINOR.PATCH)

Guidelines:
- MAJOR: Breaking changes, major new features that change the API
- MINOR: New features, enhancements that are backward compatible
- PATCH: Bug fixes, documentation updates, minor improvements
- Don't create a release for: minor docs, CI changes, formatting, etc.

Consider:
- Changes to Sources/ are more significant than changes to docs
- New features in Swift files warrant minor version bumps
- Breaking changes warrant major version bumps
- Bug fixes warrant patch version bumps
- Multiple features may warrant minor bumps
- Look for keywords like "feat:", "fix:", "BREAKING CHANGE:", etc.

Respond with a JSON object only:
{
  "should_release": true/false,
  "new_version": "X.Y.Z",
  "release_type": "major/minor/patch",
  "reasoning": "Brief explanation of the decision",
  "changelog_summary": "Brief summary of changes for release notes"
}`;

  try {
    const response = await axios.post(
      'https://api.anthropic.com/v1/messages',
      {
        model: 'claude-3-sonnet-20240229',
        max_tokens: 1000,
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

    const content = response.data.content[0].text;
    console.log('Claude response:', content);
    
    // Extract JSON from response
    const jsonMatch = content.match(/\{[\s\S]*\}/);
    if (!jsonMatch) {
      throw new Error('No JSON found in Claude response');
    }
    
    return JSON.parse(jsonMatch[0]);
  } catch (error) {
    console.error('Error calling Claude API:', error.response?.data || error.message);
    
    // Fallback logic if Claude fails
    const hasSourceChanges = changedFiles.some(file => file.startsWith('Sources/'));
    const hasBreakingChanges = commits.some(commit => 
      commit.toLowerCase().includes('breaking') || 
      commit.toLowerCase().includes('major')
    );
    const hasFeatures = commits.some(commit => 
      commit.toLowerCase().includes('feat') || 
      commit.toLowerCase().includes('add') ||
      commit.toLowerCase().includes('new')
    );
    const hasFixes = commits.some(commit => 
      commit.toLowerCase().includes('fix') || 
      commit.toLowerCase().includes('bug')
    );
    
    if (!hasSourceChanges && commits.length < 3) {
      return {
        should_release: false,
        new_version: currentVersion,
        release_type: 'none',
        reasoning: 'No significant changes detected',
        changelog_summary: 'Minor updates'
      };
    }
    
    // Determine version bump
    let newVersion = currentVersion;
    const versionParts = currentVersion.split('.').map(Number);
    
    if (hasBreakingChanges) {
      versionParts[0] += 1;
      versionParts[1] = 0;
      versionParts[2] = 0;
    } else if (hasFeatures) {
      versionParts[1] += 1;
      versionParts[2] = 0;
    } else if (hasFixes) {
      versionParts[2] += 1;
    }
    
    newVersion = versionParts.join('.');
    
    return {
      should_release: hasSourceChanges || commits.length >= 3,
      new_version: newVersion,
      release_type: hasBreakingChanges ? 'major' : hasFeatures ? 'minor' : 'patch',
      reasoning: 'Fallback analysis based on commit patterns',
      changelog_summary: `${commits.length} commits with ${changedFiles.length} changed files`
    };
  }
}

async function main() {
  try {
    console.log('Analyzing changes for version determination...');
    
    const latestTag = await getLatestTag();
    console.log('Latest tag:', latestTag || 'none');
    
    const commits = await getCommitsSinceTag(latestTag);
    console.log('Commits since last tag:', commits.length);
    
    const changedFiles = await getChangedFiles(latestTag);
    console.log('Changed files:', changedFiles.length);
    
    const currentVersion = await getCurrentVersion();
    console.log('Current version:', currentVersion);
    
    if (commits.length === 0) {
      console.log('No new commits since last tag');
      console.log('::set-output name=should_release::false');
      console.log(`::set-output name=new_version::${currentVersion}`);
      return;
    }
    
    const analysis = await analyzeWithClaude(commits, changedFiles, currentVersion);
    
    console.log('Analysis result:', analysis);
    
    // Format version with Lua suffix
    const formattedVersion = formatVersionWithLua(analysis.new_version);
    
    // Set GitHub Actions outputs
    console.log(`::set-output name=should_release::${analysis.should_release}`);
    console.log(`::set-output name=new_version::${analysis.new_version}`);
    console.log(`::set-output name=full_version::${formattedVersion}`);
    console.log(`::set-output name=lua_version::${getLuaVersion()}`);
    console.log(`::set-output name=release_type::${analysis.release_type}`);
    console.log(`::set-output name=reasoning::${analysis.reasoning}`);
    console.log(`::set-output name=changelog_summary::${analysis.changelog_summary}`);
    
    // Also write to environment file for newer GitHub Actions
    if (process.env.GITHUB_OUTPUT) {
      const outputs = [
        `should_release=${analysis.should_release}`,
        `new_version=${analysis.new_version}`,
        `full_version=${formattedVersion}`,
        `lua_version=${getLuaVersion()}`,
        `release_type=${analysis.release_type}`,
        `reasoning=${analysis.reasoning}`,
        `changelog_summary=${analysis.changelog_summary}`
      ].join('\n');
      
      fs.appendFileSync(process.env.GITHUB_OUTPUT, outputs + '\n');
    }
    
  } catch (error) {
    console.error('Error in version analysis:', error);
    process.exit(1);
  }
}

main();