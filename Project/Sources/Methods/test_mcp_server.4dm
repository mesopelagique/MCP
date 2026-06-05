//%attributes = {}
// Exercises the MCP *server* dispatcher directly (no network), the mirror of
// the client tests. Registers a demo endpoint, builds a transient cs.MCPServer
// from its Storage descriptor, and drives the JSON-RPC methods by hand.

// --- Register the demo endpoint and load its (shared) descriptor ---
cs:C1710._MCPDemoHandler.me.register("/mcp/demo"; {\
name: "demo"; \
version: "1.0"; \
toolsClass: "_DemoTools"; \
tools: [\
{name: "echo"; description: "Echo back the provided text"; inputSchema: {type: "object"}}; \
{name: "add"; description: "Add two numbers"; inputSchema: {type: "object"}}\
]\
})

var $descriptor : Object:=Storage:C1525.mcpServers["/mcp/demo"]
var $server:=cs:C1710.Server.new($descriptor)

var $resp : Object

// --- initialize ---
$resp:=JSON Parse:C1218($server.handleMessage(JSON Stringify:C1217({jsonrpc: "2.0"; id: 1; method: "initialize"; params: {}})))
ASSERT:C1129($resp.result.serverInfo.name="demo"; "initialize should report server name")
ASSERT:C1129($resp.result.capabilities.tools#Null:C1517; "initialize should advertise tools capability")

// --- tools/list ---
$resp:=JSON Parse:C1218($server.handleMessage(JSON Stringify:C1217({jsonrpc: "2.0"; id: 2; method: "tools/list"; params: {}})))
ASSERT:C1129($resp.result.tools.length=2; "tools/list should return 2 tools")

// --- tools/call echo (Text return -> wrapped content) ---
$resp:=JSON Parse:C1218($server.handleMessage(JSON Stringify:C1217({jsonrpc: "2.0"; id: 3; method: "tools/call"; params: {name: "echo"; arguments: {text: "hello"}}})))
ASSERT:C1129($resp.result.content[0].text="hello"; "echo should return the input text")

// --- tools/call add (object return -> passthrough) ---
$resp:=JSON Parse:C1218($server.handleMessage(JSON Stringify:C1217({jsonrpc: "2.0"; id: 4; method: "tools/call"; params: {name: "add"; arguments: {a: 2; b: 3}}})))
ASSERT:C1129($resp.result.content[0].text="5"; "add should return the sum")

// --- tools/call unknown tool -> INVALID_PARAMS error ---
$resp:=JSON Parse:C1218($server.handleMessage(JSON Stringify:C1217({jsonrpc: "2.0"; id: 5; method: "tools/call"; params: {name: "nope"; arguments: {}}})))
ASSERT:C1129($resp.error.code=cs:C1710.JSONRPC.Init.me.INVALID_PARAMS; "unknown tool should be INVALID_PARAMS")

// --- unknown method -> METHOD_NOT_FOUND error ---
$resp:=JSON Parse:C1218($server.handleMessage(JSON Stringify:C1217({jsonrpc: "2.0"; id: 6; method: "foo/bar"; params: {}})))
ASSERT:C1129($resp.error.code=cs:C1710.JSONRPC.Init.me.METHOD_NOT_FOUND; "unknown method should be METHOD_NOT_FOUND")

// --- notification -> no reply ---
ASSERT:C1129($server.handleMessage(JSON Stringify:C1217({jsonrpc: "2.0"; method: "notifications/initialized"}))=""; "notification should produce no reply")

// --- batch (request + notification) -> single-element array reply ---
var $batch : Collection:=[{jsonrpc: "2.0"; id: 7; method: "ping"; params: {}}; {jsonrpc: "2.0"; method: "notifications/initialized"}]
var $respC:=JSON Parse:C1218($server.handleMessage(JSON Stringify:C1217($batch)))
ASSERT:C1129(Value type:C1509($respC)=Is collection:K8:32; "batch reply should be a collection")
ASSERT:C1129($respC.length=1; "batch reply should drop the notification")

// --- cleanup ---
cs:C1710._MCPDemoHandler.me.unregister("/mcp/demo")
