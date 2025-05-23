# Nim TestKit Build Structure

This document describes the build and distribution structure of Nim TestKit, which is designed to be similar to Rust's Cargo system.

## Directory Structure

```
nim-testkit/
├── src/              # Source code
├── build/            # Build artifacts
│   ├── debug/        # Debug builds
│   │   ├── linux/    # Linux-specific binaries
│   │   ├── macos/    # macOS-specific binaries
│   │   └── windows/  # Windows-specific binaries
│   └── release/      # Release builds
│       ├── linux/    # Linux-specific binaries
│       ├── macos/    # macOS-specific binaries
│       └── windows/  # Windows-specific binaries
├── bin/              # Distribution binaries (copied from release build)
└── templates/        # Template files for project setup
```

## Build Process

Nim TestKit uses a multi-stage build process:

1. **Debug Build**: `nimble build_debug`
   - Compiler optimizations: None
   - Debug information: Full
   - Output directory: `build/debug/<platform>/`
   - Used for: Development and testing

2. **Release Build**: `nimble build_release`
   - Compiler optimizations: Speed
   - Debug information: None
   - Output directory: `build/release/<platform>/`
   - Used for: Performance testing and pre-distribution

3. **Distribution**: `nimble dist`
   - Performs a release build
   - Copies binaries to the `bin/` directory
   - Used for: Final distribution and installation

## Platform-Specific Builds

Nim TestKit automatically detects the current platform and builds for it:

- **Linux**: Binaries are placed in the `linux/` subdirectory
- **macOS**: Binaries are placed in the `macos/` subdirectory
- **Windows**: Binaries are placed in the `windows/` subdirectory with `.exe` extension

## Script Integration

Scripts are designed to look for binaries in the following order:

1. Distribution binaries in `bin/`
2. Release binaries in `build/release/<platform>/`
3. Debug binaries in `build/debug/<platform>/`
4. If no binary is found, build from source

This approach allows developers to work with different build configurations while always using the most appropriate binary.

## Nimble Tasks

The following Nimble tasks are available for building:

```nim
nimble build_debug    # Build debug binaries
nimble build_release  # Build release binaries
nimble dist           # Create distribution binaries
```

## Cross-Platform Compilation

For cross-platform compilation, you need to specify the target platform:

```bash
# For Windows cross-compilation (from Linux/macOS)
nim c -d:mingw -o:build/release/windows/binary.exe src/binary.nim

# For Linux cross-compilation (from macOS/Windows)
nim c -d:linux -o:build/release/linux/binary src/binary.nim

# For macOS cross-compilation (from Linux/Windows)
nim c -d:macosx -o:build/release/macos/binary src/binary.nim
```

Note: Cross-compilation requires appropriate cross-compilers to be installed.