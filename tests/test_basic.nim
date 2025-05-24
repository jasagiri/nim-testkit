import unittest
import os

# Get the path to the package root directory
let pkgRootDir = currentSourcePath.parentDir.parentDir

suite "Nim TestKit Basic Test":
  test "Verify toolkit structure exists":
    # First test each directory with explicit checks
    check os.dirExists(os.joinPath(pkgRootDir, "src"))
    check os.dirExists(os.joinPath(pkgRootDir, "scripts"))
    check os.dirExists(os.joinPath(pkgRootDir, "scripts", "generate"))
    check os.dirExists(os.joinPath(pkgRootDir, "scripts", "run"))
    check os.dirExists(os.joinPath(pkgRootDir, "scripts", "guard"))
    check os.dirExists(os.joinPath(pkgRootDir, "scripts", "coverage"))
    check os.dirExists(os.joinPath(pkgRootDir, "scripts", "hooks"))
    
  test "Source files exist":
    # Check each source file exists
    check os.fileExists(os.joinPath(pkgRootDir, "src", "generation", "generator.nim"))
    check os.fileExists(os.joinPath(pkgRootDir, "src", "execution", "runner.nim"))
    check os.fileExists(os.joinPath(pkgRootDir, "src", "execution", "guard.nim"))
    check os.fileExists(os.joinPath(pkgRootDir, "src", "analysis", "coverage.nim"))
    
  test "Scripts exist":
    when defined(windows):
      check os.fileExists(os.joinPath(pkgRootDir, "scripts", "generate", "generate.bat"))
      check os.fileExists(os.joinPath(pkgRootDir, "scripts", "run", "run.bat"))
      check os.fileExists(os.joinPath(pkgRootDir, "scripts", "guard", "guard.bat"))
      check os.fileExists(os.joinPath(pkgRootDir, "scripts", "coverage", "coverage.bat"))
      check os.fileExists(os.joinPath(pkgRootDir, "scripts", "hooks", "install_hooks.bat"))
    else:
      check os.fileExists(os.joinPath(pkgRootDir, "scripts", "generate", "generate.sh"))
      check os.fileExists(os.joinPath(pkgRootDir, "scripts", "run", "run.sh"))
      check os.fileExists(os.joinPath(pkgRootDir, "scripts", "guard", "guard.sh"))
      check os.fileExists(os.joinPath(pkgRootDir, "scripts", "coverage", "coverage.sh"))
      check os.fileExists(os.joinPath(pkgRootDir, "scripts", "hooks", "install_hooks.sh"))