# Troubleshooting Guide

This guide helps you resolve common issues when using Nim TestKit.

## Quick Diagnosis

### Check Installation
```bash
# Verify Nim TestKit installation
nimble list | grep nimtestkit

# Check version
nimble --version

# Verify core functionality
nimble test
```

### Check Environment
```bash
# Verify Nim installation
nim --version

# Check PATH configuration
echo $PATH | grep nim

# Verify nimble functionality
nimble --help
```

## Common Issues

### 1. Installation Problems

#### Issue: Nimble install fails
```bash
Error: Package 'nimtestkit' not found
```

**Solutions:**
```bash
# Update nimble package list
nimble refresh

# Install from specific source
nimble install https://github.com/your-org/nim-testkit.git

# Install locally from source
git clone https://github.com/your-org/nim-testkit.git
cd nim-testkit
nimble install
```

#### Issue: Dependency conflicts
```bash
Error: Dependency 'cligen' version conflict
```

**Solutions:**
```bash
# Update all packages
nimble update

# Force install specific version
nimble install cligen@1.5.0

# Clean install
rm -rf ~/.nimble/pkgs/nimtestkit-*
nimble install nimtestkit
```

### 2. Test Generation Issues

#### Issue: No tests generated
```bash
$ nimble generate
No functions found that need tests
```

**Possible Causes & Solutions:**

1. **Wrong directory structure:**
   ```bash
   # Ensure proper structure
   mkdir -p src tests
   
   # Check configuration
   cat nimtestkit.toml
   ```

2. **No public functions:**
   ```nim
   # Ensure functions are exported
   proc myFunction*(): string =  # Note the *
     return "Hello"
   ```

3. **Incorrect file patterns:**
   ```toml
   # nimtestkit.toml
   [patterns]
   include = ["*.nim"]  # Make sure this matches your files
   exclude = ["*_test.nim", "test_*.nim"]
   ```

#### Issue: Generated tests are malformed
```bash
Error: undeclared identifier: 'myFunction'
```

**Solutions:**
```bash
# Check import paths in generated tests
cat tests/mymodule_test.nim

# Regenerate with debug info
NIMTESTKIT_DEBUG=1 nimble generate

# Clean and regenerate
rm tests/*_test.nim
nimble generate
```

### 3. Test Execution Problems

#### Issue: Tests fail to compile
```bash
Error: cannot open file: tests/mymodule_test.nim
```

**Solutions:**
```bash
# Check file permissions
ls -la tests/
chmod +r tests/*.nim

# Verify file exists and is valid
cat tests/mymodule_test.nim

# Check for circular imports
nim check tests/mymodule_test.nim
```

#### Issue: Import errors in tests
```bash
Error: cannot open '../src/mymodule'
```

**Solutions:**
```bash
# Check relative paths
# Ensure tests are in tests/ and source in src/

# Update import in test file
# From: import ../src/mymodule
# To: import mymodule

# Or configure search paths
echo '--path:"../src"' > tests/nim.cfg
```

### 4. Coverage Issues

#### Issue: No coverage data generated
```bash
$ nimble coverage
Coverage report generation failed
```

**Solutions:**
```bash
# Check if gcov is installed
which gcov

# Install gcov (Ubuntu/Debian)
sudo apt-get install gcc

# Check compiler flags
nim c --showcc tests/test_basic.nim

# Manual coverage compilation
nim c --debugger:native --passC:--coverage --passL:--coverage -r tests/test_basic.nim
```

#### Issue: Coverage threshold not met
```bash
WARNING: Coverage 75.0% is below threshold 80.0%
```

**Solutions:**
```bash
# Identify uncovered areas
nimble coverage
open build/coverage/index.html

# Generate more tests
nimble generate

# Lower threshold temporarily
# Edit nimtestkit.toml
[coverage]
threshold = 70.0
```

### 5. Guard (Continuous Testing) Issues

#### Issue: Guard not detecting changes
```bash
$ nimble guard
Monitoring for changes...
# No response to file changes
```

**Solutions:**
```bash
# Check file system events support
# Linux: inotify
ls /proc/sys/fs/inotify/

# macOS: fsevents should work automatically

# Windows: check file permissions

# Test manual trigger
touch src/test.nim
# Should trigger guard
```

#### Issue: Guard runs too frequently
```bash
# Guard triggers on every keystroke
```

**Solutions:**
```bash
# Increase debounce time
# Edit nimtestkit.toml
[guard]
debounce_ms = 1000  # Increase from default 500

# Exclude temp files
[guard]
exclude_patterns = ["*.tmp", "*.swp", "*~", ".#*"]
```

### 6. MCP Integration Issues

#### Issue: MCP servers not starting
```bash
$ nimble mcp_setup
Error: Failed to start git server
```

**Solutions:**
```bash
# Check server dependencies
# For Git server (Python)
cd vendor/servers/src/git
python -c "import git; print('GitPython available')"

# For GitHub/GitLab servers (Node.js)
cd vendor/servers/src/github
node -e "console.log('Node.js available')"

# Install missing dependencies
cd vendor/servers/src/git && uv sync
cd vendor/servers/src/github && npm install
cd vendor/servers/src/gitlab && npm install
```

#### Issue: Authentication failures
```bash
$ nimble mcp_github create-issue "Test" "Test"
Error: Authentication failed
```

**Solutions:**
```bash
# Check token is set
echo $GITHUB_TOKEN
echo $GITLAB_PERSONAL_ACCESS_TOKEN

# Test token validity
curl -H "Authorization: token $GITHUB_TOKEN" https://api.github.com/user

# Set tokens properly
export GITHUB_TOKEN="your_token_here"
export GITLAB_PERSONAL_ACCESS_TOKEN="your_gitlab_token_here"

# Add to shell profile
echo 'export GITHUB_TOKEN="your_token"' >> ~/.bashrc
source ~/.bashrc
```

#### Issue: MCP server timeouts
```bash
Error: MCP server timeout after 30 seconds
```

**Solutions:**
```bash
# Increase timeout
export MCP_SERVER_TIMEOUT=60

# Check server logs
tail -f /tmp/mcp-*.log

# Restart servers
nimble mcp_stop
nimble mcp_setup
```

### 7. Cross-Platform Issues

#### Issue: Scripts not executable (Unix/Linux/macOS)
```bash
bash: ./scripts/generate/generate.sh: Permission denied
```

**Solutions:**
```bash
# Make scripts executable
chmod +x scripts/**/*.sh

# Or run via bash
bash scripts/generate/generate.sh
```

#### Issue: Path separators (Windows)
```bash
Error: cannot open file: tests\mymodule_test.nim
```

**Solutions:**
```bash
# Use forward slashes in configuration
# nimtestkit.toml
[directories]
source = "src"      # Not "src\"
tests = "tests"     # Not "tests\"

# Use proper batch files
scripts\generate\generate.bat  # Not .sh
```

## Performance Issues

### 1. Slow Test Generation

#### Issue: Generation takes too long
```bash
$ time nimble generate
# Takes > 30 seconds
```

**Solutions:**
```bash
# Exclude large files/directories
# nimtestkit.toml
[patterns]
exclude = ["vendor/**", "build/**", "*.generated.nim"]

# Use parallel processing
# nimtestkit.toml
[generation]
parallel = true

# Profile generation
NIMTESTKIT_PROFILE=1 nimble generate
```

### 2. Slow Test Execution

#### Issue: Tests run slowly
```bash
$ time nimble tests
# Takes > 2 minutes for small project
```

**Solutions:**
```bash
# Enable parallel execution
# nimtestkit.toml
[tests]
parallel = true

# Use release builds for tests
nim c -d:release -r tests/test_basic.nim

# Profile specific tests
nim c --profiler:on -r tests/slow_test.nim
```

### 3. Memory Issues

#### Issue: Out of memory during large operations
```bash
Fatal: out of memory
```

**Solutions:**
```bash
# Increase available memory (if possible)
ulimit -v unlimited

# Process files in batches
# nimtestkit.toml
[generation]
batch_size = 10  # Process 10 files at a time

# Use streaming for large files
# nimtestkit.toml
[processing]
use_streaming = true
```

## Debug Mode

### Enable Debug Output

```bash
# General debug mode
export NIMTESTKIT_DEBUG=1

# Specific component debug
export NIMTESTKIT_GENERATOR_DEBUG=1
export NIMTESTKIT_RUNNER_DEBUG=1
export NIMTESTKIT_GUARD_DEBUG=1
export NIMTESTKIT_COVERAGE_DEBUG=1
export MCP_DEBUG=1

# Run with debug output
nimble generate  # Now shows debug info
```

### Debug Information

Debug mode provides:
- Detailed execution traces
- File processing information
- Error stack traces
- Performance timing
- Configuration loading details

### Log Files

Check log files for detailed information:
```bash
# General logs
cat ~/.nimtestkit/debug.log

# Component-specific logs
cat ~/.nimtestkit/generator.log
cat ~/.nimtestkit/runner.log
cat ~/.nimtestkit/guard.log

# MCP server logs
cat /tmp/mcp-git.log
cat /tmp/mcp-github.log
cat /tmp/mcp-gitlab.log
```

## Configuration Issues

### 1. Configuration Not Loading

#### Issue: Settings ignored
```bash
# Changes to nimtestkit.toml seem to have no effect
```

**Solutions:**
```bash
# Check file location
ls -la nimtestkit.toml

# Validate TOML syntax
# Use online TOML validator or:
python -c "import tomli; tomli.load(open('nimtestkit.toml', 'rb'))"

# Check for multiple config files
find . -name "*.toml" -o -name "*.cfg"

# Force config reload
rm ~/.nimtestkit/cache/*
nimble generate
```

### 2. Path Configuration Problems

#### Issue: Files not found
```bash
Error: Source directory 'src' not found
```

**Solutions:**
```bash
# Check current directory
pwd
ls -la

# Verify configuration paths
cat nimtestkit.toml

# Use absolute paths if needed
# nimtestkit.toml
[directories]
source = "/absolute/path/to/src"
tests = "/absolute/path/to/tests"
```

## Getting Help

### Community Resources

1. **GitHub Issues**: Report bugs and request features
2. **Documentation**: Check latest docs for updates
3. **Examples**: See example projects for working configurations

### Diagnostic Information

When reporting issues, include:

```bash
# System information
nim --version
nimble --version
uname -a  # Unix/Linux/macOS
ver       # Windows

# Nim TestKit version
nimble list | grep nimtestkit

# Configuration
cat nimtestkit.toml

# Debug output
NIMTESTKIT_DEBUG=1 nimble [command] 2>&1 | head -50
```

### Minimal Reproduction

Create a minimal example that reproduces the issue:

```bash
# Create minimal project
mkdir test-project
cd test-project

# Minimal source file
echo 'proc hello*(): string = "world"' > src/example.nim

# Minimal configuration
echo '[directories]
source = "src"
tests = "tests"' > nimtestkit.toml

# Test the issue
nimble install nimtestkit
nimble generate
```

## Prevention

### Best Practices

1. **Version Control**: Keep configuration in VCS
2. **Testing**: Test configuration changes
3. **Documentation**: Document project-specific setup
4. **Monitoring**: Use guard for continuous feedback
5. **Regular Updates**: Keep Nim TestKit updated

### Project Setup Checklist

- [ ] Proper directory structure (`src/`, `tests/`)
- [ ] Valid `nimtestkit.toml` configuration
- [ ] Executable permissions on scripts (Unix-like systems)
- [ ] Environment variables set (for MCP integration)
- [ ] Dependencies installed (Python, Node.js for MCP servers)
- [ ] Tests can be generated and run successfully
- [ ] Coverage reports generate properly
- [ ] Guard detects changes correctly

---

*If you encounter issues not covered in this guide, please check the [GitHub Issues](https://github.com/your-org/nim-testkit/issues) or create a new issue with detailed information.*