## Nim TestKit Setup Tool
##
## プロジェクトにTestKitを設定するためのツール

import std/[os, strutils, strformat]

proc copyTemplates(templateDir, targetDir: string) =
  ## テンプレートファイルをコピー
  for kind, path in walkDir(templateDir):
    let targetPath = targetDir / extractFilename(path)
    
    case kind
    of pcDir:
      # ディレクトリを再帰的にコピー
      createDir(targetPath)
      copyTemplates(path, targetPath)
    of pcFile:
      # ファイルをコピー
      copyFile(path, targetPath)
      
      # シェルスクリプトに実行権限を付与
      when defined(posix):
        if path.endsWith(".sh") or extractFilename(path) == "pre-commit":
          discard execShellCmd(fmt"chmod +x {targetPath}")
    else:
      discard

proc addNimbleTasks(nimbleFile: string) =
  ## Nimbleファイルにタスクを追加
  if not fileExists(nimbleFile):
    echo "No .nimble file found at: " & nimbleFile
    return
  
  var content = readFile(nimbleFile)
  
  # タスク定義を追加
  let testkitTasks = """
# TestKit integration tasks
task testkit_generate, "Generate tests for untested functions":
  when defined(windows):
    exec "scripts\\nim-testkit\\generate\\generate.bat"
  else:
    exec "scripts/nim-testkit/generate/generate.sh"

task testkit_run, "Run tests":
  when defined(windows):
    exec "scripts\\nim-testkit\\run\\run.bat"
  else:
    exec "scripts/nim-testkit/run/run.sh"

task testkit_guard, "Monitor source changes and run tests":
  when defined(windows):
    exec "scripts\\nim-testkit\\guard\\guard.bat"
  else:
    exec "scripts/nim-testkit/guard/guard.sh"

task testkit_coverage, "Generate test coverage report":
  when defined(windows):
    exec "scripts\\nim-testkit\\coverage\\coverage.bat"
  else:
    exec "scripts/nim-testkit/coverage/coverage.sh"

task testkit_hooks, "Install git hooks for auto testing":
  when defined(windows):
    exec "scripts\\nim-testkit\\hooks\\install_hooks.bat"
  else:
    exec "scripts/nim-testkit/hooks/install_hooks.sh"
"""

  # タスクがまだ追加されていなければ追加
  if not content.contains("task testkit_generate,") and not content.contains("task testkit_run,"):
    content.add("\n" & testkitTasks)
    writeFile(nimbleFile, content)
    echo "Added TestKit tasks to .nimble file"
  else:
    echo "TestKit tasks already exist in .nimble file"

proc setupProject(projectDir: string) =
  echo "Setting up TestKit in project: " & projectDir
  
  # 絶対パスに変換
  let projectPath = if isAbsolute(projectDir): projectDir else: getCurrentDir() / projectDir
  
  # テンプレートディレクトリを検索
  var templateDir = ""
  let possiblePaths = [
    getCurrentDir() / "templates" / "nim-testkit",
    getAppDir() / "../templates/nim-testkit",
    getEnv("NIMBLE_DIR", getHomeDir() / ".nimble") / "pkgs/nimtestkit-0.1.0/templates/nim-testkit"
  ]
  
  for path in possiblePaths:
    if dirExists(path):
      templateDir = path
      break
  
  if templateDir == "":
    echo "Error: Template directory not found"
    echo "Tried:"
    for path in possiblePaths:
      echo "  - " & path
    quit(1)
  
  # スクリプトディレクトリを作成
  let scriptDir = projectPath / "scripts" / "nim-testkit"
  createDir(scriptDir)
  
  # テンプレートをコピー
  echo "Copying TestKit scripts to: " & scriptDir
  copyTemplates(templateDir / "scripts", scriptDir)
  
  # 設定ディレクトリを作成
  let configDir = scriptDir / "config"
  createDir(configDir)
  
  # 設定テンプレートをコピー
  echo "Copying configuration templates"
  copyTemplates(templateDir / "config", configDir)
  
  # nimbleファイルを検索してタスクを追加
  var nimbleFiles: seq[string] = @[]
  for file in walkFiles(projectPath / "*.nimble"):
    nimbleFiles.add(file)
  
  if nimbleFiles.len > 0:
    addNimbleTasks(nimbleFiles[0])
  else:
    echo "Warning: No .nimble file found in project directory"
  
  echo "\nTestKit setup complete!"
  echo "You can now use the following commands:"
  echo "  nimble testkit_generate  - Generate tests"
  echo "  nimble testkit_run       - Run tests"
  echo "  nimble testkit_guard     - Monitor source changes"
  echo "  nimble testkit_coverage  - Generate coverage report"
  echo "  nimble testkit_hooks     - Install Git hooks"

proc main() =
  if paramCount() < 1:
    echo "Usage: nimtestkit_setup <project_dir>"
    quit(1)
  
  let projectDir = paramStr(1)
  setupProject(projectDir)

when isMainModule:
  main()