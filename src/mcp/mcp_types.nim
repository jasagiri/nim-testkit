## MCP (Model Context Protocol) Types for Nim TestKit
##
## Provides type definitions and utilities for MCP integration

import std/[json, tables, options]

type
  McpCapability* = enum
    mcpTools = "tools"
    mcpResources = "resources"
    mcpPrompts = "prompts"
    mcpRoots = "roots"
    mcpSampling = "sampling"

  McpServerConfig* = object
    name*: string
    command*: string
    args*: seq[string]
    env*: Table[string, string]
    capabilities*: set[McpCapability]
    enabled*: bool
    timeout*: int  # seconds

  McpClientConfig* = object
    mcpVersion*: string
    capabilities*: set[McpCapability]
    clientInfo*: ClientInfo

  ClientInfo* = object
    name*: string
    version*: string

  McpTransport* = enum
    transportStdio = "stdio"
    transportHttp = "http"
    transportSse = "sse"

  McpMessage* = object
    jsonrpc*: string
    id*: Option[JsonNode]
    `method`*: Option[string]
    params*: Option[JsonNode]
    result*: Option[JsonNode]
    error*: Option[McpError]

  McpError* = object
    code*: int
    message*: string
    data*: Option[JsonNode]

  McpToolCall* = object
    name*: string
    arguments*: JsonNode

  McpToolResult* = object
    content*: seq[McpContent]
    isError*: bool

  McpContent* = object
    `type`*: string
    text*: Option[string]
    data*: Option[string]
    mimeType*: Option[string]

  McpResource* = object
    uri*: string
    name*: string
    description*: Option[string]
    mimeType*: Option[string]

  McpPrompt* = object
    name*: string
    description*: Option[string]
    arguments*: Option[seq[McpPromptArgument]]

  McpPromptArgument* = object
    name*: string
    description*: Option[string]
    required*: bool

  # VCS-specific MCP server configurations
  VcsMcpServers* = object
    git*: McpServerConfig
    github*: McpServerConfig
    gitlab*: McpServerConfig
    jujutsu*: McpServerConfig

const
  MCP_VERSION* = "2024-11-05"
  
  # Default server configurations
  DEFAULT_GIT_SERVER* = McpServerConfig(
    name: "git",
    command: "uv",
    args: @["--directory", "vendor/servers/src/git", "run", "mcp-server-git"],
    env: initTable[string, string](),
    capabilities: {mcpTools},
    enabled: true,
    timeout: 30
  )

  DEFAULT_GITHUB_SERVER* = McpServerConfig(
    name: "github",
    command: "node",
    args: @["vendor/servers/src/github/index.js"],
    env: {"GITHUB_TOKEN": ""}.toTable,
    capabilities: {mcpTools, mcpResources},
    enabled: true,
    timeout: 30
  )

  DEFAULT_GITLAB_SERVER* = McpServerConfig(
    name: "gitlab", 
    command: "node",
    args: @["vendor/servers/src/gitlab/index.js"],
    env: {"GITLAB_PERSONAL_ACCESS_TOKEN": ""}.toTable,
    capabilities: {mcpTools, mcpResources},
    enabled: true,
    timeout: 30
  )

  DEFAULT_JUJUTSU_SERVER* = McpServerConfig(
    name: "jujutsu",
    command: "nimble",
    args: @["-d:release", "run", "mcp_jujutsu"],
    env: initTable[string, string](),
    capabilities: {mcpTools, mcpResources},
    enabled: true,
    timeout: 30
  )

proc `%`*(config: McpServerConfig): JsonNode =
  ## Converts McpServerConfig to JSON
  result = %*{
    "name": config.name,
    "command": config.command,
    "args": config.args,
    "env": config.env,
    "enabled": config.enabled,
    "timeout": config.timeout
  }
  
  var caps: seq[string]
  for cap in config.capabilities:
    caps.add($cap)
  result["capabilities"] = %caps

proc `%`*(msg: McpMessage): JsonNode =
  ## Converts McpMessage to JSON
  result = %*{
    "jsonrpc": msg.jsonrpc
  }
  
  if msg.id.isSome:
    result["id"] = msg.id.get
  if msg.`method`.isSome:
    result["method"] = %msg.`method`.get
  if msg.params.isSome:
    result["params"] = msg.params.get
  if msg.result.isSome:
    result["result"] = msg.result.get
  if msg.error.isSome:
    result["error"] = %msg.error.get

proc `%`*(error: McpError): JsonNode =
  ## Converts McpError to JSON
  result = %*{
    "code": error.code,
    "message": error.message
  }
  
  if error.data.isSome:
    result["data"] = error.data.get

proc `%`*(content: McpContent): JsonNode =
  ## Converts McpContent to JSON
  result = %*{
    "type": content.`type`
  }
  
  if content.text.isSome:
    result["text"] = %content.text.get
  if content.data.isSome:
    result["data"] = %content.data.get
  if content.mimeType.isSome:
    result["mimeType"] = %content.mimeType.get

proc newMcpMessage*(id: JsonNode = nil, `method`: string = "", 
                   params: JsonNode = nil): McpMessage =
  ## Creates a new MCP message
  result = McpMessage(
    jsonrpc: "2.0",
    id: if id != nil: some(id) else: none(JsonNode),
    `method`: if `method` != "": some(`method`) else: none(string),
    params: if params != nil: some(params) else: none(JsonNode)
  )

proc newMcpResponse*(id: JsonNode, resultData: JsonNode = nil, 
                    error: McpError = McpError()): McpMessage =
  ## Creates a new MCP response message
  result = McpMessage(
    jsonrpc: "2.0",
    id: some(id)
  )
  
  if error.message != "":
    result.error = some(error)
  else:
    result.result = if resultData != nil: some(resultData) else: some(%*{})

proc newMcpError*(code: int, message: string, data: JsonNode = nil): McpError =
  ## Creates a new MCP error
  result = McpError(
    code: code,
    message: message,
    data: if data != nil: some(data) else: none(JsonNode)
  )

# Error codes from MCP specification
const
  MCP_PARSE_ERROR* = -32700
  MCP_INVALID_REQUEST* = -32600
  MCP_METHOD_NOT_FOUND* = -32601
  MCP_INVALID_PARAMS* = -32602
  MCP_INTERNAL_ERROR* = -32603