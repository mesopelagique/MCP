//%attributes = {}

// Test MCP server configuration loading from well-known files
// This test discovers servers from Claude Desktop and VSCode configs

// ==============================================================================
// Test 1: Load and list all discovered servers
// ==============================================================================

cs:C1710.MCPServerRegistry.me.reload()

var $serverNames : Collection:=cs:C1710.MCPServerRegistry.me.listServers()
var $serverCount : Integer:=cs:C1710.MCPServerRegistry.me.count()

// ==============================================================================
// Test 2: Show server details by source
// ==============================================================================

var $claudeServers : Collection:=cs:C1710.MCPServerRegistry.me.getServersBySource("claude")
var $vscodeServers : Collection:=cs:C1710.MCPServerRegistry.me.getServersBySource("vscode")

// Log server info
var $config : cs:C1710.MCPServerConfig
For each ($config; cs:C1710.MCPServerRegistry.me.getAllConfigs())
	// Each config has: name, type, command, args, env, url, headers, source
	// Access via: $config.name, $config.type, $config.command, etc.
End for each 

// ==============================================================================
// Test 3: Check for load errors
// ==============================================================================

var $errors : Collection:=cs:C1710.MCPServerRegistry.me.getLoadErrors()
// $errors contains any parsing errors from config files

// ==============================================================================
// Test 4: Test lazy launch with TransportStdIO
// ==============================================================================

If ($serverCount>0)
	// Get first server config
	var $firstServerName : Text:=$serverNames[0]
	var $firstConfig : cs:C1710.MCPServerConfig:=cs:C1710.MCPServerRegistry.me.getServerConfig($firstServerName)
	
	If ($firstConfig.type="stdio") | ($firstConfig.type="")
		// Create transport without launching
		var $transport : cs:C1710.Transport:=$firstConfig.createTransport()
		
		// Check lazy launch: process should NOT be running yet
		If (OB Instance of:C1731($transport; cs:C1710.TransportStdIO))
			var $stdioTransport : cs:C1710.TransportStdIO:=$transport
			ASSERT:C1129(Not:C34($stdioTransport.isLaunched); "Transport should not be launched yet")
		End if 
		
		// Create client (still not launched)
		var $client : cs:C1710.Client:=cs:C1710.Client.new($transport)
		
		// First call will launch the process
		// var $init := $client.initialize()  // Uncomment to actually connect
		
		// Clean up without connecting
		$transport.close()
	End if 
End if 

// ==============================================================================
// Test 5: Manual server registration
// ==============================================================================

cs:C1710.MCPServerRegistry.me.registerServerFromObject("my-custom-server"; New object:C1471(\
"type"; "stdio"; \
"command"; "npx"; \
"args"; New collection:C1472("-y"; "@modelcontextprotocol/server-filesystem"); \
"env"; New object:C1471))

ASSERT:C1129(cs:C1710.MCPServerRegistry.me.hasServer("my-custom-server"); "Custom server should be registered")

// Clean up custom server
cs:C1710.MCPServerRegistry.me.unregisterServer("my-custom-server")

// ==============================================================================
// Test 6: Connect to a real server (optional - uncomment to test)
// ==============================================================================

If (cs:C1710.MCPServerRegistry.me.hasServer("github"))
	
	$config:=cs:C1710.MCPServerRegistry.me.getServerConfig("github")
	var $token:=""
	$config.addHeader("Authorization"; "Bearer "+$token)
	
	var $githubClient : cs:C1710.Client:=cs:C1710.MCPServerRegistry.me.getClient("github")
	
	If ($githubClient#Null:C1517)
		var $initResult:=$githubClient.initialize()
		
		If ($initResult.success)
			var $toolsResult:=$githubClient.listTools()
			// Use tools...
		End if 
		
		// Clean up
		cs:C1710.MCPServerRegistry.me.closeClient("github")
	End if 
End if 

// Clean up all clients
cs:C1710.MCPServerRegistry.me.closeAllClients()
