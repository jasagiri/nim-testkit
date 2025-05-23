# Nim TestKit Documentation

Welcome to the Nim TestKit documentation. This comprehensive documentation will help you understand and use the test automation toolkit with MCP protocol integration for your Nim projects.

## Documentation Structure

- **[guides/](guides/)** - User guides and tutorials
- **[design/](design/)** - Architecture and design documentation
- **[api/](api/)** - API documentation and code reference
- **[mcp/](mcp/)** - MCP (Model Context Protocol) integration documentation

## Contents

### Getting Started
- [Setup Guide](guides/setup-guide.md) - How to set up Nim TestKit in your project
- [Quick Start](../README.md#quick-start-example) - Quick start example
- [MCP Integration Setup](mcp/setup.md) - Set up MCP protocol integration

### Core Concepts
- [Non-Invasive Design](design/non-invasive-design.md) - Understanding the non-invasive package design
- [Build Structure](design/build-structure.md) - Build and distribution architecture
- [Jujutsu Integration](design/jujutsu-integration.md) - Jujutsu VCS integration architecture
- [MCP Architecture](mcp/architecture.md) - MCP protocol integration design
- [Configuration Reference](guides/configuration.md) - Complete configuration options

### Core Tools
- [Test Generator](api/test_generator.html) - Automatically generate test skeletons
- [Test Runner](api/test_runner.html) - Run tests and report results
- [Test Guard](api/test_guard.html) - Monitor for changes and run tests automatically
- [Coverage Helper](api/coverage_helper.html) - Generate and analyze code coverage reports
- [Documentation Generator](api/doc_generator.html) - Generate project documentation

### VCS Integration
- [VCS Commands](guides/vcs-integration.md) - Version control system integration
- [MCP VCS Operations](mcp/vcs-operations.md) - MCP-based VCS operations
- [Git Integration](mcp/git.md) - Git operations via MCP
- [GitHub Integration](mcp/github.md) - GitHub operations via MCP
- [GitLab Integration](mcp/gitlab.md) - GitLab operations via MCP
- [Jujutsu Integration](mcp/jujutsu.md) - Jujutsu operations via MCP

### Scripts
- [Generate Scripts](guides/scripts.md#generate) - Scripts for test generation
- [Run Scripts](guides/scripts.md#run) - Scripts for executing tests
- [Guard Scripts](guides/scripts.md#guard) - Scripts for continuous testing
- [Coverage Scripts](guides/scripts.md#coverage) - Scripts for coverage analysis
- [Hook Scripts](guides/scripts.md#hooks) - Git hooks for test enforcement
- [MCP Scripts](guides/scripts.md#mcp) - MCP operation scripts

### Advanced Topics
- [Custom Templates](guides/templates.md) - Creating custom test templates
- [CI/CD Integration](guides/ci-cd.md) - Integrating with continuous integration systems
- [MCP Server Development](mcp/server-development.md) - Developing custom MCP servers
- [Multi-Platform Support](guides/multi-platform.md) - Cross-platform considerations

### Troubleshooting
- [Common Issues](guides/troubleshooting.md) - Solutions to common problems
- [MCP Troubleshooting](mcp/troubleshooting.md) - MCP-specific issue resolution
- [Performance Tuning](guides/performance.md) - Optimizing test performance

## Features

### ✨ Key Features
- **Automated Test Generation** - Generate test skeletons for functions without tests
- **Cross-Platform Testing** - Specialized tests for all supported platforms
- **Continuous Testing** - Monitor code changes and automatically run tests
- **Code Coverage Analysis** - Track and report on test coverage
- **VCS Integration** - Unified interface for Git, GitHub, GitLab, and Jujutsu
- **MCP Protocol Support** - Modern protocol-based VCS operations
- **Documentation Generation** - Automated project documentation

### 🚀 New Features (v0.2.0)
- **MCP (Model Context Protocol) Integration** - Unified VCS operations
- **Advanced Test Generation** - Property-based and async test templates
- **Enhanced Test Runner** - JUnit XML, TAP format, parallel execution
- **Comprehensive Coverage** - HTML reports with detailed metrics
- **Smart Documentation** - Markdown docs with coverage integration

## Project Status

For the current development status, see the [TODO.md](../TODO.md) file.

## Contributing

Contributions are welcome! Please read the contributing guidelines to get started.

## License

Nim TestKit is licensed under the MIT License.

---

*Documentation last updated: 2025-05-22*