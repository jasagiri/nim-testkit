# VCS Integration Guide

Nim TestKit provides comprehensive version control system integration, supporting both traditional VCS operations and modern MCP-based unified operations.

## Overview

The VCS integration offers two approaches:

1. **Traditional VCS Integration** - Direct command-line tool integration
2. **MCP-based Integration** - Protocol-based unified operations

## Supported Version Control Systems

| VCS | Traditional Support | MCP Support | Features |
|-----|-------------------|-------------|----------|
| **Git** | ✅ Full | ✅ Full | Local operations, hooks |
| **GitHub** | ⚠️ Limited | ✅ Full | Issues, PRs, API operations |
| **GitLab** | ⚠️ Limited | ✅ Full | Issues, MRs, API operations |
| **Jujutsu** | ✅ Full | 🚧 Planned | Advanced change management |

## Quick Start

### 1. Automatic VCS Detection

Nim TestKit automatically detects your VCS environment:

```bash
# Navigate to your repository
cd /path/to/your/repo

# Check VCS detection
nimble mcp_status
```

Output example:
```
VCS Information:
Type: git
Remote: https://github.com/user/repo.git
Platform: github
Repository: user/repo
```

### 2. Setup Integration

```bash
# For MCP-based integration (recommended)
nimble mcp_setup

# For traditional integration
nimble install_hooks
```

## Traditional VCS Integration

### Git Integration

#### Hooks Installation
```bash
# Install pre-commit hooks
nimble install_hooks
```

This creates `.git/hooks/pre-commit` that runs tests before commits.

#### Basic Operations
```bash
# Generate tests for modified files
nimble generate

# Run tests
nimble tests

# Start continuous testing
nimble guard
```

### Jujutsu Integration

#### Advanced Features
```bash
# Setup Jujutsu-specific integration
nimble setup_jj_integration

# Split workflow support
jj split

# Evolve support with testing
jj evolve
```

#### Change-based Testing
- Automatic test selection based on changes
- Conflict detection and resolution testing
- Workspace-specific test configuration

## MCP-based Integration

### Setup

```bash
# Set authentication tokens
export GITHUB_TOKEN="your_github_token"
export GITLAB_PERSONAL_ACCESS_TOKEN="your_gitlab_token"

# Initialize MCP integration
nimble mcp_setup
```

### Unified Operations

#### Repository Management
```bash
# Check status across VCS types
nimble mcp_git status
nimble mcp_jujutsu status

# Commit changes
nimble mcp_git commit "Your commit message"
```

#### Issue Management
```bash
# Create issues across platforms
nimble mcp_github create-issue "Bug report" "Description"
nimble mcp_gitlab create-issue "Feature request" "Description"
```

#### Pull/Merge Requests
```bash
# Create pull requests
nimble mcp_github create-pr "Fix bug" "feature-branch" "main" "PR description"

# Create merge requests
nimble mcp_gitlab create-mr "Add feature" "feature-branch" "main" "MR description"
```

## Configuration

### VCS Detection Configuration

The system automatically detects VCS configuration, but you can customize detection:

```toml
# nimtestkit.toml
[vcs]
# Force specific VCS type
type = "git"  # or "jujutsu"

# Custom remote handling
remote_patterns = [
  "github.com",
  "gitlab.com",
  "your-enterprise.com"
]

# Hook configuration
[vcs.hooks]
pre_commit = true
pre_push = false
```

### Platform-specific Configuration

#### GitHub Configuration
```bash
# Standard GitHub
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"

# GitHub Enterprise
export GITHUB_API_URL="https://your-github.enterprise.com/api/v3"
export GITHUB_TOKEN="your_enterprise_token"
```

#### GitLab Configuration
```bash
# GitLab.com
export GITLAB_PERSONAL_ACCESS_TOKEN="glpat-xxxxxxxxxxxx"

# Self-hosted GitLab
export GITLAB_API_URL="https://your-gitlab.com/api/v4"
export GITLAB_PERSONAL_ACCESS_TOKEN="your_self_hosted_token"
```

## Advanced Features

### Smart Test Selection

#### Change-based Testing
```bash
# Run tests only for changed files
nimble tests --changed-only

# With Jujutsu integration
nimble tests --jj-changed
```

#### Platform Integration
```bash
# Test files related to PR changes
nimble mcp_github get-pr-files <pr-number> | xargs nimble tests

# Test files in specific GitLab MR
nimble mcp_gitlab get-mr-files <mr-id> | xargs nimble tests
```

### Workflow Integration

#### CI/CD Hooks
```bash
# Pre-commit testing
git add .
nimble tests --fast
git commit -m "Your message"

# Pre-push validation
git push origin feature-branch
# Automatically triggers: nimble tests --full
```

#### Continuous Integration
```yaml
# .github/workflows/test.yml
name: Test with VCS Integration
on: [push, pull_request]

jobs:
  test:
    steps:
      - uses: actions/checkout@v3
      - name: Setup Nim TestKit
        run: |
          nimble install -y
          nimble mcp_setup
      - name: Run VCS-aware tests
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          nimble tests --vcs-aware
          nimble mcp_github create-issue "CI Test" "Automated test result"
```

### Multi-Repository Support

#### Cross-repository Testing
```bash
# Test across multiple repositories
for repo in repo1 repo2 repo3; do
  cd $repo
  nimble tests
done

# With MCP integration
nimble mcp_github search-repositories "org:myorg topic:testing" | \
  xargs -I {} nimble mcp_github clone {} && nimble tests
```

## URL Parsing and Detection

### Supported URL Formats

#### HTTPS URLs
```bash
# GitHub
https://github.com/user/repo.git
https://github.com/user/repo

# GitLab
https://gitlab.com/user/repo.git
https://gitlab.example.com/group/subgroup/repo
```

#### SSH URLs
```bash
# GitHub
git@github.com:user/repo.git

# GitLab
git@gitlab.com:user/repo.git
git@gitlab.example.com:group/repo.git
```

#### Custom Processing
```nim
# Automatic URL parsing
let repoInfo = parseRepoInfo("git@github.com:user/repo.git")
echo repoInfo.platform  # "github"
echo repoInfo.owner     # "user"
echo repoInfo.repo      # "repo"
```

## Testing Strategies

### Repository-specific Testing

#### Mono-repository
```bash
# Test entire repository
nimble tests

# Test specific modules
nimble tests --module=auth,api,core

# Test with coverage
nimble coverage
```

#### Multi-repository
```bash
# Test dependencies first
nimble tests --deps-first

# Test in dependency order
nimble tests --topological
```

### Branch-specific Testing

#### Feature Branches
```bash
# Test only changes in branch
git checkout feature-branch
nimble tests --branch-changes

# Compare with main branch
nimble tests --compare-branch=main
```

#### Release Testing
```bash
# Full test suite for releases
nimble tests --full --coverage --docs

# Cross-platform testing
nimble tests --platforms=linux,macos,windows
```

## Troubleshooting

### Common Issues

#### VCS Detection Problems
```bash
# Debug VCS detection
nimble mcp_status --debug

# Force VCS type
export NIMTESTKIT_VCS_TYPE=git
nimble mcp_setup
```

#### Authentication Issues
```bash
# Test GitHub token
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Test GitLab token
curl -H "Authorization: Bearer $GITLAB_PERSONAL_ACCESS_TOKEN" https://gitlab.com/api/v4/user
```

#### Hook Problems
```bash
# Reinstall hooks
rm -f .git/hooks/pre-commit
nimble install_hooks

# Check hook permissions
ls -la .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

### Debug Mode

Enable verbose logging:

```bash
# Debug VCS operations
export VCS_DEBUG=1
nimble tests

# Debug MCP operations
export MCP_DEBUG=1
nimble mcp_git status
```

## Best Practices

### Repository Setup

1. **Initialize Early**: Set up VCS integration when starting projects
2. **Configure Authentication**: Set up tokens before first use
3. **Test Integration**: Verify setup with simple operations
4. **Document Process**: Document team-specific VCS workflows

### Team Collaboration

1. **Shared Configuration**: Use consistent token management
2. **Hook Standardization**: Ensure all team members use same hooks
3. **Branch Protection**: Use platform branch protection with testing
4. **Review Process**: Integrate testing into code review workflow

### Performance Optimization

1. **Selective Testing**: Use change-based test selection
2. **Parallel Operations**: Leverage async MCP operations
3. **Cache Management**: Use intelligent caching for repository data
4. **Resource Limits**: Configure appropriate timeout and limits

## Migration Guide

### From Git Hooks to MCP

```bash
# Old approach
git add .
git commit -m "Message"  # Runs pre-commit hook

# New MCP approach
nimble mcp_git add .
nimble mcp_git commit "Message"  # With MCP integration
```

### From Platform Tools to Unified Interface

```bash
# Old approach
gh issue create --title "Bug" --body "Description"
glab issue create --title "Bug" --description "Description"

# New unified approach
nimble mcp_github create-issue "Bug" "Description"
nimble mcp_gitlab create-issue "Bug" "Description"
```

---

*For platform-specific details, see the individual platform guides in the [MCP documentation](../mcp/).*