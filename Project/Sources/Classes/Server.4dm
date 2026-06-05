// MCP Server - transport-agnostic JSON-RPC dispatcher.
//
// This object is *transient*: it is rebuilt on each request from a shareable
// descriptor stored in Storage (see cs.MCPHandler.register). It never lives in
// Storage itself, because a class instance cannot be placed in a shared object.
//
// The descriptor shape is:
//   {
//     name: Text; version: Text;       // serverInfo
//     toolsClass: Text;                // name of a cs.<class> implementing the tools
//     tools: [ {name; description; inputSchema} ]   // declared tool schemas
//   }
//
// Each declared tool maps to a function of the same name on the tools class.
// That function receives the call arguments (Object) and returns either:
//   - Text                                   -> wrapped as a text content block
//   - {content: [...]; isError: Boolean}     -> passed through unchanged
//   - any other value                        -> JSON-stringified into a text block

property info : Object
property tools : Variant  // Collection of tool definitions (may be shared)
property toolsClass : Text

Class constructor($descriptor : Object)
	This:C1470.info:={name: String:C10($descriptor.name); version: String:C10($descriptor.version)}
	This:C1470.tools:=$descriptor.tools || []
	This:C1470.toolsClass:=String:C10($descriptor.toolsClass)
	
	// ============================================================================
	// Entry point - decode a raw JSON-RPC payload and return the reply text.
	// Returns "" when nothing should be sent back (notification-only payloads).
	// ============================================================================
	
Function handleMessage($raw : Variant) : Text
	var $parsed : Object:=cs:C1710.JSONRPC.Init.me.parse($raw)
	
	// Whole payload was not valid JSON
	If ($parsed.type="invalid")
		var $err:=cs:C1710.JSONRPC.Init.me.error(\
			Null:C1517; \
			cs:C1710.JSONRPC.Init.me.PARSE_ERROR; \
			"Parse error: "+String:C10($parsed.error); \
			Null:C1517)
		return JSON Stringify:C1217($err)
	End if 
	
	// Batch: process each message, collect only the messages that need a reply
	If ($parsed.type="batch")
		var $replies : Collection:=[]
		var $item : Object
		For each ($item; $parsed.value)
			var $one : Object:=This:C1470._handleOne($item)
			If ($one#Null:C1517)
				$replies.push($one)
			End if 
		End for each 
		If ($replies.length=0)  // batch of notifications only
			return ""
		End if 
		return JSON Stringify:C1217($replies)
	End if 
	
	// Single message
	var $reply : Object:=This:C1470._handleOne($parsed)
	If ($reply=Null:C1517)  // notification
		return ""
	End if 
	return JSON Stringify:C1217($reply)
	
	// Handle one parsed message. Returns a Response/Error object, or Null when
	// no reply is expected (notifications).
Function _handleOne($parsed : Object) : Object
	Case of 
		: ($parsed.type="request")
			return This:C1470._dispatch($parsed.value)
		: ($parsed.type="notification")
			This:C1470._handleNotification($parsed.value)
			return Null:C1517
		: ($parsed.type="invalid")
			return cs:C1710.JSONRPC.Init.me.error(\
				Null:C1517; \
				cs:C1710.JSONRPC.Init.me.INVALID_REQUEST; \
				"Invalid request: "+String:C10($parsed.error); \
				Null:C1517)
		Else 
			// response/error coming *to* a server: ignore
			return Null:C1517
	End case 
	
	// ============================================================================
	// Method routing
	// ============================================================================
	
Function _dispatch($req : cs:C1710.JSONRPC.Request) : Object
	Case of 
		: ($req.method="initialize")
			return cs:C1710.JSONRPC.Init.me.response($req.id; {\
				protocolVersion: "2025-11-25"; \
				capabilities: {tools: {listChanged: False:C215}}; \
				serverInfo: This:C1470.info\
				})
			
		: ($req.method="ping")
			return cs:C1710.JSONRPC.Init.me.response($req.id; {})
			
		: ($req.method="tools/list")
			return cs:C1710.JSONRPC.Init.me.response($req.id; {tools: This:C1470.tools})
			
		: ($req.method="tools/call")
			return This:C1470._callTool($req)
			
		Else 
			return cs:C1710.JSONRPC.Init.me.error(\
				$req.id; \
				cs:C1710.JSONRPC.Init.me.METHOD_NOT_FOUND; \
				"Method not found: "+$req.method; \
				Null:C1517)
	End case 
	
	// ============================================================================
	// tools/call
	// ============================================================================
	
Function _callTool($req : cs:C1710.JSONRPC.Request) : Object
	var $name : Text:=String:C10($req.params.name)
	
	// The tool must be declared in this server's tool list
	If (Not:C34(This:C1470._isDeclared($name)))
		return cs:C1710.JSONRPC.Init.me.error(\
			$req.id; \
			cs:C1710.JSONRPC.Init.me.INVALID_PARAMS; \
			"Unknown tool: "+$name; \
			Null:C1517)
	End if 
	
	If (This:C1470.toolsClass="")
		return cs:C1710.JSONRPC.Init.me.error(\
			$req.id; \
			cs:C1710.JSONRPC.Init.me.INTERNAL_ERROR; \
			"No tools class bound to this server"; \
			Null:C1517)
	End if 
	
	// Resolve the backing class and the function named after the tool
	var $impl : Object:=cs:C1710[This:C1470.toolsClass].new()
	var $fn : 4D:C1709.Function:=$impl[$name]
	If ($fn=Null:C1517)
		return cs:C1710.JSONRPC.Init.me.error(\
			$req.id; \
			cs:C1710.JSONRPC.Init.me.METHOD_NOT_FOUND; \
			"Tool not implemented: "+$name; \
			Null:C1517)
	End if 
	
	var $args : Object:=$req.params.arguments || {}
	var $content : Object
	Try
		var $out : Variant:=$fn.call($impl; $args)
		$content:=This:C1470._toContent($out)
	Catch
		$content:={content: [{type: "text"; text: "Tool execution error"}]; isError: True:C214}
	End try
	
	return cs:C1710.JSONRPC.Init.me.response($req.id; $content)
	
	// Is a tool name present in the declared tool list?
Function _isDeclared($name : Text) : Boolean
	var $def : Object
	For each ($def; This:C1470.tools)
		If ($def.name=$name)
			return True:C214
		End if 
	End for each 
	return False:C215
	
	// Normalize a tool function result into an MCP tool-result object
Function _toContent($out : Variant) : Object
	Case of 
		: (Value type:C1509($out)=Is object:K8:27) && (OB Is defined:C1231($out; "content"))
			return $out
		: (Value type:C1509($out)=Is text:K8:3)
			return {content: [{type: "text"; text: $out}]}
		: (Value type:C1509($out)=Is object:K8:27) | (Value type:C1509($out)=Is collection:K8:32)
			return {content: [{type: "text"; text: JSON Stringify:C1217($out)}]}
		Else 
			return {content: [{type: "text"; text: String:C10($out)}]}
	End case 
	
	// Notifications (e.g. notifications/initialized). No reply is sent.
	// Override / extend as needed for progress, cancellation, etc.
Function _handleNotification($notification : cs:C1710.JSONRPC.Notification)
	// no-op in the minimal server
	