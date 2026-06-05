//%attributes = {}
cs:C1710._MCPDemoHandler.me.register("/mcp/demo"; {\
name: "demo"; \
version: "1.0"; \
toolsClass: "_DemoTools"; \
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
