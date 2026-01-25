// MCPConfigLoader
// Singleton that loads MCP server configurations from well-known config files
// Supports: Claude Desktop, VSCode User Settings, VSCode Workspace Settings, VSCode mcp.json

singleton Class constructor
	
	// ==============================================================================
	// Public Methods
	// ==============================================================================
	
	// Load all configurations from all known sources
	// Returns: Object with { servers: Collection of MCPServerConfig, errors: Collection }
Function loadAll() : Object
	var $result : Object:=New object:C1471("servers"; New collection:C1472; "errors"; New collection:C1472)
	
	// Load from Claude Desktop
	var $claudeResult : Object:=This:C1470.loadClaudeConfig()
	$result.servers:=$result.servers.combine($claudeResult.servers)
	If ($claudeResult.error#Null:C1517)
		$result.errors.push($claudeResult.error)
	End if 
	
	// Load from VSCode user settings
	var $vscodeResult : Object:=This:C1470.loadVSCodeConfig()
	$result.servers:=$result.servers.combine($vscodeResult.servers)
	If ($vscodeResult.error#Null:C1517)
		$result.errors.push($vscodeResult.error)
	End if 
	
	// Load from workspace .vscode/settings.json
	var $workspaceResult : Object:=This:C1470.loadVSCodeWorkspaceConfig()
	$result.servers:=$result.servers.combine($workspaceResult.servers)
	If ($workspaceResult.error#Null:C1517)
		$result.errors.push($workspaceResult.error)
	End if

	// Load from workspace .vscode/mcp.json
	var $mcpJsonResult : Object:=This:C1470.loadVSCodeMcpJson()
	$result.servers:=$result.servers.combine($mcpJsonResult.servers)
	If ($mcpJsonResult.error#Null:C1517)
		$result.errors.push($mcpJsonResult.error)
	End if

	return $result
	
	// Load only Claude Desktop configuration
	// ~/Library/Application Support/Claude/claude_desktop_config.json
Function loadClaudeConfig() : Object
	var $result : Object:=New object:C1471("servers"; New collection:C1472; "error"; Null:C1517)
	var $configPath:=This:C1470._getClaudeConfigPath()
	
	If (Not:C34($configPath.exists))
		return $result  // No config file, not an error
	End if 
	
	var $jsonText : Text:=($configPath.exists) ? $configPath.getText() : ""
	If (Length:C16($jsonText)=0)
		return $result
	End if 
	
	var $config : Object:=JSON Parse:C1218($jsonText; Is object:K8:27)
	If ($config=Null:C1517)
		$result.error:=New object:C1471("source"; "claude"; "message"; "Failed to parse JSON"; "path"; $configPath)
		return $result
	End if 
	
	// Parse mcpServers object: {"mcpServers": {"name": {config...}}}
	var $mcpServers : Object:=$config.mcpServers
	If ($mcpServers#Null:C1517)
		var $serverName : Text
		For each ($serverName; $mcpServers)
			var $serverConfig : Object:=OB Copy:C1225($mcpServers[$serverName])
			$serverConfig.name:=$serverName
			$serverConfig.source:="claude"
			$result.servers.push(cs:C1710.MCPServerConfig.new($serverConfig))
		End for each 
	End if 
	
	return $result
	
	// Load VSCode user settings configuration
	// ~/Library/Application Support/Code/User/settings.json
Function loadVSCodeConfig() : Object
	var $result : Object:=New object:C1471("servers"; New collection:C1472; "error"; Null:C1517)
	var $configPath:=This:C1470._getVSCodeUserSettingsPath()
	
	If (Not:C34($configPath.exists))
		return $result
	End if 
	
	return This:C1470._parseVSCodeSettings($configPath; "vscode")
	
	// Load VSCode workspace configuration
	// .vscode/settings.json relative to current database
Function loadVSCodeWorkspaceConfig() : Object
	var $result : Object:=New object:C1471("servers"; New collection:C1472; "error"; Null:C1517)
	
	// Get path relative to database folder
	var $dbFolder : 4D:C1709.Folder:=Folder:C1567(fk database folder:K87:14)
	var $vscodeFolder : 4D:C1709.Folder:=$dbFolder.folder(".vscode")
	
	If (Not:C34($vscodeFolder.exists))
		return $result
	End if 
	
	var $settingsFile : 4D:C1709.File:=$vscodeFolder.file("settings.json")
	If (Not:C34($settingsFile.exists))
		return $result
	End if 
	
	return This:C1470._parseVSCodeSettings($settingsFile; "vscode-workspace")

	// Load VSCode mcp.json configuration
	// .vscode/mcp.json relative to current database
	// Format: {"servers": {"name": {config...}}}
Function loadVSCodeMcpJson() : Object
	var $result : Object:=New object:C1471("servers"; New collection:C1472; "error"; Null:C1517)

	// Get path relative to database folder
	var $dbFolder : 4D:C1709.Folder:=Folder:C1567(fk database folder:K87:14)
	var $vscodeFolder : 4D:C1709.Folder:=$dbFolder.folder(".vscode")

	If (Not:C34($vscodeFolder.exists))
		return $result
	End if

	var $mcpFile : 4D:C1709.File:=$vscodeFolder.file("mcp.json")
	If (Not:C34($mcpFile.exists))
		return $result
	End if

	return This:C1470._parseMcpJson($mcpFile; "vscode-mcp")

	// ==============================================================================
	// Private Methods
	// ==============================================================================
	
Function _getClaudeConfigPath() : 4D:C1709.File
	// ~/Library/Application Support/Claude/claude_desktop_config.json
	return Folder:C1567(fk home folder:K87:24).file("Library/Application Support/Claude/claude_desktop_config.json")
	
Function _getVSCodeUserSettingsPath() : 4D:C1709.File
	// ~/Library/Application Support/Code/User/settings.json
	return Folder:C1567(fk home folder:K87:24).file("Library/Application Support/Code/User/settings.json")

	// Parse mcp.json format: {"servers": {"name": {config...}}}
Function _parseMcpJson($path : 4D:C1709.File; $source : Text) : Object
	var $result : Object:=New object:C1471("servers"; New collection:C1472; "error"; Null:C1517)

	var $jsonText : Text:=($path.exists) ? $path.getText() : ""
	If (Length:C16($jsonText)=0)
		return $result
	End if

	// Strip JSONC comments before parsing
	$jsonText:=This:C1470._stripJSONComments($jsonText)

	var $config : Object:=JSON Parse:C1218($jsonText; Is object:K8:27)
	If ($config=Null:C1517)
		$result.error:=New object:C1471("source"; $source; "message"; "Failed to parse JSON"; "path"; $path)
		return $result
	End if

	// mcp.json structure: {"servers": {"name": {config...}}}
	var $servers : Object:=$config.servers
	If ($servers=Null:C1517)
		return $result  // No servers, not an error
	End if

	var $serverName : Text
	For each ($serverName; $servers)
		var $serverConfig : Object:=OB Copy:C1225($servers[$serverName])
		$serverConfig.name:=$serverName
		$serverConfig.source:=$source
		$result.servers.push(cs:C1710.MCPServerConfig.new($serverConfig))
	End for each

	return $result

	// Parse VSCode settings.json (JSONC format with comments)
Function _parseVSCodeSettings($path : 4D:C1709.File; $source : Text) : Object
	var $result : Object:=New object:C1471("servers"; New collection:C1472; "error"; Null:C1517)
	
	var $jsonText : Text:=($path.exists) ? $path.getText() : ""
	If (Length:C16($jsonText)=0)
		return $result
	End if 
	
	// Strip JSONC comments before parsing
	$jsonText:=This:C1470._stripJSONComments($jsonText)
	
	var $config : Object:=JSON Parse:C1218($jsonText; Is object:K8:27)
	If ($config=Null:C1517)
		$result.error:=New object:C1471("source"; $source; "message"; "Failed to parse JSON"; "path"; $path)
		return $result
	End if 
	
	// VSCode structure: {"mcp": {"servers": {"name": {config...}}}}
	var $mcpConfig : Object:=$config.mcp
	If ($mcpConfig=Null:C1517)
		return $result  // No MCP config, not an error
	End if 
	
	var $servers : Object:=$mcpConfig.servers
	If ($servers=Null:C1517)
		return $result
	End if 
	
	var $serverName : Text
	For each ($serverName; $servers)
		var $serverConfig : Object:=OB Copy:C1225($servers[$serverName])
		$serverConfig.name:=$serverName
		$serverConfig.source:=$source
		$result.servers.push(cs:C1710.MCPServerConfig.new($serverConfig))
	End for each 
	
	return $result
	
	// Strip // comments from JSONC text
Function _stripJSONComments($jsonc : Text) : Text
	var $lines : Collection:=Split string:C1554($jsonc; "\n")
	var $cleanLines : Collection:=New collection:C1472
	var $line : Text
	var $trimmed : Text
	
	For each ($line; $lines)
		$trimmed:=This:C1470._trim($line)
		
		// Skip lines that are pure comments (start with //)
		If ($trimmed#"") & (Position:C15("//"; $trimmed)#1)
			// Handle inline comments (simple approach - not handling comments inside strings perfectly)
			var $commentPos : Integer:=Position:C15("//"; $line)
			If ($commentPos>0)
				// Check if // is inside a string (simplified - count quotes before //)
				var $beforeComment : Text:=Substring:C12($line; 1; $commentPos-1)
				var $quoteCount : Integer:=This:C1470._countChar($beforeComment; "\"")
				If (($quoteCount%2)=0)  // Even number of quotes = not inside string
					$line:=Substring:C12($line; 1; $commentPos-1)
				End if 
			End if 
			$cleanLines.push($line)
		Else 
			If ($trimmed="")  // Keep empty lines
				$cleanLines.push($line)
			End if 
		End if 
	End for each 
	
	return $cleanLines.join("\n")
	
Function _trim($text : Text) : Text
	var $result : Text:=$text
	// Trim leading whitespace
	While (Length:C16($result)>0) & (Position:C15($result[[1]]; " \t")>0)
		$result:=Substring:C12($result; 2)
	End while 
	// Trim trailing whitespace
	While (Length:C16($result)>0) & (Position:C15($result[[Length:C16($result)]]; " \t")>0)
		$result:=Substring:C12($result; 1; Length:C16($result)-1)
	End while 
	return $result
	
Function _countChar($text : Text; $char : Text) : Integer
	var $count : Integer:=0
	var $i : Integer
	For ($i; 1; Length:C16($text))
		If ($text[[$i]]=$char)
			$count:=$count+1
		End if 
	End for 
	return $count
	