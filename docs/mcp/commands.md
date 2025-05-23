# MCP Commands Reference

Complete reference for all Model Context Protocol (MCP) commands available in Nim TestKit.

## Command Structure

All MCP commands follow the pattern:
```bash
nimble mcp_<platform> <operation> [arguments...]
```

## Global Options

### Authentication
- `--token <token>` - Override authentication token
- `--auth-file <path>` - Load authentication from file

### Output
- `--format <format>` - Output format: `json`, `yaml`, `table` (default: `table`)
- `--verbose` - Enable verbose output with debug information
- `--quiet` - Suppress non-essential output

### Server Management
- `--server-timeout <seconds>` - Server response timeout (default: 30)
- `--no-cache` - Disable server capability caching

## Git Commands (`nimble mcp_git`)

### File Operations
```bash
# Read file contents
nimble mcp_git read <file_path>

# Write file contents
nimble mcp_git write <file_path> <content>

# List files in directory
nimble mcp_git list [directory]
```

### Repository Information
```bash
# Show repository status
nimble mcp_git status

# Show commit history
nimble mcp_git log [--limit 10] [--since "2024-01-01"]

# Show file differences
nimble mcp_git diff [file_path] [--staged]

# Show branch information
nimble mcp_git branches [--remote] [--all]
```

### Commit Operations
```bash
# Create commit
nimble mcp_git commit <message> [--author "Name <email>"]

# Add files to staging
nimble mcp_git add <file_pattern>

# Create and switch to branch
nimble mcp_git checkout <branch_name> [--create]

# Merge branches
nimble mcp_git merge <source_branch> [--no-ff]
```

### Remote Operations
```bash
# Push changes
nimble mcp_git push [remote] [branch]

# Pull changes
nimble mcp_git pull [remote] [branch]

# Fetch remote updates
nimble mcp_git fetch [remote]

# Clone repository
nimble mcp_git clone <url> [directory]
```

## GitHub Commands (`nimble mcp_github`)

### Repository Management
```bash
# Create repository
nimble mcp_github create-repo <name> [--private] [--description "Description"]

# Get repository information
nimble mcp_github get-repo <owner/repo>

# List user repositories
nimble mcp_github list-repos [--user username] [--org organization]

# Fork repository
nimble mcp_github fork <owner/repo> [--organization target_org]
```

### File Operations
```bash
# Get file contents
nimble mcp_github get-file <owner/repo> <path> [--ref branch_or_commit]

# Create or update file
nimble mcp_github create-file <owner/repo> <path> <content> <message> [--branch branch]

# Delete file
nimble mcp_github delete-file <owner/repo> <path> <message> [--branch branch]
```

### Issues and Discussions
```bash
# Create issue
nimble mcp_github create-issue <owner/repo> <title> <body> [--labels label1,label2]

# List issues
nimble mcp_github list-issues <owner/repo> [--state open|closed|all] [--labels label1,label2]

# Update issue
nimble mcp_github update-issue <owner/repo> <issue_number> [--title "New Title"] [--body "New Body"]

# Close issue
nimble mcp_github close-issue <owner/repo> <issue_number>
```

### Pull Requests
```bash
# Create pull request
nimble mcp_github create-pr <owner/repo> <title> <body> <head_branch> [--base main]

# List pull requests
nimble mcp_github list-prs <owner/repo> [--state open|closed|all]

# Merge pull request
nimble mcp_github merge-pr <owner/repo> <pr_number> [--merge-method merge|squash|rebase]

# Review pull request
nimble mcp_github review-pr <owner/repo> <pr_number> <event> [--body "Review comment"]
```

### Workflow and Actions
```bash
# List workflow runs
nimble mcp_github list-runs <owner/repo> [--workflow workflow_id]

# Get workflow run
nimble mcp_github get-run <owner/repo> <run_id>

# Trigger workflow
nimble mcp_github trigger-workflow <owner/repo> <workflow_id> [--ref branch]
```

## GitLab Commands (`nimble mcp_gitlab`)

### Project Management
```bash
# Create project
nimble mcp_gitlab create-project <name> [--namespace group] [--private] [--description "Description"]

# Get project information
nimble mcp_gitlab get-project <project_id>

# List user projects
nimble mcp_gitlab list-projects [--owned] [--membership]

# Fork project
nimble mcp_gitlab fork-project <project_id> [--namespace target_namespace]
```

### File Operations
```bash
# Get file contents
nimble mcp_gitlab get-file <project_id> <path> [--ref branch_or_commit]

# Create file
nimble mcp_gitlab create-file <project_id> <path> <content> <message> [--branch branch]

# Update file
nimble mcp_gitlab update-file <project_id> <path> <content> <message> [--branch branch]

# Delete file
nimble mcp_gitlab delete-file <project_id> <path> <message> [--branch branch]
```

### Issues and Milestones
```bash
# Create issue
nimble mcp_gitlab create-issue <project_id> <title> [--description "Description"] [--labels label1,label2]

# List issues
nimble mcp_gitlab list-issues <project_id> [--state opened|closed|all]

# Update issue
nimble mcp_gitlab update-issue <project_id> <issue_iid> [--title "New Title"] [--description "New Description"]

# Close issue
nimble mcp_gitlab close-issue <project_id> <issue_iid>
```

### Merge Requests
```bash
# Create merge request
nimble mcp_gitlab create-mr <project_id> <title> <source_branch> [--target-branch main] [--description "Description"]

# List merge requests
nimble mcp_gitlab list-mrs <project_id> [--state opened|closed|merged]

# Merge merge request
nimble mcp_gitlab merge-mr <project_id> <mr_iid> [--merge-method merge|rebase_merge|ff]

# Approve merge request
nimble mcp_gitlab approve-mr <project_id> <mr_iid>
```

### CI/CD Operations
```bash
# List pipelines
nimble mcp_gitlab list-pipelines <project_id> [--ref branch] [--status running|success|failed]

# Get pipeline
nimble mcp_gitlab get-pipeline <project_id> <pipeline_id>

# Trigger pipeline
nimble mcp_gitlab trigger-pipeline <project_id> <ref> [--variables key1=value1,key2=value2]

# Cancel pipeline
nimble mcp_gitlab cancel-pipeline <project_id> <pipeline_id>
```

## Jujutsu Commands (`nimble mcp_jujutsu`)

### Change Management
```bash
# Show repository status
nimble mcp_jujutsu status

# Create new change
nimble mcp_jujutsu new [--message "Description"]

# Commit current changes
nimble mcp_jujutsu commit [--message "Commit message"]

# Describe change
nimble mcp_jujutsu describe <change_id> <description>
```

### History Operations
```bash
# Show change log
nimble mcp_jujutsu log [--limit 10] [--template template]

# Show changes in commit
nimble mcp_jujutsu show <change_id>

# Compare changes
nimble mcp_jujutsu diff [change_id] [--from from_id] [--to to_id]

# Visualize change graph
nimble mcp_jujutsu graph [--limit 20]
```

### Branch Operations
```bash
# Create branch
nimble mcp_jujutsu branch create <name> [--change change_id]

# List branches
nimble mcp_jujutsu branch list [--all]

# Delete branch
nimble mcp_jujutsu branch delete <name>

# Rename branch
nimble mcp_jujutsu branch rename <old_name> <new_name>
```

### Conflict Resolution
```bash
# Rebase changes
nimble mcp_jujutsu rebase [--destination dest_id] [--source source_id]

# Resolve conflicts
nimble mcp_jujutsu resolve [--list] [--tool tool_name]

# Squash changes
nimble mcp_jujutsu squash [--into target_id] [--from source_id]

# Split change
nimble mcp_jujutsu split <change_id>
```

### Remote Operations
```bash
# Fetch from remote
nimble mcp_jujutsu fetch [remote] [--branch branch]

# Push to remote
nimble mcp_jujutsu push [remote] [--branch branch] [--change change_id]

# Pull changes
nimble mcp_jujutsu pull [remote] [--branch branch]

# Clone repository
nimble mcp_jujutsu clone <url> [directory]
```

## Setup Commands (`nimble mcp_setup`)

### Initialization
```bash
# Setup MCP integration
nimble mcp_setup

# Initialize specific server
nimble mcp_setup --server git|github|gitlab|jujutsu

# Verify server installation
nimble mcp_setup --verify [server_name]

# Reset server configuration
nimble mcp_setup --reset [server_name]
```

### Configuration
```bash
# Set authentication token
nimble mcp_setup --set-token <platform> <token>

# Configure server settings
nimble mcp_setup --configure <platform>

# Export configuration
nimble mcp_setup --export [file_path]

# Import configuration
nimble mcp_setup --import <file_path>
```

## Error Handling

### Common Exit Codes
- `0` - Success
- `1` - General error
- `2` - Authentication failure
- `3` - Server connection error
- `4` - Invalid arguments
- `5` - Permission denied
- `6` - Resource not found

### Debug Information
Use `--verbose` flag to get detailed error information:
```bash
nimble mcp_github create-issue owner/repo "Title" "Body" --verbose
```

### Server Logs
Check server logs for debugging:
```bash
# View recent MCP server logs
nimble mcp_setup --logs [server_name]

# Follow server logs in real-time
nimble mcp_setup --logs [server_name] --follow
```

## Environment Variables

### GitHub Authentication
```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"
```

### GitLab Authentication
```bash
export GITLAB_PERSONAL_ACCESS_TOKEN="glpat-xxxxxxxxxxxxxxxxxxxx"
export GITLAB_URL="https://gitlab.example.com"  # For self-hosted instances
```

### General Configuration
```bash
export MCP_DEBUG=true                    # Enable debug mode
export MCP_TIMEOUT=60                    # Server timeout in seconds
export MCP_CONFIG_DIR="~/.mcp"          # Custom config directory
```