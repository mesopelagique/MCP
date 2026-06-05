// MCP HTTP request handler + endpoint registry.
//
// 4D requires HTTP request handler classes to be shared singletons, so this
// class is a stateless *router*: it owns no server state of its own. The MCP
// servers themselves live in Storage, keyed by URL path, so several different
// MCP servers can be exposed on different endpoints (e.g. /mcp/demo, /mcp/foo).
//
// Wiring (see HTTPHandlers.json): every POST/GET/DELETE under /mcp/ is routed
// to handle(), which looks up the descriptor for the request path and delegates
// to a transient cs.MCPServer.

shared singleton Class constructor
	
	// ============================================================================
	// Registration - publish a server descriptor into Storage for a given path.
	// Call this from On Startup (or whenever you add an endpoint at runtime).
	// $descriptor is a plain object; it is deep-copied as shared into Storage.
	// ============================================================================
	
Function register($path : Text; $descriptor : Object)
	Use (Storage:C1525)
		If (Storage:C1525.mcpServers=Null:C1517)
			Storage:C1525.mcpServers:=New shared object:C1526
		End if 
	End use 
	
	// Copy the descriptor as a shared object inside the mcpServers group
	var $shared : Object:=OB Copy:C1225($descriptor; ck shared:K85:29; Storage:C1525.mcpServers)
	
	Use (Storage:C1525.mcpServers)
		Storage:C1525.mcpServers[$path]:=$shared
	End use 
	
	// Remove an endpoint
Function unregister($path : Text)
	If (Storage:C1525.mcpServers=Null:C1517)
		return 
	End if 
	Use (Storage:C1525.mcpServers)
		OB REMOVE:C1226(Storage:C1525.mcpServers; $path)
	End use 
	
	// ============================================================================
	// HTTP request handler (declared in HTTPHandlers.json)
	// ============================================================================
	
Function handle($request : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $response : 4D:C1709.OutgoingMessage:=4D:C1709.OutgoingMessage.new()
	var $path : Text:=$request.url
	
	// Look up the server registered for this exact path
	var $descriptor : Object:=Null:C1517
	If (Storage:C1525.mcpServers#Null:C1517)
		$descriptor:=Storage:C1525.mcpServers[$path]
	End if 
	
	If ($descriptor=Null:C1517)
		$response.setStatus(404)
		$response.setBody("No MCP server registered at "+$path)
		return $response
	End if 
	
	Case of 
			// Session teardown - nothing stateful to clean up in the minimal server
		: ($request.verb="delete")
			$response.setStatus(200)
			return $response
			
			// GET opens an SSE stream in the Streamable HTTP transport. Not supported
			// here: this minimal server only does request/response over POST.
		: ($request.verb="get")
			$response.setStatus(405)
			$response.setBody("SSE streaming not supported by this endpoint")
			return $response
	End case 
	
	// POST: decode the JSON-RPC body, dispatch, reply as application/json
	var $server:=cs:C1710.Server.new($descriptor)
	var $reply : Text:=$server.handleMessage($request.getText())
	
	If ($reply="")  // notification(s) only -> 202 Accepted, no body
		$response.setStatus(202)
		return $response
	End if 
	
	$response.setBody($reply)  // setBody first, then override Content-Type
	$response.setHeader("Content-Type"; "application/json")
	$response.setStatus(200)
	return $response
	