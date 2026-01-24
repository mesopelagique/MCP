//%attributes = {}

// Test MCP Client with HTTP Transport - Async mode
//
// Usage:
//   Set $url and $token variables to test with your MCP HTTP server
//   Example for GitHub Copilot:
//     $url := "https://api.githubcopilot.com/mcp/"
//     $token := "your-oauth-token"

var $url : Text:="https://api.githubcopilot.com/mcp/"  // Set your MCP HTTP server URL
var $token : Text:=""  // Set your auth token if needed

// Skip test if URL not configured
If (Length:C16($url)=0)
	ALERT:C41("Set $url variable to test HTTP transport")
	return 
End if 

// Build options
var $options : Object:={}
If (Length:C16($token)>0)
	$options.headers:={Authorization: "Bearer "+$token}
End if 

// Create HTTP transport
var $transport:=cs:C1710.TransportHttp.new($url; $options)
var $client:=cs:C1710.Client.new($transport)

// Initialize first (sync, needed to get capabilities)
var $init:=$client.initialize()
If (Not:C34(Asserted:C1132($init.success; "Initialize failed: "+JSON Stringify:C1217($init.error))))
	$transport.close()
	return 
End if 

// MARK: - Async listTools (if supported)
If ($init.capabilities.tools#Null:C1517)
	cs:C1710._MCPTestSignal.me.init()
	
	CALL WORKER:C1389(Current method name:C684; Formula:C1597($client.listTools(Formula:C1597(cs:C1710._MCPTestSignal.me.trigger($1)))))
	
	cs:C1710._MCPTestSignal.me.wait(30000)  // 30 sec timeout for HTTP
	
	var $listResult : cs:C1710.ListToolsResult:=cs:C1710._MCPTestSignal.me.result
	If (Asserted:C1132($listResult#Null:C1517; "Async listTools result should not be null"))
		If (Asserted:C1132($listResult.success; "Async listTools failed: "+JSON Stringify:C1217($listResult.error)))
			ASSERT:C1129($listResult.tools#Null:C1517; "Should have tools collection")
		End if 
	End if 
	
	cs:C1710._MCPTestSignal.me.reset()
End if 

// MARK: - Async callTool (if tools available)
If ($init.capabilities.tools#Null:C1517)
	// First get tools to find one to call
	var $tools:=$client.listTools()
	If ($tools.success) && ($tools.tools.length>0)
		var $firstTool : cs:C1710.Tool:=$tools.tools[0]
		
		cs:C1710._MCPTestSignal.me.init()
		
		// Call first tool with empty arguments (may fail but tests the transport)
		CALL WORKER:C1389(Current method name:C684; Formula:C1597($client.callTool($firstTool.name; {}; Formula:C1597(cs:C1710._MCPTestSignal.me.trigger($1)))))
		
		cs:C1710._MCPTestSignal.me.wait(30000)  // 30 sec timeout for HTTP
		
		var $callResult : cs:C1710.ToolCallResult:=cs:C1710._MCPTestSignal.me.result
		If (Asserted:C1132($callResult#Null:C1517; "Async callTool result should not be null"))
			// Tool call might fail due to missing arguments, but transport should work
		End if 
		
		cs:C1710._MCPTestSignal.me.reset()
	End if 
End if 

// MARK: - Cleanup
$transport.close()
KILL WORKER:C1390(Current method name:C684)

ALERT:C41("HTTP async transport tests passed!")
