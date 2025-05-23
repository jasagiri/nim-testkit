# MCP Integration Design

This document outlines the design and architecture of the Model Context Protocol (MCP) integration in Nim TestKit.

## Overview

The MCP integration provides a unified interface for version control operations across multiple platforms (Git, GitHub, GitLab, Jujutsu) through a standardized protocol.

## Design Principles

### 1. Non-Invasive Integration
- MCP functionality is additive, not replacing existing VCS features
- Traditional VCS commands continue to work unchanged
- MCP integration is opt-in and configurable

### 2. Unified Interface
- Single command set for all supported VCS platforms
- Consistent error handling and response formats
- Platform-agnostic operation definitions

### 3. Async-First Architecture
- All MCP operations are asynchronous by default
- Non-blocking communication with MCP servers
- Parallel operation support where applicable

### 4. Extensible Server Support
- Plugin-like architecture for adding new MCP servers
- Server-specific configuration and authentication
- Runtime server discovery and capability detection

## Architecture Components

### Core Types (`src/mcp/mcp_types.nim`)

```nim
type
  McpMessage* = object
    jsonrpc*: string
    id*: Option[JsonNode]
    method*: Option[string]
    params*: Option[JsonNode]
    result*: Option[JsonNode]
    error*: Option[McpError]
```

Defines the fundamental MCP protocol types following JSON-RPC 2.0 specification.

### Client Layer (`src/mcp/mcp_client.nim`)

Individual MCP client implementations handle:
- Server process lifecycle management
- STDIO transport communication
- Message serialization/deserialization
- Tool invocation and result handling

### Manager Layer (`src/mcp/mcp_manager.nim`)

The manager orchestrates multiple MCP servers:
- Server selection based on operation type
- Load balancing and failover
- Unified result aggregation
- Cross-server operation coordination

### Command Interface (`src/mcp_commands.nim`)

User-facing command implementations:
- Command parsing and validation
- Authentication handling
- Output formatting and display
- Error reporting and diagnostics

## Server Integration

### Git Server (Python)
- **Location**: `vendor/_Agentic/git-mcp-server/`
- **Protocol**: File operations, commit history, branch management
- **Authentication**: Local git configuration
- **Tools**: `read_file`, `write_file`, `git_log`, `git_diff`, `git_commit`

### GitHub Server (Node.js)
- **Location**: `vendor/_Agentic/github-mcp-server/`
- **Protocol**: Repository management, issues, pull requests
- **Authentication**: GitHub token (`GITHUB_TOKEN`)
- **Tools**: `create_repository`, `create_issue`, `create_pull_request`, `get_file`

### GitLab Server (Node.js)
- **Location**: `vendor/_Agentic/gitlab-mcp-server/`
- **Protocol**: Project management, merge requests, CI/CD
- **Authentication**: Personal access token (`GITLAB_PERSONAL_ACCESS_TOKEN`)
- **Tools**: `create_project`, `create_issue`, `create_merge_request`, `get_file`

### Jujutsu Server (Nim)
- **Location**: `src/mcp/jujutsu.nim`
- **Protocol**: Change-based operations, conflict resolution
- **Authentication**: Local jj configuration
- **Tools**: `jj_status`, `jj_commit`, `jj_rebase`, `jj_resolve`

## Communication Flow

```
User Command
     ↓
Command Parser
     ↓
MCP Manager
     ↓
Server Selection
     ↓
MCP Client
     ↓
Server Process (STDIO)
     ↓
Tool Execution
     ↓
Result Aggregation
     ↓
User Output
```

## Protocol Compliance

### JSON-RPC 2.0
- All messages follow JSON-RPC 2.0 specification
- Proper error handling with standardized error codes
- Request/response correlation via message IDs

### MCP Specification
- Tool discovery through `tools/list` method
- Resource enumeration via `resources/list`
- Capability negotiation during initialization

## Security Considerations

### Authentication
- Token-based authentication for cloud services
- Local credential management for git operations
- Environment variable isolation for sensitive data

### Process Isolation
- MCP servers run in separate processes
- STDIO-only communication (no network exposure)
- Sandboxed execution environment

### Data Protection
- No credential storage in configuration files
- Secure token passing through environment variables
- Local-only operation for sensitive repositories

## Performance Optimizations

### Connection Pooling
- Persistent server processes for repeated operations
- Connection reuse across command invocations
- Graceful server lifecycle management

### Async Operations
- Non-blocking I/O for all server communication
- Parallel execution of independent operations
- Efficient resource utilization

### Caching
- Server capability caching
- Authentication token reuse
- Operation result memoization where appropriate

## Error Handling

### Server Failures
- Automatic server restart on process termination
- Graceful fallback to alternative servers
- Comprehensive error logging and diagnostics

### Protocol Errors
- JSON-RPC error code mapping
- User-friendly error message translation
- Detailed debug information in verbose mode

### Network Issues
- Retry logic for transient failures
- Timeout handling for long-running operations
- Offline mode support where applicable

## Future Enhancements

### Planned Features
- WebSocket transport support for real-time operations
- Plugin marketplace for community MCP servers
- Advanced caching and synchronization mechanisms
- Multi-repository operation support

### Extension Points
- Custom MCP server registration
- User-defined tool implementations
- Configurable operation pipelines
- Integration with external CI/CD systems

## Testing Strategy

### Unit Testing
- Individual component testing with mocked dependencies
- Protocol compliance verification
- Error condition simulation

### Integration Testing
- End-to-end workflow testing with real servers
- Cross-platform compatibility verification
- Performance benchmarking and optimization

### Compatibility Testing
- Multiple server version support
- Protocol version negotiation
- Backward compatibility maintenance