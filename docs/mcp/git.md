# Git Integration via MCP

This guide covers Git operations using the MCP (Model Context Protocol) integration in Nim TestKit.

## Overview

The Git MCP server provides local Git repository operations through a standardized protocol interface, enabling unified VCS management alongside platform-specific operations.

## Server Details

- **Location**: `vendor/servers/src/git`
- **Technology**: Python with GitPython library
- **Transport**: STDIO (JSON-RPC 2.0)
- **Dependencies**: Python 3.8+, GitPython

## Setup

### 1. Server Installation

```bash
# Navigate to Git server directory
cd vendor/servers/src/git

# Install with uv (recommended)
uv sync

# Or install with pip
pip install -e .
```

### 2. Verify Installation

```bash
# Test server functionality
cd /path/to/git/repository
nimble mcp_setup
nimble mcp_git status
```

## Available Operations

### Repository Status

#### `git_status`
Get the current status of the Git repository.

```bash
# Command
nimble mcp_git status

# Equivalent Git command
git status
```

**Example Output:**
```
On branch main
Your branch is up to date with 'origin/main'.

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git restore <file>..." to discard changes in working directory)
        modified:   src/example.nim

no changes added to commit (use "git add" or "git commit -a")
```

### Staging Operations

#### `git_add`
Add files to the staging area.

```bash
# Add specific files
nimble mcp_git add file1.nim file2.nim

# Add all changes
nimble mcp_git add .
```

**Parameters:**
- `repo_path`: Repository path (default: current directory)
- `files`: List of files to add

#### `git_reset`
Unstage all staged changes.

```bash
# Reset staging area
nimble mcp_git reset
```

### Commit Operations

#### `git_commit`
Create a new commit with staged changes.

```bash
# Create commit
nimble mcp_git commit "Add new feature implementation"
```

**Parameters:**
- `repo_path`: Repository path (default: current directory)
- `message`: Commit message (required)

**Example Output:**
```
Changes committed successfully with hash a1b2c3d4
```

### History and Inspection

#### `git_log`
View commit history.

```bash
# View recent commits (default: 10)
nimble mcp_git log

# View specific number of commits
nimble mcp_git log --count=5
```

**Parameters:**
- `repo_path`: Repository path (default: current directory)
- `max_count`: Number of commits to show (default: 10)

**Example Output:**
```
Commit: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0
Author: John Doe <john@example.com>
Date: 2025-05-22 10:30:00+00:00
Message: Add new feature implementation

Commit: b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0a1
Author: Jane Smith <jane@example.com>
Date: 2025-05-21 15:45:00+00:00
Message: Fix bug in authentication module
```

#### `git_show`
Show detailed information about a specific commit.

```bash
# Show specific commit
nimble mcp_git show a1b2c3d4
```

**Parameters:**
- `repo_path`: Repository path (default: current directory)
- `revision`: Commit hash, branch name, or tag

### Diff Operations

#### `git_diff_unstaged`
Show changes in working directory that are not staged.

```bash
# Show unstaged changes
nimble mcp_git diff-unstaged
```

#### `git_diff_staged`
Show changes that are staged for commit.

```bash
# Show staged changes
nimble mcp_git diff-staged
```

#### `git_diff`
Show differences between branches or commits.

```bash
# Compare with specific branch/commit
nimble mcp_git diff main
nimble mcp_git diff HEAD~1
```

### Branch Operations

#### `git_create_branch`
Create a new branch.

```bash
# Create branch from current HEAD
nimble mcp_git create-branch feature/new-api

# Create branch from specific base
nimble mcp_git create-branch feature/hotfix main
```

**Parameters:**
- `repo_path`: Repository path (default: current directory)
- `branch_name`: Name of new branch (required)
- `base_branch`: Base branch or commit (optional, defaults to current HEAD)

#### `git_checkout`
Switch to a different branch.

```bash
# Switch to existing branch
nimble mcp_git checkout feature/new-api

# Switch to main branch
nimble mcp_git checkout main
```

**Parameters:**
- `repo_path`: Repository path (default: current directory)
- `branch_name`: Branch to switch to (required)

### Repository Initialization

#### `git_init`
Initialize a new Git repository.

```bash
# Initialize in current directory
nimble mcp_git init

# Initialize in specific directory
nimble mcp_git init /path/to/new/repo
```

**Parameters:**
- `repo_path`: Path where to initialize repository (required)

## Integration with Nim TestKit

### Automated Testing Workflows

#### Pre-commit Testing
```bash
# Check status before committing
nimble mcp_git status

# Add test files
nimble mcp_git add tests/

# Run tests
nimble tests

# Commit if tests pass
nimble mcp_git commit "Add comprehensive test suite"
```

#### Branch-based Development
```bash
# Create feature branch
nimble mcp_git create-branch feature/new-test-generator

# Switch to feature branch
nimble mcp_git checkout feature/new-test-generator

# Develop and test
nimble generate
nimble tests

# Commit changes
nimble mcp_git add .
nimble mcp_git commit "Implement enhanced test generator"

# Switch back to main
nimble mcp_git checkout main
```

### Coverage Tracking

#### Commit Coverage Analysis
```bash
# Generate coverage before commit
nimble coverage

# Check what changed
nimble mcp_git diff-staged

# Commit with coverage info
nimble mcp_git commit "Add feature X (coverage: 95.2%)"
```

#### Historical Coverage Tracking
```bash
# View commits with coverage info
nimble mcp_git log | grep "coverage:"

# Compare coverage between commits
nimble mcp_git show HEAD~1 | grep "coverage:"
nimble mcp_git show HEAD | grep "coverage:"
```

## Error Handling

### Common Issues

#### Repository Not Found
```bash
# Error
Error: Not a git repository

# Solution
cd /path/to/git/repository
# or
nimble mcp_git init /path/to/new/repository
```

#### No Changes to Commit
```bash
# Error
nothing to commit, working tree clean

# Solution - check status first
nimble mcp_git status
# Add changes if needed
nimble mcp_git add .
```

#### Merge Conflicts
```bash
# Error during operations
Merge conflict detected

# Solution - resolve manually then
git add resolved_file.nim
nimble mcp_git commit "Resolve merge conflict"
```

### Debug Mode

Enable detailed logging:

```bash
# Set debug environment
export GIT_MCP_DEBUG=1

# Run operations with verbose output
nimble mcp_git status
```

## Configuration

### Repository-specific Configuration

```toml
# nimtestkit.toml
[mcp.git]
# Default repository path
repo_path = "."

# Auto-add generated files
auto_add_generated = true

# Default commit message prefix
commit_prefix = "[auto]"

# Pre-commit hooks
pre_commit_tests = true
```

### Global Git Configuration

The MCP server respects global Git configuration:

```bash
# Configure user information
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"

# Configure default branch
git config --global init.defaultBranch main

# Configure merge strategy
git config --global merge.tool vimdiff
```

## Performance Considerations

### Repository Size
- Large repositories may have slower operations
- Consider using sparse checkout for massive repos
- Git LFS is supported for large files

### Optimization Tips
```bash
# Use shallow clones for CI
git clone --depth 1 <repository>

# Clean up before operations
git gc --auto

# Use .gitignore effectively
echo "build/" >> .gitignore
echo "*.tmp" >> .gitignore
```

## Security

### Safe Operations
- All operations are read-only by default except explicit commits
- No automatic push operations
- Repository boundaries are respected

### Best Practices
```bash
# Always check status before operations
nimble mcp_git status

# Use descriptive commit messages
nimble mcp_git commit "Fix authentication bug in login module

- Resolve null pointer exception
- Add input validation
- Update related tests
Fixes #123"

# Review changes before committing
nimble mcp_git diff-staged
```

## Comparison with Traditional Git

| Operation | Traditional Git | MCP Git | Benefits |
|-----------|----------------|---------|----------|
| Status | `git status` | `nimble mcp_git status` | Unified interface |
| Commit | `git commit -m "msg"` | `nimble mcp_git commit "msg"` | Consistent syntax |
| History | `git log --oneline -10` | `nimble mcp_git log` | Structured output |
| Branching | `git checkout -b feature` | `nimble mcp_git create-branch feature` | Explicit operations |

## Advanced Usage

### Scripting with MCP Git

```bash
#!/bin/bash
# Automated development workflow

# Check for changes
if nimble mcp_git status | grep -q "modified:"; then
    echo "Changes detected, running tests..."
    
    # Run tests
    if nimble tests; then
        echo "Tests passed, committing..."
        nimble mcp_git add .
        nimble mcp_git commit "Auto-commit: $(date)"
    else
        echo "Tests failed, not committing"
        exit 1
    fi
else
    echo "No changes to commit"
fi
```

### Integration with Other MCP Servers

```bash
# Complete workflow: local -> GitHub
nimble mcp_git add .
nimble mcp_git commit "Implement new feature"
git push origin feature-branch
nimble mcp_github create-pr "New Feature" "feature-branch" "main" "Description"
```

---

*For more VCS integration options, see:*
- [GitHub Integration](github.md)
- [GitLab Integration](gitlab.md)
- [Jujutsu Integration](jujutsu.md)