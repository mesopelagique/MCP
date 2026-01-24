//%attributes = {}

var $command : Text:="/opt/homebrew/bin/npx -y @modelcontextprotocol/server-github"
var $transport:=cs:C1710.TransportStdIO.new($command)
var $client:=cs:C1710.Client.new($transport)

// MARK: - Async toolList
// Use CALL WORKER to avoid deadlock (callback routes to caller thread which would be blocked)
cs:C1710._MCPTestSignal.me.init()

CALL WORKER:C1389(Current method name:C684; Formula:C1597($client.listTools(Formula:C1597(cs:C1710._MCPTestSignal.me.trigger($1)))))

cs:C1710._MCPTestSignal.me.wait(10000)

var $listResult : cs:C1710.ListToolsResult:=cs:C1710._MCPTestSignal.me.result
If (Asserted:C1132($listResult#Null:C1517; "Result should not be null"))
	If (Asserted:C1132($listResult.success; "toolList failed"))
		ASSERT:C1129($listResult.tools.length>0; "Should have tools")
	End if 
End if 

cs:C1710._MCPTestSignal.me.reset()

// MARK: - Async toolCall
cs:C1710._MCPTestSignal.me.init()

CALL WORKER:C1389(Current method name:C684; Formula:C1597($client.callTool("search_repositories"; {query: "4d-go-mobile"; perPage: 3}; Formula:C1597(cs:C1710._MCPTestSignal.me.trigger($1)))))

cs:C1710._MCPTestSignal.me.wait(10000)

var $callResult : cs:C1710.ToolCallResult:=cs:C1710._MCPTestSignal.me.result
If (Asserted:C1132($callResult#Null:C1517; "Result should not be null"))
	If (Asserted:C1132($callResult.success; "toolCall failed"))
		ASSERT:C1129($callResult.content.length>0; "Should have content")
		var $data : Object:=$callResult.data()
		ASSERT:C1129($data#Null:C1517; "Should have parsed data")
	End if 
End if 

cs:C1710._MCPTestSignal.me.reset()

// MARK: - Cleanup
$transport.close()
KILL WORKER:C1390(Current method name:C684)
