## Dependency analysis tool for nim-testkit
## Analyzes project dependencies and suggests improvements

import std/[os, strutils, sequtils, tables, sets, json, re, algorithm, strformat]
import ./config

type
  ImportInfo* = object
    module*: string
    isLocal*: bool
    isStd*: bool
    isExternal*: bool
    symbols*: seq[string]  # Specific symbols imported
    
  ModuleInfo* = object
    path*: string
    imports*: seq[ImportInfo]
    exports*: seq[string]
    dependencies*: seq[string]
    dependents*: seq[string]
    
  CycleInfo* = object
    modules*: seq[string]
    
  DependencyGraph* = ref object
    modules*: Table[string, ModuleInfo]
    cycles*: seq[CycleInfo]
    layers*: seq[seq[string]]  # Dependency layers
    
  DependencyAnalyzer* = ref object
    projectRoot*: string
    graph*: DependencyGraph
    stdModules*: HashSet[string]

# Standard library modules (partial list)
const StdModules = [
  "os", "strutils", "sequtils", "tables", "sets", "hashes",
  "json", "parseopt", "terminal", "times", "math", "random",
  "algorithm", "unicode", "strformat", "sugar", "options",
  "asyncdispatch", "asyncfile", "asyncnet", "httpclient",
  "net", "uri", "base64", "md5", "sha1", "oids", "re", "nre"
].toHashSet()

proc newDependencyAnalyzer*(projectRoot = getCurrentDir()): DependencyAnalyzer =
  result = DependencyAnalyzer(
    projectRoot: projectRoot,
    graph: DependencyGraph(
      modules: initTable[string, ModuleInfo](),
      cycles: @[],
      layers: @[]
    ),
    stdModules: StdModules
  )

proc parseImports(content: string): seq[ImportInfo] =
  ## Parse import statements from Nim source
  result = @[]
  
  # Regular import
  let importRe = re"(?m)^import\s+(.+)$"
  for match in content.findAll(importRe):
    let importLine = match.strip()
    if importLine.startsWith("import "):
      let imports = importLine[7..^1]
      
      # Handle multiple imports
      for imp in imports.split(","):
        let cleaned = imp.strip()
        var info = ImportInfo(module: cleaned)
        
        # Check if it's a standard library module
        let baseModule = cleaned.split("/")[0].split("[")[0]
        info.isStd = baseModule in StdModules
        info.isLocal = cleaned.startsWith("./") or cleaned.startsWith("../")
        info.isExternal = not info.isStd and not info.isLocal
        
        result.add(info)
  
  # From import
  let fromImportRe = re"(?m)^from\s+(\S+)\s+import\s+(.+)$"
  for match in content.findAll(fromImportRe):
    let parts = match.strip().split("import")
    if parts.len == 2:
      let module = parts[0].strip()[5..^1].strip()  # Remove "from "
      let symbols = parts[1].strip().split(",").mapIt(it.strip())
      
      var info = ImportInfo(
        module: module,
        symbols: symbols
      )
      
      let baseModule = module.split("/")[0]
      info.isStd = baseModule in StdModules
      info.isLocal = module.startsWith("./") or module.startsWith("../")
      info.isExternal = not info.isStd and not info.isLocal
      
      result.add(info)

proc parseExports(content: string): seq[string] =
  ## Parse exported symbols from Nim source
  result = @[]
  
  # Find exported procs, funcs, types, etc.
  let exportRe = re"(?m)^(proc|func|method|template|macro|type|const|var|let)\s+(\w+)\*"
  for match in content.findAll(exportRe):
    let parts = match.strip().split()
    if parts.len >= 2:
      let symbol = parts[1].replace("*", "")
      result.add(symbol)

proc analyzeModule(da: DependencyAnalyzer, path: string): ModuleInfo =
  ## Analyze a single module
  result = ModuleInfo(
    path: path,
    imports: @[],
    exports: @[],
    dependencies: @[],
    dependents: @[]
  )
  
  if not fileExists(path):
    return
  
  try:
    let content = readFile(path)
    result.imports = parseImports(content)
    result.exports = parseExports(content)
    
    # Extract dependency module names
    for imp in result.imports:
      if imp.isLocal:
        # Resolve local path
        let importPath = path.parentDir() / imp.module.replace(".", "/") & ".nim"
        let normalizedPath = importPath.normalizedPath()
        if fileExists(normalizedPath):
          result.dependencies.add(normalizedPath)
      else:
        result.dependencies.add(imp.module)
  except:
    discard

proc buildDependencyGraph*(da: DependencyAnalyzer) =
  ## Build the complete dependency graph
  # First pass: analyze all modules
  for file in walkDirRec(da.projectRoot):
    if file.endsWith(".nim") and not file.contains("nimcache"):
      let moduleInfo = da.analyzeModule(file)
      da.graph.modules[file] = moduleInfo
  
  # Second pass: build reverse dependencies
  for path, module in da.graph.modules:
    for dep in module.dependencies:
      if dep in da.graph.modules:
        da.graph.modules[dep].dependents.add(path)

proc detectCycles(da: DependencyAnalyzer) =
  ## Detect dependency cycles using DFS
  var visited = initHashSet[string]()
  var recursionStack = initHashSet[string]()
  var currentPath: seq[string] = @[]
  
  proc dfs(module: string): bool =
    visited.incl(module)
    recursionStack.incl(module)
    currentPath.add(module)
    
    if module in da.graph.modules:
      for dep in da.graph.modules[module].dependencies:
        if dep notin visited:
          if dfs(dep):
            return true
        elif dep in recursionStack:
          # Found a cycle
          let cycleStart = currentPath.find(dep)
          if cycleStart >= 0:
            let cycle = currentPath[cycleStart..^1]
            da.graph.cycles.add(CycleInfo(modules: cycle))
          return true
    
    currentPath.setLen(currentPath.len - 1)
    recursionStack.excl(module)
    return false
  
  for module in da.graph.modules.keys:
    if module notin visited:
      discard dfs(module)

proc calculateLayers(da: DependencyAnalyzer) =
  ## Calculate dependency layers (topological sort)
  var inDegree = initTable[string, int]()
  var queue: seq[string] = @[]
  
  # Initialize in-degrees
  for path, module in da.graph.modules:
    inDegree[path] = 0
  
  # Calculate in-degrees
  for path, module in da.graph.modules:
    for dep in module.dependencies:
      if dep in da.graph.modules:
        inDegree[dep] = inDegree.getOrDefault(dep, 0) + 1
  
  # Find modules with no dependencies
  for path, degree in inDegree:
    if degree == 0:
      queue.add(path)
  
  # Process layers
  while queue.len > 0:
    let currentLayer = queue
    da.graph.layers.add(currentLayer)
    queue = @[]
    
    for module in currentLayer:
      if module in da.graph.modules:
        for dependent in da.graph.modules[module].dependents:
          inDegree[dependent] = inDegree[dependent] - 1
          if inDegree[dependent] == 0:
            queue.add(dependent)

proc findUnusedDependencies*(da: DependencyAnalyzer): Table[string, seq[string]] =
  ## Find imported but unused modules
  result = initTable[string, seq[string]]()
  
  for path, module in da.graph.modules:
    var unused: seq[string] = @[]
    
    # Check each import
    for imp in module.imports:
      if imp.symbols.len > 0:
        # Check if imported symbols are used
        let content = readFile(path)
        var anyUsed = false
        for symbol in imp.symbols:
          # Simple check - could be improved with AST
          if content.count(symbol) > 1:  # More than just the import
            anyUsed = true
            break
        if not anyUsed:
          unused.add(imp.module)
      # For general imports, harder to detect if unused without full analysis
    
    if unused.len > 0:
      result[path] = unused

proc findCircularDependencies*(da: DependencyAnalyzer): seq[CycleInfo] =
  ## Find all circular dependencies
  da.detectCycles()
  result = da.graph.cycles

proc suggestLayering*(da: DependencyAnalyzer): seq[seq[string]] =
  ## Suggest module layering to avoid circular dependencies
  da.calculateLayers()
  result = da.graph.layers

proc generateDependencyReport*(da: DependencyAnalyzer): string =
  ## Generate a comprehensive dependency report
  da.buildDependencyGraph()
  da.detectCycles()
  da.calculateLayers()
  
  result = "# Dependency Analysis Report\n\n"
  result &= fmt"Project: {da.projectRoot}\n"
  result &= fmt"Total modules: {da.graph.modules.len}\n\n"
  
  # Module statistics
  result &= "## Module Statistics\n"
  var maxDeps = 0
  var maxDepsModule = ""
  var maxDependents = 0
  var maxDependentsModule = ""
  
  for path, module in da.graph.modules:
    if module.dependencies.len > maxDeps:
      maxDeps = module.dependencies.len
      maxDepsModule = path
    if module.dependents.len > maxDependents:
      maxDependents = module.dependents.len
      maxDependentsModule = path
  
  result &= fmt"- Most dependencies: {maxDepsModule.extractFilename()} ({maxDeps} deps)\n"
  result &= fmt"- Most dependents: {maxDependentsModule.extractFilename()} ({maxDependents} dependents)\n\n"
  
  # Circular dependencies
  result &= "## Circular Dependencies\n"
  if da.graph.cycles.len > 0:
    result &= fmt"Found {da.graph.cycles.len} circular dependencies:\n"
    for i, cycle in da.graph.cycles:
      result &= fmt"\nCycle {i+1}:\n"
      for module in cycle.modules:
        result &= fmt"  → {module.extractFilename()}\n"
  else:
    result &= "No circular dependencies found! ✓\n"
  
  # Dependency layers
  result &= "\n## Dependency Layers\n"
  result &= "Modules organized by dependency depth:\n\n"
  for i, layer in da.graph.layers:
    result &= fmt"Layer {i} ({layer.len} modules):\n"
    for module in layer[0..min(5, layer.len-1)]:
      result &= fmt"  - {module.extractFilename()}\n"
    if layer.len > 5:
      result &= fmt"  ... and {layer.len - 5} more\n"
    result &= "\n"
  
  # External dependencies
  result &= "## External Dependencies\n"
  var externalDeps = initHashSet[string]()
  for path, module in da.graph.modules:
    for imp in module.imports:
      if imp.isExternal:
        externalDeps.incl(imp.module)
  
  if externalDeps.len > 0:
    result &= "External packages used:\n"
    for dep in externalDeps:
      result &= fmt"  - {dep}\n"
  else:
    result &= "No external dependencies\n"
  
  result &= "\n## Recommendations\n"
  if da.graph.cycles.len > 0:
    result &= "1. Break circular dependencies by:\n"
    result &= "   - Extracting shared interfaces\n"
    result &= "   - Using dependency injection\n"
    result &= "   - Reorganizing module structure\n"
  
  if maxDeps > 10:
    result &= "2. Consider splitting modules with many dependencies\n"
  
  if externalDeps.len > 20:
    result &= "3. Review external dependencies for redundancy\n"

proc generateDotGraph*(da: DependencyAnalyzer): string =
  ## Generate Graphviz DOT format for visualization
  result = "digraph Dependencies {\n"
  result &= "  rankdir=TB;\n"
  result &= "  node [shape=box];\n\n"
  
  # Add nodes
  for path in da.graph.modules.keys:
    let name = path.extractFilename().changeFileExt("")
    result &= fmt"""  "{name}" [label="{name}"];\n"""
  
  # Add edges
  for path, module in da.graph.modules:
    let fromName = path.extractFilename().changeFileExt("")
    for dep in module.dependencies:
      if dep in da.graph.modules:
        let toName = dep.extractFilename().changeFileExt("")
        result &= fmt"""  "{fromName}" -> "{toName}";\n"""
  
  result &= "}\n"