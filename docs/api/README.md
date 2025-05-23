# API Documentation

This directory contains the complete API documentation for Nim TestKit components.

## Core Components

### Configuration System
- **[config](config.html)** - TOML-based configuration management

### Test Management
- **[test_generator](test_generator.html)** - Automated test skeleton generation
- **[test_runner](test_runner.html)** - Test execution and reporting
- **[test_guard](test_guard.html)** - Continuous testing and file monitoring

### Coverage Analysis
- **[coverage_helper](coverage_helper.html)** - Code coverage reporting and analysis

### VCS Integration
- **[jujutsu](jujutsu.html)** - Jujutsu version control integration
- **[jujutsu_test_integration](jujutsu_test_integration.html)** - Jujutsu-specific testing features

### MCP Integration
- **[mcp_types](mcp_types.html)** - MCP protocol type definitions
- **[mcp_client](mcp_client.html)** - MCP client implementation
- **[mcp_manager](mcp_manager.html)** - Multi-server MCP orchestration

### Documentation Generation
- **[doc_generator](doc_generator.html)** - API documentation and badge generation

### Utilities
- **[nimtestkit_generator](nimtestkit_generator.html)** - Project initialization
- **[nimtestkit_runner](nimtestkit_runner.html)** - Main runner orchestration
- **[nimtestkit_setup](nimtestkit_setup.html)** - Setup and configuration helpers

## API Index

For a complete index of all modules and functions, see the [index page](theindex.html).

## Navigation

- [Main Documentation](../README.md)
- [Setup Guide](../guides/setup-guide.md)
- [Configuration Guide](../guides/configuration.md)
- [MCP Integration](../mcp/README.md)

## Generation

API documentation is automatically generated from source code using Nim's built-in documentation generator:

```bash
nimble docs
```

The generated HTML files include:
- Function signatures and descriptions
- Type definitions and examples
- Cross-references between modules
- Source code links