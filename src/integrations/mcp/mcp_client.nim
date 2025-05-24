## MCP Client for Nim TestKit
##
## Provides client functionality to communicate with MCP servers

import std/[asyncdispatch, json, strutils, strformat, osproc, streams, tables, strtabs, options, logging]
import ./mcp_types

type
  McpClient* = ref object
    config*: McpServerConfig
    process*: Process
    input*: Stream
    output*: Stream
    running*: bool
    messageId*: int

  McpClientError* = object of CatchableError

proc newMcpClient*(config: McpServerConfig): McpClient =
  ## Creates a new MCP client
  result = McpClient(
    config: config,
    running: false,
    messageId: 0
  )

proc nextMessageId*(client: McpClient): int =
  ## Gets the next message ID
  inc client.messageId
  return client.messageId

proc start*(client: McpClient): Future[void] {.async.} =
  ## Starts the MCP server process
  if client.running:
    return
  
  try:
    var cmd = client.config.command
    var args = client.config.args
    
    # Set up environment
    var envTable: StringTableRef = nil
    if client.config.env.len > 0:
      envTable = newStringTable()
      for key, value in client.config.env:
        envTable[key] = value
    
    info "Starting MCP server: " & cmd & " " & args.join(" ")
    
    client.process = startProcess(
      cmd, 
      args = args,
      env = envTable,
      options = {poUsePath, poStdErrToStdOut}
    )
    
    client.input = client.process.inputStream
    client.output = client.process.outputStream
    client.running = true
    
    # Send initialization
    # await client.initialize()  # Will be implemented later
    
  except Exception as e:
    raise newException(McpClientError, "Failed to start MCP server: " & e.msg)

proc stop*(client: McpClient) =
  ## Stops the MCP server process
  if not client.running:
    return
  
  try:
    if client.input != nil:
      client.input.close()
    if client.output != nil:
      client.output.close()
    if client.process != nil:
      client.process.terminate()
      client.process.close()
  except:
    discard
  
  client.running = false

proc sendMessage*(client: McpClient, message: McpMessage): Future[void] {.async.} =
  ## Sends a message to the MCP server
  if not client.running:
    raise newException(McpClientError, "MCP client not running")
  
  try:
    let jsonStr = $(%message)
    client.input.writeLine(jsonStr)
    client.input.flush()
    debug "Sent MCP message: " & jsonStr
  except Exception as e:
    raise newException(McpClientError, "Failed to send message: " & e.msg)

proc readMessage*(client: McpClient): Future[McpMessage] {.async.} =
  ## Reads a message from the MCP server
  if not client.running:
    raise newException(McpClientError, "MCP client not running")
  
  try:
    let line = client.output.readLine()
    debug "Received MCP message: " & line
    
    let jsonNode = parseJson(line)
    
    result = McpMessage(
      jsonrpc: jsonNode["jsonrpc"].getStr(),
      id: if jsonNode.hasKey("id"): some(jsonNode["id"]) else: none(JsonNode),
      `method`: if jsonNode.hasKey("method"): some(jsonNode["method"].getStr()) else: none(string),
      params: if jsonNode.hasKey("params"): some(jsonNode["params"]) else: none(JsonNode),
      result: if jsonNode.hasKey("result"): some(jsonNode["result"]) else: none(JsonNode)
    )
    
    if jsonNode.hasKey("error"):
      let errorNode = jsonNode["error"]
      result.error = some(McpError(
        code: errorNode["code"].getInt(),
        message: errorNode["message"].getStr(),
        data: if errorNode.hasKey("data"): some(errorNode["data"]) else: none(JsonNode)
      ))
      
  except Exception as e:
    raise newException(McpClientError, "Failed to read message: " & e.msg)

proc initialize*(client: McpClient): Future[void] {.async.} =
  ## Initializes the MCP connection
  let initMessage = newMcpMessage(
    id = %client.nextMessageId(),
    `method` = "initialize",
    params = %*{
      "protocolVersion": MCP_VERSION,
      "capabilities": {},
      "clientInfo": {
        "name": "nim-testkit",
        "version": "1.0.0"
      }
    }
  )
  
  await client.sendMessage(initMessage)
  let response = await client.readMessage()
  
  if response.error.isSome:
    raise newException(McpClientError, "Initialization failed: " & response.error.get.message)
  
  # Send initialized notification
  let initializedMessage = newMcpMessage(
    `method` = "notifications/initialized"
  )
  
  await client.sendMessage(initializedMessage)

proc callTool*(client: McpClient, name: string, arguments: JsonNode): Future[McpToolResult] {.async.} =
  ## Calls a tool on the MCP server
  let message = newMcpMessage(
    id = %client.nextMessageId(),
    `method` = "tools/call",
    params = %*{
      "name": name,
      "arguments": arguments
    }
  )
  
  await client.sendMessage(message)
  let response = await client.readMessage()
  
  if response.error.isSome:
    return McpToolResult(
      isError: true,
      content: @[McpContent(
        `type`: "text",
        text: some(response.error.get.message)
      )]
    )
  
  if response.result.isSome:
    let resultNode = response.result.get
    var content: seq[McpContent] = @[]
    
    if resultNode.hasKey("content"):
      for item in resultNode["content"]:
        content.add(McpContent(
          `type`: item["type"].getStr(),
          text: if item.hasKey("text"): some(item["text"].getStr()) else: none(string),
          data: if item.hasKey("data"): some(item["data"].getStr()) else: none(string),
          mimeType: if item.hasKey("mimeType"): some(item["mimeType"].getStr()) else: none(string)
        ))
    
    return McpToolResult(
      isError: false,
      content: content
    )
  
  return McpToolResult(
    isError: true,
    content: @[McpContent(
      `type`: "text",
      text: some("No result returned")
    )]
  )

proc listTools*(client: McpClient): Future[seq[JsonNode]] {.async.} =
  ## Lists available tools from the MCP server
  let message = newMcpMessage(
    id = %client.nextMessageId(),
    `method` = "tools/list"
  )
  
  await client.sendMessage(message)
  let response = await client.readMessage()
  
  if response.error.isSome:
    raise newException(McpClientError, "Failed to list tools: " & response.error.get.message)
  
  if response.result.isSome and response.result.get.hasKey("tools"):
    for tool in response.result.get["tools"]:
      result.add(tool)

proc getResources*(client: McpClient): Future[seq[McpResource]] {.async.} =
  ## Gets available resources from the MCP server
  let message = newMcpMessage(
    id = %client.nextMessageId(),
    `method` = "resources/list"
  )
  
  await client.sendMessage(message)
  let response = await client.readMessage()
  
  if response.error.isSome:
    raise newException(McpClientError, "Failed to get resources: " & response.error.get.message)
  
  if response.result.isSome and response.result.get.hasKey("resources"):
    for resource in response.result.get["resources"]:
      result.add(McpResource(
        uri: resource["uri"].getStr(),
        name: resource["name"].getStr(),
        description: if resource.hasKey("description"): some(resource["description"].getStr()) else: none(string),
        mimeType: if resource.hasKey("mimeType"): some(resource["mimeType"].getStr()) else: none(string)
      ))

proc readResource*(client: McpClient, uri: string): Future[JsonNode] {.async.} =
  ## Reads a resource from the MCP server
  let message = newMcpMessage(
    id = %client.nextMessageId(),
    `method` = "resources/read",
    params = %*{
      "uri": uri
    }
  )
  
  await client.sendMessage(message)
  let response = await client.readMessage()
  
  if response.error.isSome:
    raise newException(McpClientError, "Failed to read resource: " & response.error.get.message)
  
  if response.result.isSome:
    return response.result.get
  
  return %*{}