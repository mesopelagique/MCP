//%attributes = {}
var $requireAuth:=Shift down:C543

// Configure the OAuth 2.1 server (signing secret + demo user store).
// Set a fixed secret in production; here one is generated if omitted.
If ($requireAuth)
	cs:C1710.OAuth.me.configure({\
		users: [\
		{username: "alice"; password: "wonderland"; sub: "user-alice"; scope: "mcp:tools"}\
		]\
		})
End if 


// Register the demo MCP endpoint.
// Add  requireAuth: True  to force bearer-token auth on /mcp/demo (the MCP
// client will then run the full OAuth discovery + login flow).
cs:C1710._MCPDemoHandler.me.register("/mcp/demo"; {\
name: "demo"; \
version: "1.0"; \
toolsClass: "_DemoTools"; \
requireAuth: $requireAuth; \
tools: [\
{\
name: "echo"; \
description: "Echo back the provided text"; \
inputSchema: {type: "object"; properties: {text: {type: "string"}}; required: ["text"]}\
}; \
{\
name: "add"; \
description: "Add two numbers and return the sum"; \
inputSchema: {type: "object"; properties: {a: {type: "number"}; b: {type: "number"}}; required: ["a"; "b"]}\
}\
]\
})
