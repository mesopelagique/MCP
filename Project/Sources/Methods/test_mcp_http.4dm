//%attributes = {}

// Test MCP Client with HTTP Transport
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

// Test 1: Initialize
var $init:=$client.initialize()
If (Not:C34(Asserted:C1132($init.success; "Initialize failed: "+JSON Stringify:C1217($init.error))))
	$transport.close()
	return 
End if 

ASSERT:C1129(Length:C16($init.protocolVersion)>0; "Should have protocol version")

// Check if session ID was received
If (Length:C16($transport.sessionId)>0)
	// Session ID tracking working
End if 

// Test 2: List Tools (if supported)
If ($init.capabilities.tools#Null:C1517)
	var $tools:=$client.listTools()
	If (Asserted:C1132($tools.success; "ListTools failed: "+JSON Stringify:C1217($tools.error)))
		ASSERT:C1129($tools.tools#Null:C1517; "Should have tools collection")
		var $tool : cs:C1710.Tool
		For each ($tool; $tools.tools)
			ASSERT:C1129(Length:C16($tool.name)>0; "Tool should have name")
		End for each 
	End if 
End if 

// Test 3: List Prompts (if supported)
If ($init.capabilities.prompts#Null:C1517)
	var $prompts:=$client.listPrompts()
	If (Asserted:C1132($prompts.success; "ListPrompts failed: "+JSON Stringify:C1217($prompts.error)))
		ASSERT:C1129($prompts.prompts#Null:C1517; "Should have prompts collection")
	End if 
End if 

// Test 4: List Resources (if supported)
If ($init.capabilities.resources#Null:C1517)
	var $resources:=$client.listResources()
	If (Asserted:C1132($resources.success; "ListResources failed: "+JSON Stringify:C1217($resources.error)))
		ASSERT:C1129($resources.resources#Null:C1517; "Should have resources collection")
	End if 
End if 

// Clean up
$transport.close()

ALERT:C41("HTTP transport tests passed!")
