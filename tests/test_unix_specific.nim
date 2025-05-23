import unittest
import os

# Get the path to the package root directory
let pkgRootDir = currentSourcePath.parentDir.parentDir

suite "Nim TestKit Unix-specific Tests":
  test "Shell scripts are executable":
    # Check each script is executable
    let generateSh = os.joinPath(pkgRootDir, "scripts", "generate", "generate.sh")
    let runSh = os.joinPath(pkgRootDir, "scripts", "run", "run.sh")
    let guardSh = os.joinPath(pkgRootDir, "scripts", "guard", "guard.sh")
    let coverageSh = os.joinPath(pkgRootDir, "scripts", "coverage", "coverage.sh")
    let installHooksSh = os.joinPath(pkgRootDir, "scripts", "hooks", "install_hooks.sh")
    let preCommit = os.joinPath(pkgRootDir, "scripts", "hooks", "pre-commit")
    
    # Check executability of each file separately for better error reporting
    if os.fileExists(generateSh):
      let perms = os.getFilePermissions(generateSh)
      let isExecutable = (os.fpUserExec in perms) or (os.fpGroupExec in perms) or (os.fpOthersExec in perms)
      check isExecutable
      
    if os.fileExists(runSh):
      let perms = os.getFilePermissions(runSh)
      let isExecutable = (os.fpUserExec in perms) or (os.fpGroupExec in perms) or (os.fpOthersExec in perms)
      check isExecutable
      
    if os.fileExists(guardSh):
      let perms = os.getFilePermissions(guardSh)
      let isExecutable = (os.fpUserExec in perms) or (os.fpGroupExec in perms) or (os.fpOthersExec in perms)
      check isExecutable
      
    if os.fileExists(coverageSh):
      let perms = os.getFilePermissions(coverageSh)
      let isExecutable = (os.fpUserExec in perms) or (os.fpGroupExec in perms) or (os.fpOthersExec in perms)
      check isExecutable
      
    if os.fileExists(installHooksSh):
      let perms = os.getFilePermissions(installHooksSh)
      let isExecutable = (os.fpUserExec in perms) or (os.fpGroupExec in perms) or (os.fpOthersExec in perms)
      check isExecutable
      
    if os.fileExists(preCommit):
      let perms = os.getFilePermissions(preCommit)
      let isExecutable = (os.fpUserExec in perms) or (os.fpGroupExec in perms) or (os.fpOthersExec in perms)
      check isExecutable