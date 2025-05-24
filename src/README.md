# nim-testkit src/ Directory Structure

This directory follows MECE (Mutually Exclusive, Collectively Exhaustive) principles for clear organization.

## Directory Structure

```
src/
├── cli/                    # Command-line interfaces
│   ├── ntk.nim            # Main CLI entry point
│   ├── setup.nim          # Setup command (was nimtestkit_setup)
│   └── init.nim           # Init command (was nimtestkit_init)
├── core/                   # Core functionality
│   ├── types.nim          # Core type definitions
│   ├── results.nim        # Result handling
│   └── runner.nim         # Base runner implementation
├── generation/             # Test generation
│   ├── generator.nim      # Main generator (was test_generator)
│   ├── nimtestkit_generator.nim  # Standalone generator tool
│   ├── unit_gen.nim       # Unit test generation
│   ├── integration_gen.nim # Integration test generation
│   └── system_gen.nim     # System test generation
├── execution/              # Test execution
│   ├── runner.nim         # Main test runner (was test_runner)
│   ├── nimtestkit_runner.nim # Standalone runner tool
│   ├── category_runner.nim # Category-based runner
│   └── guard.nim          # File watcher (was test_guard)
├── analysis/               # Code analysis tools
│   ├── mece_detector.nim  # MECE structure analyzer
│   ├── mece_organizer.nim # MECE test organizer
│   ├── coverage.nim       # Coverage helper (was coverage_helper)
│   └── dependency.nim     # Dependency analyzer
├── organization/           # Project organization
│   ├── standard_layout.nim     # Standard project layout
│   ├── minimal_layout.nim      # Minimal layout (was standard_layout_minimal)
│   ├── module_sync.nim         # Module synchronization
│   ├── ntk_module_sync.nim     # NTK-specific module sync
│   └── migration_planner.nim   # Migration planning
├── integrations/           # External integrations
│   ├── vcs/               # Version control
│   │   ├── common.nim     # VCS interface (was vcs_integration)
│   │   ├── commands.nim   # VCS commands (was vcs_commands)
│   │   ├── jujutsu.nim    # Jujutsu support
│   │   └── jujutsu_integration.nim # Jujutsu test integration
│   ├── mcp/               # MCP protocol
│   │   ├── mcp_client.nim      # MCP client
│   │   ├── mcp_manager.nim     # MCP manager
│   │   ├── mcp_types.nim       # MCP types
│   │   ├── commands.nim        # MCP commands (was mcp_commands)
│   │   └── jujutsu_integration.nim # MCP-Jujutsu integration
│   └── lang/              # Language integrations
│       ├── lang_core_integration.nim # Core language features
│       ├── aspects_integration.nim   # Aspect-oriented features
│       ├── design_patterns_integration.nim # Design patterns
│       └── optional_dependencies.nim # Optional dependencies
├── refactoring/            # Refactoring tools
│   ├── helper.nim         # Refactoring helper (was refactor_helper)
│   └── ntk_refactor.nim   # NTK refactoring tool
├── documentation/          # Documentation generation
│   └── generator.nim      # Doc generator (was doc_generator)
├── config/                 # Configuration
│   ├── config.nim         # Main config module
│   └── parser.nim         # Config parser
├── utils/                  # Utilities
│   ├── env_detector.nim   # Environment detection
│   └── platform.nim       # Platform support (was platform_support)
├── advanced/               # Advanced testing features
│   └── testing.nim        # Advanced testing (was advanced_testing)
├── nimtestkit.nim         # Main library entry point
└── panicoverride.nim      # Panic override support
```

## Key Changes Made

1. **Eliminated Duplication**: Consolidated 4 different runners into `execution/` directory
2. **Clear Categories**: Each directory has a single, clear purpose
3. **Consistent Naming**: Removed prefixes like `test_` from filenames when moved to appropriate directories
4. **Logical Grouping**: Related functionality is grouped together (e.g., all VCS code in `integrations/vcs/`)
5. **Flat Where Possible**: Avoided deep nesting while maintaining clarity

## Import Updates

All imports have been updated to reflect the new structure. For example:
- `import test_runner` → `import execution/runner`
- `import coverage_helper` → `import analysis/coverage`
- `import vcs_integration` → `import integrations/vcs/common`