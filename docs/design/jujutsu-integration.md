# Jujutsu Integration Design

This document explains the integration of Nim TestKit with Jujutsu version control system.

## Architecture

Nim TestKit integrates with Jujutsu in two distinct ways:

1. **Test Integration**: Core testing features optimized for Jujutsu
2. **MCP Integration**: Optional semantic commit analysis via MCP-Jujutsu

### Module Structure

```
nim-testkit/
├── src/
│   ├── jujutsu_test_integration.nim # Test-specific Jujutsu features
│   └── mcp/
│       └── jujutsu.nim             # MCP-Jujutsu client interface
└── vendor/
    └── mcp-jujutsu/                # Optional MCP-Jujutsu implementation
```

## Test Integration (`jujutsu_test_integration.nim`)

The test integration provides several key features:

### Features

- **Repository Status**: Check repository state and modified files
- **Test Optimization**: Filter tests based on changed files
- **Test Caching**: Cache test results based on content hashes
- **Conflict Handling**: Generate tests for conflict resolution verification
- **Workspace Support**: Switch between workspaces for testing

### Key Types

- `JujutsuInfo`: Information about repository state
- `TestCache`: Cache of test results for efficient re-runs
- `TestHistory`: History of test results across changes

### Key Functions

- `checkJujutsuRepo()`: Check if current directory is a Jujutsu repository
- `getJujutsuInfo()`: Get information about repository state
- `getFilesInChange()`: Get changed files in a specific commit
- `filterTestsByChange()`: Filter tests to only run those affected by changes
- `setupJujutsuHooks()`: Set up automatic testing hooks for Jujutsu

## MCP Integration (`mcp/jujutsu.nim`)

The MCP integration provides semantic commit analysis through optional dependency on MCP-Jujutsu.

### Features

- **Semantic Analysis**: Analyze commit content for logical boundaries
- **Commit Division**: Divide large commits into semantic units
- **Release-Please Formatting**: Generate standardized commit messages

### Key Functions

- `newMcpClient()`: Create a client for accessing MCP-Jujutsu services
- `analyzeCommitRange()`: Analyze changes in a commit range
- `proposeCommitDivision()`: Generate a proposal for dividing a large commit
- `executeCommitDivision()`: Apply a commit division proposal
- `automateCommitDivision()`: Perform the entire divide process automatically

## Usage Examples

### Basic Test Integration

```nim
import nimtestkit/jujutsu_test_integration

# Get information about the repository
let jjInfo = getJujutsuInfo()

# Filter tests based on changes
let filteredTests = filterTestsByChange(allTests, jjInfo)

# Run only the relevant tests
runTests(filteredTests)
```

### MCP Integration

```nim
import nimtestkit/mcp/jujutsu
import asyncdispatch

# Check if MCP-Jujutsu is available
if isMcpJujutsuAvailable():
  # Create MCP client
  let client = newMcpClient()
  
  # Analyze commit range
  let analysis = waitFor client.analyzeCommitRange(".", "HEAD~1..HEAD")
  
  # Propose commit division
  let proposal = waitFor client.proposeCommitDivision(".", "HEAD~1..HEAD")
  
  # Execute the proposal
  waitFor client.executeCommitDivision(".", proposal)
```

## Compiling with MCP-Jujutsu Support

To enable MCP-Jujutsu integration:

1. Uncomment the dependency in `nimtestkit.nimble`:
   ```nim
   requires "mcp-jujutsu >= 0.1.0"
   ```

2. Compile with the `useMcpJujutsu` flag:
   ```bash
   nim c -d:useMcpJujutsu yourfile.nim
   ```

## Rationale

The split between test integration and MCP integration achieves several benefits:

1. **Modularity**: Clean separation of concerns
2. **Optionality**: MCP features can be enabled only when needed
3. **Dependencies**: Core functionality has minimal dependencies
4. **Clarity**: Each module has a clear and specific purpose