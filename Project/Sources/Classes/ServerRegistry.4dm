// ServerRegistry
// Singleton registry for discovered MCP servers with lazy client creation
// Loads configs from Claude Desktop and VSCode, creates clients on demand

property _servers : Object
property _clients : Object
property _lastLoadErrors : Collection

singleton Class constructor
	This:C1470._servers:=New object:C1471
	This:C1470._clients:=New object:C1471
	This:C1470._lastLoadErrors:=New collection:C1472

// ==============================================================================
// Discovery
// ==============================================================================

// Reload all configurations from well-known files
Function reload()
	var $result : Object:=cs:C1710.ConfigLoader.me.loadAll()

	This:C1470._servers:=New object:C1471
	This:C1470._lastLoadErrors:=$result.errors

	var $config : cs:C1710.ServerConfig
	For each ($config; $result.servers)
		This:C1470._servers[$config.name]:=$config
	End for each

// Get list of all discovered server names
Function listServers() : Collection
	var $names : Collection:=New collection:C1472
	var $name : Text
	For each ($name; This:C1470._servers)
		$names.push($name)
	End for each
	return $names.sort()

// Get configuration for a specific server
Function getServerConfig($name : Text) : cs:C1710.ServerConfig
	return This:C1470._servers[$name]

// Get all server configurations
Function getAllConfigs() : Collection
	var $configs : Collection:=New collection:C1472
	var $name : Text
	For each ($name; This:C1470._servers)
		$configs.push(This:C1470._servers[$name])
	End for each
	return $configs

// Get servers filtered by source (claude, vscode, vscode-workspace, custom)
Function getServersBySource($source : Text) : Collection
	var $configs : Collection:=New collection:C1472
	var $name : Text
	var $config : cs:C1710.ServerConfig
	For each ($name; This:C1470._servers)
		$config:=This:C1470._servers[$name]
		If ($config.source=$source)
			$configs.push($config)
		End if
	End for each
	return $configs

// Check if a server exists
Function hasServer($name : Text) : Boolean
	return OB Is defined:C1231(This:C1470._servers; $name)

// Get any errors from last reload
Function getLoadErrors() : Collection
	return This:C1470._lastLoadErrors

// Get server count
Function count() : Integer
	var $count : Integer:=0
	var $name : Text
	For each ($name; This:C1470._servers)
		$count:=$count+1
	End for each
	return $count

// ==============================================================================
// Client Creation (Lazy)
// ==============================================================================

// Get or create a client for the named server
// Returns Null if server not found or creation fails
// Note: Client is cached - call closeClient() to release
Function getClient($name : Text; $clientInfo : Object) : cs:C1710.Client
	// Check if server exists
	If (Not:C34(This:C1470.hasServer($name)))
		return Null:C1517
	End if

	// Return cached client if available
	If (OB Is defined:C1231(This:C1470._clients; $name))
		return This:C1470._clients[$name]
	End if

	// Create new client
	var $config : cs:C1710.ServerConfig:=This:C1470._servers[$name]
	var $client : cs:C1710.Client:=$config.createClient($clientInfo)

	If ($client#Null:C1517)
		This:C1470._clients[$name]:=$client
	End if

	return $client

// Close a specific client connection
Function closeClient($name : Text)
	If (OB Is defined:C1231(This:C1470._clients; $name))
		var $client : cs:C1710.Client:=This:C1470._clients[$name]
		$client.close()
		OB REMOVE:C1226(This:C1470._clients; $name)
	End if

// Close all cached client connections
Function closeAllClients()
	var $name : Text
	For each ($name; This:C1470._clients)
		var $client : cs:C1710.Client:=This:C1470._clients[$name]
		$client.close()
	End for each
	This:C1470._clients:=New object:C1471

// ==============================================================================
// Manual Registration
// ==============================================================================

// Register a server configuration manually
Function registerServer($config : cs:C1710.ServerConfig)
	This:C1470._servers[$config.name]:=$config

// Register server from object
Function registerServerFromObject($name : Text; $configObj : Object)
	$configObj.name:=$name
	If ($configObj.source=Null:C1517)
		$configObj.source:="custom"
	End if
	This:C1470._servers[$name]:=cs:C1710.ServerConfig.new($configObj)

// Unregister a server
Function unregisterServer($name : Text)
	This:C1470.closeClient($name)  // Close client if cached
	OB REMOVE:C1226(This:C1470._servers; $name)

// Clear all servers
Function clear()
	This:C1470.closeAllClients()
	This:C1470._servers:=New object:C1471
	This:C1470._lastLoadErrors:=New collection:C1472
