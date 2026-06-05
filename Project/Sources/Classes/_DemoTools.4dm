// Demo tool implementations for the MCP server.
//
// Each public function is an MCP tool: it is named exactly like the tool, takes
// the call arguments as an Object, and returns either plain Text or a full MCP
// tool-result object ({content: [...]; isError}). cs.MCPServer normalizes both.

Class constructor

	// Echo back the provided text. Returns Text -> wrapped automatically.
Function echo($args : Object) : Text
	return String:C10($args.text)

	// Add two numbers. Returns a full MCP content object to show the other shape.
Function add($args : Object) : Object
	var $sum : Real:=Num:C11($args.a)+Num:C11($args.b)
	return {content: [{type: "text"; text: String:C10($sum)}]}
