import unittest
import ../src/mcp/jujutsu

suite "MCP Jujutsu Tests":
  test "Check if MCP Jujutsu is available":
    # This should return false by default in tests unless compiled with -d:useMcpJujutsu
    let available = isMcpJujutsuAvailable()
    when defined(useMcpJujutsu):
      check available == true
    else:
      check available == false
      
  test "Create MCP client":
    let client = newMcpClient()
    check client != nil
    check client.baseUrl == "http://localhost:8080/mcp"