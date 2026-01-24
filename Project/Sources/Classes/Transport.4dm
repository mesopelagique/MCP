
Class constructor
	
Function send($message : cs:C1710.JSONRPC.Request; $formula : 4D:C1709.Function) : cs:C1710.Result
	ASSERT:C1129(False:C215; "must be overriden")
	
	var $result:=cs:C1710.Result.new()
	$result.success:=False:C215
	If ($formula=Null:C1517)
		return $result
	Else 
		$formula.call(This:C1470; $result)
	End if 
	
	// Send a notification (no response expected)
Function notify($notification : cs:C1710.JSONRPC.Notification)
	ASSERT:C1129(False:C215; "must be overriden")
	
Function close()
	
	
Function _processResponse($method : Text; $response : Object) : cs:C1710.Result
	// Parse the JSON-RPC response
	var $message : Object:=cs:C1710.JSONRPC.Init.me.parse($response)
	
	// Handle JSON-RPC level error
	If ($message.type="error")
		var $errorResult : cs:C1710.Result:=cs:C1710.Result.new()
		$errorResult.success:=False:C215
		$errorResult.error:=$message.value.error  // JSONRPCErrorData
		return $errorResult
	End if 
	
	// Handle invalid messages
	If ($message.type="invalid")
		var $invalidResult : cs:C1710.Result:=cs:C1710.Result.new()
		$invalidResult.success:=False:C215
		$invalidResult.error:=cs:C1710.JSONRPC.Init.me.errorData(\
			cs:C1710.JSONRPC.Init.me.PARSE_ERROR; \
			$message.error; \
			Null:C1517)
		return $invalidResult
	End if 
	
	// Get the result from the parsed response
	var $rpcResponse : cs:C1710.JSONRPC.Response:=$message.value
	var $result : Object:=$rpcResponse.result
	
	Case of 
		: ($method="initialize")
			// Initialize response - just return success with raw response
			var $initResult:=cs:C1710.InitializeResult.new()
			If ($result#Null:C1517)
				$initResult.capabilities:=$result.capabilities
				If (Value type:C1509($result.protocolVersion)=Is date:K8:7)
					$initResult.protocolVersion:=String:C10($result.protocolVersion; "yyyy-MM-dd")
				Else 
					$initResult.protocolVersion:=$result.protocolVersion
				End if 
				$initResult.serverInfo:=$result.serverInfo
			End if 
			$initResult.rawResponse:=$response
			return $initResult
			
		: ($method="ping")
			// Ping response - empty result
			var $pingResult : cs:C1710.Result:=cs:C1710.Result.new()
			return $pingResult
			
		: ($method="tools/list")
			var $listToolsResult:=cs:C1710.ListToolsResult.new()
			
			// Process tools from response
			If ($result#Null:C1517) && (Value type:C1509($result.tools)=Is collection:K8:32)
				var $tool : Object
				For each ($tool; $result.tools)
					var $mcp_tool : cs:C1710.Tool:=cs:C1710.Tool.new()
					$mcp_tool.name:=$tool.name
					$mcp_tool.description:=$tool.description
					var $inputSchema : Object:=$tool.inputSchema || $tool.input_schema
					If ($inputSchema#Null:C1517)
						$mcp_tool.inputSchema:=OB Copy:C1225($inputSchema)
					End if 
					$listToolsResult.tools.push($mcp_tool)
				End for each 
			End if 
			
			return $listToolsResult
			
		: ($method="tools/call")
			var $callResult:=cs:C1710.ToolCallResult.new()
			
			If ($result#Null:C1517)
				// Copy content array
				If (Value type:C1509($result.content)=Is collection:K8:32)
					$callResult.content:=$result.content
				End if 
				// Check if tool returned an error (MCP-level, not JSON-RPC level)
				If ($result.isError=True:C214)
					$callResult.isError:=True:C214
					$callResult.success:=False:C215
				End if 
			End if 
			
			return $callResult
			
		: ($method="resources/list")
			var $listResourcesResult:=cs:C1710.ListResourcesResult.new()
			
			If ($result#Null:C1517) && (Value type:C1509($result.resources)=Is collection:K8:32)
				$listResourcesResult.resources:=$result.resources
			End if 
			
			return $listResourcesResult
			
		: ($method="resources/templates/list")
			var $listTemplatesResult:=cs:C1710.ListResourceTemplatesResult.new()
			
			If ($result#Null:C1517) && (Value type:C1509($result.resourceTemplates)=Is collection:K8:32)
				$listTemplatesResult.resourceTemplates:=$result.resourceTemplates
			End if 
			
			return $listTemplatesResult
			
		: ($method="resources/read")
			var $readResult:=cs:C1710.ReadResourceResult.new()
			
			If ($result#Null:C1517) && (Value type:C1509($result.contents)=Is collection:K8:32)
				$readResult.contents:=$result.contents
			End if 
			
			return $readResult
			
		: ($method="resources/subscribe") | ($method="resources/unsubscribe")
			// Empty result
			var $subResult:=cs:C1710.Result.new()
			return $subResult
			
		: ($method="prompts/list")
			var $listPromptsResult:=cs:C1710.ListPromptsResult.new()
			
			If ($result#Null:C1517) && (Value type:C1509($result.prompts)=Is collection:K8:32)
				$listPromptsResult.prompts:=$result.prompts
			End if 
			
			return $listPromptsResult
			
		: ($method="prompts/get")
			var $getPromptResult:=cs:C1710.GetPromptResult.new()
			
			If ($result#Null:C1517)
				$getPromptResult.description:=$result.description || ""
				If (Value type:C1509($result.messages)=Is collection:K8:32)
					$getPromptResult.messages:=$result.messages
				End if 
			End if 
			
			return $getPromptResult
			
		: ($method="completion/complete")
			// Completion result - return raw
			var $completeResult : cs:C1710.Result:=cs:C1710.Result.new()
			$completeResult.rawResponse:=$response
			return $completeResult
			
		: ($method="logging/setLevel")
			// Empty result
			var $logResult : cs:C1710.Result:=cs:C1710.Result.new()
			return $logResult
			
		Else 
			// Generic result for other methods
			var $genericResult : cs:C1710.Result:=cs:C1710.Result.new()
			$genericResult.rawResponse:=$response
			return $genericResult
	End case 
	