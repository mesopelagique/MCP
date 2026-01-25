# MCP

A 4D implementation of the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) client library.

MCP is a standardized protocol that enables applications to communicate with AI models and specialized backend services through a structured JSON-RPC based interface.

## Features

- Connect to MCP servers (local and remote)
- Invoke tools and access resources from MCP-compatible services
- Auto-discover servers configured in Claude Desktop and VSCode
- Multiple transport mechanisms: StdIO and HTTP/SSE
- Synchronous (and asynchronous) operation modes

## Dependencies

This component requires:

- [StdIO](https://github.com/mesopelagique/StdIO) - For stdio-based process communication
- [JSONRPC](https://github.com/mesopelagique/JSONRPC) - JSON-RPC protocol implementation

## Usage

### Basic Example

```4d
// Create a transport for a local MCP server
var $transport:=cs.TransportStdIO.new("/opt/homebrew/bin/npx"; "-y"; "@modelcontextprotocol/server-github")

// Create client
var $client:=cs.Client.new($transport)

// Initialize connection
var $init : cs.InitializeResult:=$client.initialize()

If ($init.success)
    // List available tools
    var $tools : cs.ListToolsResult:=$client.listTools()

    // Call a tool
    var $result : cs.ToolCallResult:=$client.callTool("search_repositories"; {query: "4d language"})

    // Get text result
    var $text : Text:=$result.text()
End if

// Cleanup
$transport.close()
```

### Using the Server Registry

The registry auto-discovers MCP servers from Claude Desktop and VSCode configurations:

```4d
// Load all discovered servers
cs.ServerRegistry.me.reload()

// List available servers
var $servers : Collection:=cs.ServerRegistry.me.listServers()

// Get a client for a specific server
var $client : cs.Client:=cs.ServerRegistry.me.getClient("github")

// Use the client...
var $tools : cs.ListToolsResult:=$client.listTools()

// Close when done
cs.ServerRegistry.me.closeClient("github")
```

### Manual Server Configuration

```4d
// Create a stdio server config
var $config:=cs.ServerConfig.new("my-server"; "stdio")
$config.command:="/usr/local/bin/my-mcp-server"
$config.args:=["--option"; "value"]
$config.env:={API_KEY: "secret"}

// Create client from config
var $client:=$config.createClient()
```

### HTTP Transport

```4d
// Create HTTP transport for remote server
var $transport:=cs.TransportHttp.new("https://mcp.example.com/xxx")

// Create client
var $client:=cs.Client.new($transport)

// Initialize and use...
$client.initialize()
```

### Async Mode

> WORK IN PROGRESS

```4d
// Define callback
var $callback:=Formula(handleResult($1))

// Call asynchronously
$client.listTools($callback)
```

## API Reference

### Client

The main class for interacting with MCP servers.

| Method | Description |
|--------|-------------|
| `initialize()` | Negotiate protocol version and capabilities |
| `listTools()` | Get available tools |
| `callTool(name; arguments)` | Execute a tool |
| `listResources()` | Get available resources |
| `readResource(uri)` | Read a resource |
| `listPrompts()` | Get available prompts |
| `getPrompt(name; arguments)` | Get a prompt |
| `ping()` | Check server connectivity |
| `close()` | Close the connection |

### Transports

| Class | Description |
|-------|-------------|
| `TransportStdIO` | Local process communication via stdin/stdout |
| `TransportHttp` | Remote server communication via HTTP/SSE |

### Configuration

| Class | Description |
|-------|-------------|
| `ConfigLoader` | Loads server configs from Claude/VSCode |
| `ServerConfig` | Represents a server configuration |
| `ServerRegistry` | Registry for discovered servers |

## Configuration Files

The library discovers MCP servers from these locations:

- **Claude Desktop**: `~/Library/Application Support/Claude/claude_desktop_config.json`
- **VSCode User**: `~/Library/Application Support/Code/User/settings.json`
- **VSCode Workspace**: `.vscode/settings.json`
- **VSCode MCP**: `.vscode/mcp.json`

Example `.vscode/mcp.json`:

```json
{
  "servers": {
    "github": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-github"],
      "env": {
        "GITHUB_PERSONAL_ACCESS_TOKEN": "your-token"
      }
    }
  }
}
```

## License

MIT
