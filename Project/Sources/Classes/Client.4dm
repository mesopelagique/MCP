property transport : cs:C1710.Transport
property _initialized : Boolean:=False:C215
property _clientInfo : Object
property _serverCapabilities : Object

Class constructor($transport : Variant; $clientInfo : Object)
	This:C1470.transport:=$transport
	This:C1470._clientInfo:=$clientInfo || {name: "4D-AIKit"; version: "1.0"}
	
	// ============================================================================
	// Initialization
	// ============================================================================
	
Function initialize($formula : 4D:C1709.Function) : cs:C1710.InitializeResult
	// Send initialize request
	// protocolVersion should be the latest version we support (server will negotiate down if needed)
	var $params : Object:={\
		protocolVersion: "2025-11-25"; \
		capabilities: {\
		sampling: {}; \
		roots: {listChanged: True:C214}\
		}; \
		clientInfo: This:C1470._clientInfo\
		}
	var $result : cs:C1710.InitializeResult:=This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("initialize"; $params); $formula)
	
	// Send initialized notification after successful init (sync mode only)
	If ($formula=Null:C1517) && ($result#Null:C1517) && ($result.success)
		This:C1470.transport.notify(cs:C1710.JSONRPC.Init.me.notification("notifications/initialized"; {}))
		This:C1470._initialized:=True:C214
		// Store server capabilities
		If ($result.rawResponse#Null:C1517) && ($result.rawResponse.result#Null:C1517)
			This:C1470._serverCapabilities:=$result.rawResponse.result.capabilities
		End if 
	End if 
	
	return $result
	
	// ============================================================================
	// Ping
	// ============================================================================
	
Function ping($formula : 4D:C1709.Function) : cs:C1710.Result
	// Send a ping request
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("ping"; {}); $formula)
	
	// ============================================================================
	// Tools
	// ============================================================================
	
Function listTools($formula : 4D:C1709.Function) : cs:C1710.ListToolsResult
	// Send a tools/list request
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("tools/list"; {}); $formula)
	
Function callTool($name : Text; $arguments : Object; $formula : 4D:C1709.Function) : cs:C1710.ToolCallResult
	// Send a tools/call request
	var $params : Object:={name: $name; arguments: $arguments || {}}
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("tools/call"; $params); $formula)
	
	// ============================================================================
	// Resources
	// ============================================================================
	
Function listResources($formula : 4D:C1709.Function) : cs:C1710.ListResourcesResult
	// Send a resources/list request
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("resources/list"; {}); $formula)
	
Function listResourceTemplates($formula : 4D:C1709.Function) : cs:C1710.ListResourceTemplatesResult
	// Send a resources/templates/list request
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("resources/templates/list"; {}); $formula)
	
Function readResource($uri : Text; $formula : 4D:C1709.Function) : cs:C1710.ReadResourceResult
	// Send a resources/read request
	var $params : Object:={uri: $uri}
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("resources/read"; $params); $formula)
	
Function subscribeResource($uri : Text; $formula : 4D:C1709.Function) : cs:C1710.Result
	// Send a resources/subscribe request
	var $params : Object:={uri: $uri}
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("resources/subscribe"; $params); $formula)
	
Function unsubscribeResource($uri : Text; $formula : 4D:C1709.Function) : cs:C1710.Result
	// Send a resources/unsubscribe request
	var $params : Object:={uri: $uri}
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("resources/unsubscribe"; $params); $formula)
	
	// ============================================================================
	// Prompts
	// ============================================================================
	
Function listPrompts($formula : 4D:C1709.Function) : cs:C1710.ListPromptsResult
	// Send a prompts/list request
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("prompts/list"; {}); $formula)
	
Function getPrompt($name : Text; $arguments : Object; $formula : 4D:C1709.Function) : cs:C1710.GetPromptResult
	// Send a prompts/get request
	var $params : Object:={name: $name; arguments: $arguments || {}}
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("prompts/get"; $params); $formula)
	
	// ============================================================================
	// Completion
	// ============================================================================
	
Function complete($ref : Object; $argument : Object; $formula : 4D:C1709.Function) : cs:C1710.Result
	// Send a completion/complete request
	var $params : Object:={ref: $ref; argument: $argument}
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("completion/complete"; $params); $formula)
	
	// ============================================================================
	// Logging
	// ============================================================================
	
Function setLoggingLevel($level : Text; $formula : 4D:C1709.Function) : cs:C1710.Result
	// Send a logging/setLevel request
	// level: "debug" | "info" | "notice" | "warning" | "error" | "critical" | "alert" | "emergency"
	var $params : Object:={level: $level}
	return This:C1470.transport.send(cs:C1710.JSONRPC.Init.me.request("logging/setLevel"; $params); $formula)
	
	// ============================================================================
	// Notifications (client to server)
	// ============================================================================
	
Function sendProgress($progressToken : Variant; $progress : Real; $total : Real)
	// Send a progress notification
	var $params : Object:={progressToken: $progressToken; progress: $progress}
	If ($total>0)
		$params.total:=$total
	End if 
	This:C1470.transport.notify(cs:C1710.JSONRPC.Init.me.notification("notifications/progress"; $params))
	
Function sendRootsListChanged()
	// Send a roots/list_changed notification
	This:C1470.transport.notify(cs:C1710.JSONRPC.Init.me.notification("notifications/roots/list_changed"; {}))
	
Function sendCancelled($requestId : Variant; $reason : Text)
	// Send a cancelled notification
	var $params : Object:={requestId: $requestId}
	If ($reason#"")
		$params.reason:=$reason
	End if 
	This:C1470.transport.notify(cs:C1710.JSONRPC.Init.me.notification("notifications/cancelled"; $params))
	
	// ============================================================================
	// Lifecycle
	// ============================================================================
	
Function close()
	This:C1470.transport.close()
	This:C1470._initialized:=False:C215
	