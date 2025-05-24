# Nim TestKit Standard Project Layout

Nim TestKit provides a standardized project structure that minimizes configuration needs while maximizing consistency across projects. This approach is inspired by Cargo's conventions.

## Quick Start

```bash
# Initialize a new project
nimtestkit_init myproject

# Or initialize current directory
nimtestkit_init

# Specific project types
nimtestkit_init -t library mylib
nimtestkit_init -t application myapp
```

## Standard Directory Structure

```
myproject/
├── src/                # Source code (auto-detected)
├── tests/              # Test files (auto-detected)
├── build/              # All build artifacts (git-ignored)
│   ├── debug/          # Debug builds
│   ├── release/        # Release builds
│   ├── cache/          # Compilation cache
│   ├── coverage/       # Coverage data and reports
│   │   ├── raw/        # Raw coverage data (.cov files)
│   │   ├── reports/    # Generated reports (HTML, JSON, XML, LCOV)
│   │   └── temp/       # Temporary/intermediate files
│   ├── test-results/   # Test execution results
│   └── artifacts/      # Other build artifacts
├── docs/               # Documentation
├── examples/           # Example code
├── benchmarks/         # Performance benchmarks
├── nimtestkit.toml     # Minimal configuration (optional)
├── .gitignore          # Auto-generated
└── README.md           # Auto-generated template
```

## Build Directory Management

All build artifacts are centralized in the `build/` directory, similar to Cargo's `target/` directory:

- **Isolation**: Keeps source tree clean
- **Gitignore**: Automatically excluded from version control
- **Easy cleanup**: Single directory to delete
- **Organization**: Artifacts organized by type and build mode

### Build Artifact Paths

```nim
# Test results with timestamps
build/test-results/test_results_20240124_143022.xml
build/test-results/test_results_20240124_143022.tap

# Coverage structure
build/coverage/
├── raw/                    # Raw coverage data
│   ├── test_lib.cov       # Per-test coverage data
│   └── test_app.cov
├── reports/               # Generated reports
│   ├── index.html        # Main HTML report
│   ├── coverage_20240124_143022.json
│   ├── coverage_20240124_143022.lcov
│   └── coverage_20240124_143022.xml
└── temp/                  # Temporary files (auto-cleaned)

# Binary outputs
build/debug/myapp
build/release/myapp

# Test summary
build/test-summary.txt
```

### Coverage Management

All coverage-related files are organized under `build/coverage/`:

1. **Raw Data** (`build/coverage/raw/`):
   - Contains `.cov` files for each test
   - Preserved between runs for incremental analysis
   - Named after test files for easy correlation

2. **Reports** (`build/coverage/reports/`):
   - HTML reports for browser viewing
   - JSON for programmatic access
   - LCOV format for CI integration
   - XML for tool compatibility

3. **Temporary Files** (`build/coverage/temp/`):
   - Intermediate processing files
   - Automatically cleaned after report generation
   - Not tracked in version control

Example coverage workflow:
```bash
# Run tests with coverage
nimtestkit coverage

# View HTML report
open build/coverage/reports/index.html

# Access raw data for CI
cat build/coverage/reports/coverage_*.json

# Clean temporary files only
rm -rf build/coverage/temp/

# Full clean
rm -rf build/
```

## Minimal Configuration

With standard layout, most projects need minimal or no configuration:

### No Configuration Needed

If your project follows the standard layout, nim-testkit works with zero configuration:

```bash
# Just works - no config file needed!
nimtestkit_runner
nimtestkit_generator
```

### Minimal Configuration (nimtestkit.toml)

```toml
# Only specify what differs from conventions
[build]
output_dir = "build"  # Default

[tests]
parallel = true       # Default for standard layout
```

### Configuration Presets

Use presets for common scenarios:

```bash
# Minimal preset - for simple projects
nimtestkit_init --preset minimal

# Strict preset - for production projects
nimtestkit_init --preset strict

# Standard preset - balanced defaults (default)
nimtestkit_init --preset standard
```

## Auto-Detection Features

Nim TestKit automatically detects:

1. **Source Directory**: Checks for `src/`, `source/`, `lib/`, or uses root
2. **Test Directory**: Checks for `tests/`, `test/`, `spec/`
3. **Project Type**: Library, application, or hybrid based on files
4. **Configuration File**: Looks for multiple naming conventions
5. **Project Info**: Reads from `.nimble` file if present

## Project Types

### Library Project
- Has `src/lib.nim` or similar
- Tests import from `../src/`
- Example files in `examples/`

### Application Project
- Has `src/main.nim` or `src/app.nim`
- Integration tests
- Binary output to `build/`

### Hybrid Project
- Both library and application components
- Separate test suites
- Multiple build artifacts

## Convention Benefits

1. **Zero Configuration**: Most projects work without any config file
2. **Consistency**: Same structure across all projects
3. **Tool Integration**: Tools know where to find things
4. **Clean Separation**: Source, tests, and build artifacts separated
5. **Easy Onboarding**: New developers know the structure

## Advanced Usage

### Custom Build Paths

```nim
import nimtestkit/standard_layout

let paths = getStandardPaths()
let artifact = getBuildArtifactPath(paths, "mylib.so", release = true)
# Returns: /path/to/project/build/release/mylib.so
```

### Project Detection

```nim
let info = detectProjectInfo()
echo info.name        # From nimble file or directory
echo info.layout      # plLibrary, plApplication, etc.
echo info.paths       # All standard paths
```

### Programmatic Initialization

```nim
import nimtestkit/standard_layout

# Initialize with specific layout
initStandardProject("/path/to/project", plLibrary)
```

## Migration from Custom Layout

1. **Move source files** to `src/`
2. **Move test files** to `tests/`
3. **Delete or minimize** configuration file
4. **Add build/** to `.gitignore`
5. **Run** `nimtestkit_init --force` to update

## Comparison with Other Build Systems

| Feature | Nim TestKit | Cargo | npm | Maven |
|---------|------------|-------|-----|-------|
| Build directory | `build/` | `target/` | `node_modules/`, `dist/` | `target/` |
| Source directory | `src/` | `src/` | `src/`, varies | `src/main/` |
| Test directory | `tests/` | `tests/`, `src/` | `test/`, `tests/` | `src/test/` |
| Config file | Optional | Required | Required | Required |
| Auto-detection | Yes | No | Partial | No |

## Best Practices

1. **Follow conventions**: Use standard directory names
2. **Minimal config**: Only configure what's non-standard
3. **Use presets**: Start with appropriate preset
4. **Centralized build**: Keep all artifacts in `build/`
5. **Version control**: Commit source, ignore `build/`

## Troubleshooting

### Config not found
- TestKit will use auto-detection
- Run `nimtestkit_init` to create standard structure

### Wrong directories detected
- Create explicit config with correct paths
- Or restructure to match conventions

### Build artifacts in wrong place
- Check `build.output_dir` in config
- Ensure using latest TestKit version

## Future Enhancements

- Watch mode with incremental builds in `build/cache/`
- Dependency tracking in `build/deps/`
- Cross-compilation targets in `build/target-triple/`
- Package generation in `build/packages/`