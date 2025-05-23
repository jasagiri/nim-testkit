# MCP (Model Context Protocol) Integration

Nim TestKit provides comprehensive integration with the Model Context Protocol (MCP) for unified version control system operations across Git, GitHub, GitLab, and Jujutsu.

## Overview

The MCP integration enables seamless interaction with multiple VCS platforms through a standardized protocol interface, providing:

- **Unified Operations** - Single interface for multiple VCS platforms
- **Automatic Detection** - Smart detection of repository type and remote platforms  
- **Secure Authentication** - Environment variable-based token management
- **Async Processing** - Non-blocking MCP communication
- **Error Recovery** - Comprehensive error handling and recovery

## Quick Start

### 1. Environment Setup

```bash
# Set authentication tokens
export GITHUB_TOKEN="your_github_token"
export GITLAB_PERSONAL_ACCESS_TOKEN="your_gitlab_token"
```

### 2. Initialize MCP Integration

```bash
# Set up MCP servers and test connectivity
nimble mcp_setup

# Check server status
nimble mcp_status
```

### 3. Basic Operations

```bash
# Git operations
nimble mcp_git status
nimble mcp_git commit "Your commit message"

# GitHub operations
nimble mcp_github create-issue "Bug report" "Description"
nimble mcp_github create-pr "Fix bug" "feature-branch" "main" "PR description"

# GitLab operations  
nimble mcp_gitlab create-issue "Enhancement" "Description"
nimble mcp_gitlab create-mr "Add feature" "feature-branch" "main" "MR description"

# Jujutsu operations
nimble mcp_jujutsu status
```

## Documentation Index

### Core Concepts
- [Architecture](architecture.md) - MCP integration architecture and design
- [Setup](setup.md) - Detailed setup and configuration guide
- [VCS Operations](vcs-operations.md) - Overview of VCS operations via MCP

### Platform-Specific Guides
- [Git Integration](git.md) - Git operations via MCP server
- [GitHub Integration](github.md) - GitHub API operations via MCP
- [GitLab Integration](gitlab.md) - GitLab API operations via MCP
- [Jujutsu Integration](jujutsu.md) - Jujutsu operations via MCP

### Advanced Topics
- [Server Development](server-development.md) - Creating custom MCP servers
- [Troubleshooting](troubleshooting.md) - Common issues and solutions

## Supported MCP Servers

The integration leverages several MCP server implementations:

| Server | Location | Language | Purpose |
|--------|----------|----------|---------|
| **git** | `vendor/servers/src/git` | Python | Basic Git operations |
| **github** | `vendor/servers/src/github` | Node.js | GitHub API integration |
| **gitlab** | `vendor/servers/src/gitlab` | Node.js | GitLab API integration |
| **jujutsu** | `vendor/mcp-jujutsu` | Nim | Jujutsu VCS operations |

## Available Commands

### Management Commands
```bash
nimble mcp_setup        # Initialize MCP integration
nimble mcp_status       # Show server status and VCS info
nimble mcp_stop         # Stop all MCP servers
nimble mcp_list_tools   # List available tools
nimble mcp_help         # Show help information
```

### VCS Operations
```bash
nimble mcp_git          # Git operations
nimble mcp_github       # GitHub operations  
nimble mcp_gitlab       # GitLab operations
nimble mcp_jujutsu      # Jujutsu operations
```

## Prerequisites

### Runtime Dependencies
- **Python 3.8+** - For Git MCP server
- **Node.js 16+** - For GitHub/GitLab MCP servers
- **Nim 1.6.0+** - For Jujutsu MCP server (when available)

### Optional Dependencies
- **Git** - For Git operations
- **Jujutsu** - For jj operations
- **uv** - Python package manager (recommended)

### Authentication
- **GitHub Token** - Personal access token for GitHub operations
- **GitLab Token** - Personal access token for GitLab operations

## Examples

### Repository Analysis
```bash
# Get comprehensive repository information
nimble mcp_status
```

### Issue Management
```bash
# Create issues across platforms
nimble mcp_github create-issue "Bug: Login failed" "Steps to reproduce..."
nimble mcp_gitlab create-issue "Feature: Dark mode" "User story..."
```

### Pull/Merge Requests
```bash
# Create pull/merge requests
nimble mcp_github create-pr "Fix login bug" "bugfix/login" "main" "Fixes #123"
nimble mcp_gitlab create-mr "Add dark mode" "feature/dark-mode" "main" "Implements #456"
```

### Version Control Operations
```bash
# Basic VCS operations
nimble mcp_git status
nimble mcp_git commit "Update documentation"
nimble mcp_jujutsu status
```

## Configuration

MCP integration is configured through:

1. **Environment Variables** - Authentication tokens and API URLs
2. **Server Paths** - Automatic detection of MCP server locations
3. **Repository Detection** - Automatic VCS type and remote platform detection

See [Setup Guide](setup.md) for detailed configuration options.

## Benefits

### Unified Interface
- Single command-line interface for multiple VCS platforms
- Consistent operation patterns across different systems
- Simplified workflow integration

### Enhanced Functionality  
- Cross-platform repository operations
- Automated issue and PR/MR management
- Intelligent repository detection

### Developer Experience
- Reduced context switching between tools
- Streamlined CI/CD integration  
- Comprehensive error reporting

---

*For detailed guides on specific platforms, see the individual integration documents.*