# MCP Integration Setup Guide

This guide walks you through setting up MCP (Model Context Protocol) integration in Nim TestKit for unified VCS operations.

## Prerequisites

### System Requirements
- **Operating System**: Linux, macOS, or Windows
- **Nim**: Version 1.6.0 or higher
- **Python**: Version 3.8 or higher (for Git MCP server)
- **Node.js**: Version 16 or higher (for GitHub/GitLab MCP servers)

### Required Tools
- **Git** - For Git operations
- **nimble** - Nim package manager
- **uv** (recommended) - Python package manager for Git server

### Optional Tools
- **Jujutsu** - For jj operations (if using Jujutsu VCS)

## Installation

### 1. Install Nim TestKit

```bash
# Install from nimble
nimble install nimtestkit

# Or install from source
git clone https://github.com/your-org/nim-testkit.git
cd nim-testkit
nimble install
```

### 2. Verify MCP Server Dependencies

The MCP servers should be available in the `vendor/` directory:

```bash
# Check server availability
ls -la vendor/servers/src/
# Should show: git/ github/ gitlab/

ls -la vendor/
# Should show: mcp-jujutsu/ (when available)
```

### 3. Install Server Dependencies

#### Git MCP Server (Python)
```bash
# Navigate to git server directory
cd vendor/servers/src/git

# Install with uv (recommended)
uv sync

# Or install with pip
pip install -e .
```

#### GitHub MCP Server (Node.js)
```bash
# Navigate to github server directory
cd vendor/servers/src/github

# Install dependencies
npm install
```

#### GitLab MCP Server (Node.js)
```bash
# Navigate to gitlab server directory
cd vendor/servers/src/gitlab

# Install dependencies
npm install
```

## Authentication Setup

### GitHub Authentication

1. **Create Personal Access Token**
   - Go to GitHub Settings → Developer settings → Personal access tokens
   - Generate new token (classic) with required scopes:
     - `repo` - Full repository access
     - `issues` - Issue management
     - `pull_requests` - Pull request management

2. **Set Environment Variable**
   ```bash
   export GITHUB_TOKEN="your_github_token_here"
   
   # Add to shell profile for persistence
   echo 'export GITHUB_TOKEN="your_github_token_here"' >> ~/.bashrc
   source ~/.bashrc
   ```

### GitLab Authentication

1. **Create Personal Access Token**
   - Go to GitLab Settings → Access Tokens
   - Create token with required scopes:
     - `api` - Full API access
     - `read_repository` - Repository read access
     - `write_repository` - Repository write access

2. **Set Environment Variable**
   ```bash
   export GITLAB_PERSONAL_ACCESS_TOKEN="your_gitlab_token_here"
   
   # Add to shell profile for persistence
   echo 'export GITLAB_PERSONAL_ACCESS_TOKEN="your_gitlab_token_here"' >> ~/.bashrc
   source ~/.bashrc
   ```

### Custom API URLs (Optional)

For enterprise installations:

```bash
# GitHub Enterprise
export GITHUB_API_URL="https://your-github-enterprise.com/api/v3"

# GitLab Self-Hosted
export GITLAB_API_URL="https://your-gitlab.com/api/v4"
```

## Configuration

### 1. Initialize MCP Integration

```bash
# Navigate to your project directory
cd /path/to/your/project

# Initialize MCP integration
nimble mcp_setup
```

This command will:
- Detect your VCS type (Git, Jujutsu, etc.)
- Identify remote platform (GitHub, GitLab, etc.)
- Start appropriate MCP servers
- Test connectivity
- Display available tools

### 2. Verify Setup

```bash
# Check server status
nimble mcp_status
```

Expected output:
```
MCP Server Status:
==================
git: ✓ Running
github: ✓ Running  
gitlab: ✓ Running
jujutsu: ✗ Stopped

VCS Information:
Type: git
Remote: https://github.com/user/repo.git
Platform: github
Repository: user/repo
```

### 3. List Available Tools

```bash
# Show all available tools
nimble mcp_list_tools
```

Expected output:
```
Available Tools by Server:
==========================

git:
  - git_status
  - git_commit
  - git_add
  - git_reset
  - git_log
  - git_create_branch
  - git_checkout

github:
  - create_issue
  - create_pull_request
  - search_repositories
  - get_file_contents
  - push_files

gitlab:
  - create_issue
  - create_merge_request
  - search_repositories
  - get_file_contents
  - push_files
```

## Testing the Setup

### 1. Basic VCS Operations

```bash
# Test Git operations
nimble mcp_git status

# Test commit (make sure you have changes first)
echo "test" > test_file.txt
git add test_file.txt
nimble mcp_git commit "Test MCP integration"
```

### 2. Platform Operations

```bash
# Test GitHub (requires valid repository)
nimble mcp_github create-issue "Test Issue" "Testing MCP integration"

# Test GitLab (requires valid repository)  
nimble mcp_gitlab create-issue "Test Issue" "Testing MCP integration"
```

## Troubleshooting

### Common Issues

#### 1. Server Not Starting
```bash
# Check server paths
nimble mcp_status

# Manually verify server files
ls -la vendor/servers/src/git/
ls -la vendor/servers/src/github/index.js
ls -la vendor/servers/src/gitlab/index.js
```

#### 2. Authentication Errors
```bash
# Verify tokens are set
echo $GITHUB_TOKEN
echo $GITLAB_PERSONAL_ACCESS_TOKEN

# Test token validity
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user
curl -H "Authorization: Bearer $GITLAB_PERSONAL_ACCESS_TOKEN" https://gitlab.com/api/v4/user
```

#### 3. Permission Errors
```bash
# Ensure scripts are executable
chmod +x vendor/servers/src/*/
```

### Debug Mode

Enable debug output:

```bash
# Set debug environment variable
export MCP_DEBUG=1

# Run with verbose output
nimble mcp_setup --verbose
```

### Server Logs

Check individual server logs:

```bash
# Git server logs
tail -f /tmp/mcp-git-server.log

# GitHub server logs  
tail -f /tmp/mcp-github-server.log

# GitLab server logs
tail -f /tmp/mcp-gitlab-server.log
```

## Advanced Configuration

### Custom Server Paths

If servers are in non-standard locations:

```bash
# Set custom vendor path
export NIMTESTKIT_VENDOR_PATH="/custom/path/to/vendor"

# Reinitialize
nimble mcp_setup
```

### Server Timeout Configuration

Adjust server startup timeout:

```bash
# Set longer timeout (in seconds)
export MCP_SERVER_TIMEOUT=60

# Restart setup
nimble mcp_stop
nimble mcp_setup
```

### Selective Server Startup

Start only specific servers:

```bash
# Create custom configuration
# Edit ~/.nimtestkit/config.toml
[mcp.servers]
git.enabled = true
github.enabled = false
gitlab.enabled = true
jujutsu.enabled = false
```

## Integration with CI/CD

### GitHub Actions

```yaml
name: Test with MCP
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Nim
        uses: jiro4989/setup-nim-action@v1
        
      - name: Setup MCP
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          nimble install -y
          nimble mcp_setup
          
      - name: Run tests with MCP
        run: |
          nimble test
          nimble mcp_git status
```

### GitLab CI

```yaml
stages:
  - test

test_mcp:
  stage: test
  image: nimlang/nim:latest
  variables:
    GITLAB_PERSONAL_ACCESS_TOKEN: $GITLAB_TOKEN
  script:
    - nimble install -y
    - nimble mcp_setup
    - nimble test
    - nimble mcp_gitlab create-issue "CI Test" "Automated test"
```

## Next Steps

After successful setup:

1. **Explore Operations** - Try different MCP commands
2. **Read Platform Guides** - Check platform-specific documentation
3. **Integrate with Workflow** - Add MCP commands to your development workflow
4. **Customize** - Adapt configuration to your team's needs

---

*For platform-specific guides, see:*
- [Git Integration](git.md)
- [GitHub Integration](github.md)  
- [GitLab Integration](gitlab.md)
- [Jujutsu Integration](jujutsu.md)