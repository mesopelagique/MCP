// MCPServerConfig
// Configuration for a single MCP server from well-known config files

property name : Text
property type : Text
property command : Text
property args : Collection
property env : Object
property url : Text
property headers : Object
property source : Text

Class constructor($config : Object)
	// Set defaults from config object
	This:C1470.name:=$config.name || ""
	This:C1470.type:=$config.type || "stdio"
	This:C1470.command:=$config.command || ""
	This:C1470.args:=$config.args || New collection:C1472
	This:C1470.env:=$config.env || New object:C1471
	This:C1470.url:=$config.url || ""
	This:C1470.headers:=$config.headers || New object:C1471
	This:C1470.source:=$config.source || "custom"

// Creates a Transport instance for this server config (lazy - doesn't connect yet)
Function createTransport() : cs:C1710.Transport
	var $type : Text:=Lowercase:C14(This:C1470.type)

	Case of
		: ($type="stdio") | ($type="")
			If (This:C1470.command="")
				ASSERT:C1129(False:C215; "command is required for stdio transport")
				return Null:C1517
			End if

			// Build full command with args
			var $fullCommand : Text:=This:C1470.command
			var $arg : Variant
			For each ($arg; This:C1470.args)
				$fullCommand:=$fullCommand+" "+String:C10($arg)
			End for each

			// Create options with environment variables
			var $options : Object:=New object:C1471("env"; This:C1470.env)

			return cs:C1710.TransportStdIO.new($fullCommand; $options)

		: ($type="http") | ($type="sse")
			If (This:C1470.url="")
				ASSERT:C1129(False:C215; "url is required for http/sse transport")
				return Null:C1517
			End if

			var $httpOptions : Object:=New object:C1471("headers"; This:C1470.headers)
			return cs:C1710.TransportHttp.new(This:C1470.url; $httpOptions)

		Else
			ASSERT:C1129(False:C215; "Unsupported transport type: "+This:C1470.type)
			return Null:C1517
	End case

// Creates a Client instance with the appropriate transport
Function createClient($clientInfo : Object) : cs:C1710.Client
	var $transport : cs:C1710.Transport:=This:C1470.createTransport()
	If ($transport=Null:C1517)
		return Null:C1517
	End if

	return cs:C1710.Client.new($transport; $clientInfo)

// Validates the configuration has required fields
Function isValid() : Boolean
	var $type : Text:=Lowercase:C14(This:C1470.type)

	Case of
		: ($type="stdio") | ($type="")
			return This:C1470.command#""
		: ($type="http") | ($type="sse")
			return This:C1470.url#""
		Else
			return False:C215
	End case

// Returns a summary object for display
Function toObject() : Object
	return New object:C1471(\
		"name"; This:C1470.name; \
		"type"; This:C1470.type; \
		"command"; This:C1470.command; \
		"args"; This:C1470.args; \
		"env"; This:C1470.env; \
		"url"; This:C1470.url; \
		"headers"; This:C1470.headers; \
		"source"; This:C1470.source)

// ==============================================================================
// Fluent API for adding headers and env vars
// ==============================================================================

// Add a header (modifies in place, returns This for chaining)
Function addHeader($key : Text; $value : Text) : cs:C1710.MCPServerConfig
	This:C1470.headers[$key]:=$value
	return This:C1470

// Add multiple headers (modifies in place, returns This for chaining)
Function addHeaders($headers : Object) : cs:C1710.MCPServerConfig
	var $key : Text
	For each ($key; $headers)
		This:C1470.headers[$key]:=$headers[$key]
	End for each
	return This:C1470

// Return a copy with an added header (immutable)
Function withHeader($key : Text; $value : Text) : cs:C1710.MCPServerConfig
	var $copy : cs:C1710.MCPServerConfig:=This:C1470._copy()
	$copy.headers[$key]:=$value
	return $copy

// Return a copy with added headers (immutable)
Function withHeaders($headers : Object) : cs:C1710.MCPServerConfig
	var $copy : cs:C1710.MCPServerConfig:=This:C1470._copy()
	var $key : Text
	For each ($key; $headers)
		$copy.headers[$key]:=$headers[$key]
	End for each
	return $copy

// Add an environment variable (modifies in place, returns This for chaining)
Function addEnv($key : Text; $value : Text) : cs:C1710.MCPServerConfig
	This:C1470.env[$key]:=$value
	return This:C1470

// Return a copy with an added env var (immutable)
Function withEnv($key : Text; $value : Text) : cs:C1710.MCPServerConfig
	var $copy : cs:C1710.MCPServerConfig:=This:C1470._copy()
	$copy.env[$key]:=$value
	return $copy

// Create a deep copy of this config
Function _copy() : cs:C1710.MCPServerConfig
	return cs:C1710.MCPServerConfig.new(New object:C1471(\
		"name"; This:C1470.name; \
		"type"; This:C1470.type; \
		"command"; This:C1470.command; \
		"args"; This:C1470.args.copy(); \
		"env"; OB Copy:C1225(This:C1470.env); \
		"url"; This:C1470.url; \
		"headers"; OB Copy:C1225(This:C1470.headers); \
		"source"; This:C1470.source))
