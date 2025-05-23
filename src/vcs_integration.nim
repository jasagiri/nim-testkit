## VCS Integration Module for Nim TestKit
##
## Provides unified interface for multiple version control systems

import std/[os, osproc, strformat, strutils, tables]
import config

proc isCommandAvailable(cmd: string): bool =
  ## Check if a command is available in PATH
  try:
    when defined(windows):
      let (_, exitCode) = execCmdEx(fmt"where {cmd}")
    else:
      let (_, exitCode) = execCmdEx(fmt"which {cmd}")
    return exitCode == 0
  except:
    return false

type
  VCSType* = enum
    vcsNone = "none"
    vcsGit = "git"
    vcsJujutsu = "jujutsu"
    vcsMercurial = "mercurial"
    vcsSVN = "svn"
    vcsFossil = "fossil"
    
  VCSInfo* = object
    vcsType*: VCSType
    rootDir*: string
    currentBranch*: string
    modifiedFiles*: seq[string]
    hasChanges*: bool
    
  VCSInterface* = ref object
    config*: VCSConfig
    detectedVCS*: seq[VCSType]

proc detectVCS(dir: string = getCurrentDir()): seq[VCSType] =
  ## Detect which VCS systems are present in the current directory
  result = @[]
  
  # Check for Git
  if dirExists(dir / ".git"):
    result.add(vcsGit)
  
  # Check for Jujutsu (can coexist with Git)
  if dirExists(dir / ".jj"):
    result.add(vcsJujutsu)
  
  # Check for Mercurial
  if dirExists(dir / ".hg"):
    result.add(vcsMercurial)
  
  # Check for SVN
  if dirExists(dir / ".svn"):
    result.add(vcsSVN)
  
  # Check for Fossil
  if fileExists(dir / ".fslckout") or fileExists(dir / "_FOSSIL_"):
    result.add(vcsFossil)

proc newVCSInterface*(config: VCSConfig): VCSInterface =
  ## Create a new VCS interface with the given configuration
  result = VCSInterface(
    config: config,
    detectedVCS: detectVCS()
  )

proc isEnabled*(vcs: VCSInterface, vcsType: VCSType): bool =
  ## Check if a VCS type is enabled, detected, and command is available
  case vcsType:
  of vcsGit: 
    return vcs.config.git and vcsGit in vcs.detectedVCS and isCommandAvailable("git")
  of vcsJujutsu: 
    return vcs.config.jujutsu and vcsJujutsu in vcs.detectedVCS and isCommandAvailable("jj")
  of vcsMercurial: 
    return vcs.config.mercurial and vcsMercurial in vcs.detectedVCS and isCommandAvailable("hg")
  of vcsSVN: 
    return vcs.config.svn and vcsSVN in vcs.detectedVCS and isCommandAvailable("svn")
  of vcsFossil: 
    return vcs.config.fossil and vcsFossil in vcs.detectedVCS and isCommandAvailable("fossil")
  of vcsNone: return false

proc getGitInfo(): VCSInfo =
  ## Get information from Git repository
  result.vcsType = vcsGit
  
  if not isCommandAvailable("git"):
    return
  
  # Get root directory
  let (rootOutput, rootCode) = execCmdEx("git rev-parse --show-toplevel")
  if rootCode == 0:
    result.rootDir = rootOutput.strip()
  
  # Get current branch
  let (branchOutput, branchCode) = execCmdEx("git branch --show-current")
  if branchCode == 0:
    result.currentBranch = branchOutput.strip()
  
  # Get modified files
  let (statusOutput, statusCode) = execCmdEx("git status --porcelain")
  if statusCode == 0:
    for line in statusOutput.splitLines():
      if line.len > 3:
        result.modifiedFiles.add(line[3..^1])
    result.hasChanges = result.modifiedFiles.len > 0

proc getJujutsuInfo(): VCSInfo =
  ## Get information from Jujutsu repository
  result.vcsType = vcsJujutsu
  
  if not isCommandAvailable("jj"):
    return
  
  # Get root directory
  let (rootOutput, rootCode) = execCmdEx("jj root")
  if rootCode == 0:
    result.rootDir = rootOutput.strip()
  
  # Get current change
  let (changeOutput, changeCode) = execCmdEx("""jj log -r @ --no-graph --template 'change_id ++ "\n"'""")
  if changeCode == 0:
    result.currentBranch = changeOutput.strip()[0..11]  # First 12 chars of change ID
  
  # Get modified files
  let (statusOutput, statusCode) = execCmdEx("jj status")
  if statusCode == 0:
    var inWorkingCopy = false
    for line in statusOutput.splitLines():
      if line.startsWith("Working copy changes"):
        inWorkingCopy = true
      elif inWorkingCopy and line.startsWith("M ") or line.startsWith("A ") or line.startsWith("D "):
        result.modifiedFiles.add(line[2..^1].strip())
    result.hasChanges = result.modifiedFiles.len > 0

proc getMercurialInfo(): VCSInfo =
  ## Get information from Mercurial repository
  result.vcsType = vcsMercurial
  
  if not isCommandAvailable("hg"):
    return
  
  # Get root directory
  let (rootOutput, rootCode) = execCmdEx("hg root")
  if rootCode == 0:
    result.rootDir = rootOutput.strip()
  
  # Get current branch
  let (branchOutput, branchCode) = execCmdEx("hg branch")
  if branchCode == 0:
    result.currentBranch = branchOutput.strip()
  
  # Get modified files
  let (statusOutput, statusCode) = execCmdEx("hg status")
  if statusCode == 0:
    for line in statusOutput.splitLines():
      if line.len > 2:
        result.modifiedFiles.add(line[2..^1])
    result.hasChanges = result.modifiedFiles.len > 0

proc getSVNInfo(): VCSInfo =
  ## Get information from SVN repository
  result.vcsType = vcsSVN
  
  if not isCommandAvailable("svn"):
    return
  
  result.rootDir = getCurrentDir()
  
  # Get current URL (branch equivalent)
  let (infoOutput, infoCode) = execCmdEx("svn info --show-item url")
  if infoCode == 0:
    let url = infoOutput.strip()
    result.currentBranch = url.split("/")[^1]
  
  # Get modified files
  let (statusOutput, statusCode) = execCmdEx("svn status")
  if statusCode == 0:
    for line in statusOutput.splitLines():
      if line.len > 7 and line[0] in ['M', 'A', 'D']:
        result.modifiedFiles.add(line[7..^1].strip())
    result.hasChanges = result.modifiedFiles.len > 0

proc getFossilInfo(): VCSInfo =
  ## Get information from Fossil repository
  result.vcsType = vcsFossil
  
  if not isCommandAvailable("fossil"):
    return
  
  result.rootDir = getCurrentDir()
  
  # Get current branch
  let (branchOutput, branchCode) = execCmdEx("fossil branch current")
  if branchCode == 0:
    result.currentBranch = branchOutput.strip()
  
  # Get modified files
  let (statusOutput, statusCode) = execCmdEx("fossil changes")
  if statusCode == 0:
    for line in statusOutput.splitLines():
      if line.len > 0:
        result.modifiedFiles.add(line.strip())
    result.hasChanges = result.modifiedFiles.len > 0

proc getVCSInfo*(vcs: VCSInterface): Table[VCSType, VCSInfo] =
  ## Get information from all enabled VCS systems
  result = initTable[VCSType, VCSInfo]()
  
  if vcs.isEnabled(vcsGit):
    try:
      result[vcsGit] = getGitInfo()
    except:
      discard
  
  if vcs.isEnabled(vcsJujutsu):
    try:
      result[vcsJujutsu] = getJujutsuInfo()
    except:
      discard
  
  if vcs.isEnabled(vcsMercurial):
    try:
      result[vcsMercurial] = getMercurialInfo()
    except:
      discard
  
  if vcs.isEnabled(vcsSVN):
    try:
      result[vcsSVN] = getSVNInfo()
    except:
      discard
  
  if vcs.isEnabled(vcsFossil):
    try:
      result[vcsFossil] = getFossilInfo()
    except:
      discard

proc getModifiedFiles*(vcs: VCSInterface): seq[string] =
  ## Get all modified files from all enabled VCS systems
  result = @[]
  let vcsInfos = vcs.getVCSInfo()
  
  for vcsType, info in vcsInfos:
    for file in info.modifiedFiles:
      if file notin result:
        result.add(file)

proc hasChanges*(vcs: VCSInterface): bool =
  ## Check if any enabled VCS has changes
  let vcsInfos = vcs.getVCSInfo()
  
  for vcsType, info in vcsInfos:
    if info.hasChanges:
      return true
  
  return false

proc getTestFilesForChanges*(vcs: VCSInterface, allTestFiles: seq[string]): seq[string] =
  ## Filter test files based on VCS changes
  let modifiedFiles = vcs.getModifiedFiles()
  
  if modifiedFiles.len == 0:
    return allTestFiles
  
  result = @[]
  
  # Find tests related to modified files
  for modFile in modifiedFiles:
    let baseName = modFile.extractFilename().changeFileExt("")
    for testFile in allTestFiles:
      if baseName in testFile and testFile notin result:
        result.add(testFile)
  
  # If no specific tests found, return all tests
  if result.len == 0:
    return allTestFiles

proc getVCSStatusSummary*(vcs: VCSInterface): string =
  ## Get a summary of VCS status
  let vcsInfos = vcs.getVCSInfo()
  
  if vcsInfos.len == 0:
    return "No VCS detected or enabled"
  
  result = "VCS Status:\n"
  
  for vcsType, info in vcsInfos:
    result &= fmt"  {vcsType}: "
    if info.currentBranch != "":
      result &= fmt"branch/change '{info.currentBranch}'"
    if info.hasChanges:
      result &= fmt", {info.modifiedFiles.len} modified files"
    else:
      result &= ", no changes"
    result &= "\n"

proc installHooks*(vcs: VCSInterface, hookType: string, hookContent: string) =
  ## Install hooks for enabled VCS systems
  if vcs.isEnabled(vcsGit):
    let gitHookPath = ".git/hooks" / hookType
    writeFile(gitHookPath, hookContent)
    when not defined(windows):
      discard execCmd(fmt"chmod +x {gitHookPath}")
  
  if vcs.isEnabled(vcsJujutsu):
    let jjHookPath = ".jj/hooks" / hookType
    if not dirExists(".jj/hooks"):
      createDir(".jj/hooks")
    writeFile(jjHookPath, hookContent)
    when not defined(windows):
      discard execCmd(fmt"chmod +x {jjHookPath}")
  
  if vcs.isEnabled(vcsMercurial):
    # Mercurial hooks are configured in .hg/hgrc
    echo "Note: Mercurial hooks should be configured in .hg/hgrc"
  
  # SVN and Fossil hooks are typically server-side