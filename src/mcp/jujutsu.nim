## MCP Integration for Jujutsu
##
## This module provides access to the MCP-Jujutsu functionality
## for semantic commit analysis and division.

import std/[asyncdispatch, options, os]

when defined(useMcpJujutsu):
  # If the useMcpJujutsu flag is defined, use the actual implementation
  import "../../vendor/mcp-jujutsu/src/client/client" as mcp_client
  export mcp_client
else:
  # Provide stub/minimal implementation if mcp-jujutsu is not available
  import std/[httpclient, json, uri]
  
  type
    McpClient* = ref object
      baseUrl*: string
      httpClient*: AsyncHttpClient
      
    McpError* = object of CatchableError
  
  proc newMcpClient*(baseUrl: string = "http://localhost:8080/mcp"): McpClient =
    ## Creates a new MCP client connected to the specified endpoint
    result = McpClient(
      baseUrl: baseUrl,
      httpClient: newAsyncHttpClient()
    )
  
  proc analyzeCommitRange*(client: McpClient, repoPath: string, commitRange: string): Future[JsonNode] {.async.} =
    ## Stub implementation for analyzing a commit range
    raise newException(McpError, "MCP-Jujutsu integration not enabled. Compile with -d:useMcpJujutsu")
  
  proc proposeCommitDivision*(client: McpClient, repoPath: string, commitRange: string): Future[JsonNode] {.async.} =
    ## Stub implementation for proposing a commit division
    raise newException(McpError, "MCP-Jujutsu integration not enabled. Compile with -d:useMcpJujutsu")
  
  proc executeCommitDivision*(client: McpClient, repoPath: string, proposal: JsonNode): Future[JsonNode] {.async.} =
    ## Stub implementation for executing a commit division
    raise newException(McpError, "MCP-Jujutsu integration not enabled. Compile with -d:useMcpJujutsu")
  
  proc automateCommitDivision*(client: McpClient, repoPath: string, commitRange: string): Future[JsonNode] {.async.} =
    ## Stub implementation for automating commit division
    raise newException(McpError, "MCP-Jujutsu integration not enabled. Compile with -d:useMcpJujutsu")

# Convenience function to check if mcp-jujutsu is available and enabled
proc isMcpJujutsuAvailable*(): bool =
  when defined(useMcpJujutsu):
    return true
  else:
    return false