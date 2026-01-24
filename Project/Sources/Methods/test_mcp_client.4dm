//%attributes = {}

var $command : Text:="/opt/homebrew/bin/npx -y @modelcontextprotocol/server-github"
var $transport:=cs:C1710.TransportStdIO.new($command)
var $client:=cs:C1710.Client.new($transport)

var $init:=$client.initialize()  // get capabilities

If ($init.capabilities.tools#Null:C1517)
	// List tools
	var $tools : Collection:=$client.listTools().tools
	var $tool : cs:C1710.Tool
	For each ($tool; $tools)
		
	End for each 
	ASSERT:C1129($tools.length>0; "Should have tools")
	
	// Call a tool
	var $result : cs:C1710.ToolCallResult:=$client.callTool("search_repositories"; {query: "4d-go-mobile"; perPage: 3})
	ASSERT:C1129($result.success; "Tool call failed")
	
End if 

If ($init.capabilities.prompts#Null:C1517)
	// List prompts
	var $promps:=$client.listPrompts()
	
End if 

If ($init.capabilities.resources#Null:C1517)
	// List resources
	var $resources:=$client.listResources()
	
End if 
// Clean up
$transport.close()