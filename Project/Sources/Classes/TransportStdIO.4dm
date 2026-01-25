// MCP Transport using stdio (stdin/stdout) communication
// Protocol-only layer - process management delegated to StdIOProcess

property _process : cs:C1710.StdIO.Process
property _command : Text
property _options : Object
property _launched : Boolean

Class extends Transport

Class constructor($command : Text; $options : Object)
	Super:C1705()

	// Store configuration but DON'T launch yet (lazy launch pattern)
	This:C1470._command:=$command
	This:C1470._options:=$options
	This:C1470._launched:=False:C215

	// Create process object without launching
	This:C1470._process:=cs:C1710.StdIO.Process.new($command; $options)

// Ensure process is launched before use (lazy launch)
Function _ensureLaunched()
	If (Not:C34(This:C1470._launched))
		This:C1470._process.launch()
		This:C1470._launched:=True:C214
	End if

// Check if process has been launched
Function get isLaunched : Boolean
	return This:C1470._launched
	
Function send($message : cs:C1710.JSONRPC.Request; $formula : 4D:C1709.Function) : cs:C1710.Result
	This:C1470._ensureLaunched()
	var $jsonString : Text:=JSON Stringify:C1217($message)+"\n"
	
	// Async mode: use formula callback
	If ($formula#Null:C1517)
		var $method : Text:=$message.method
		var $self : cs:C1710.TransportStdIO:=This:C1470
		
		// Wrap callback to process response before calling user formula
		var $wrapper : 4D:C1709.Function:=Formula:C1597($self._asyncCallback($1; $method; $formula))
		This:C1470._process.registerCallback($message.id; $wrapper)
		This:C1470._process.send($jsonString)
		return Null:C1517
	End if 
	
	// Sync mode: wait for response
	var $timeout : Integer:=10000
	var $response : Object:=This:C1470._process.sendAndWait($jsonString; $message.id; $timeout)
	
	If (OB Is defined:C1231($response; "error"))
		If (Value type:C1509($response.error)=Is text:K8:3)
			// Timeout or process error
			var $errorResult : cs:C1710.Result:=cs:C1710.Result.new()
			$errorResult.error:=cs:C1710.JSONRPC.Init.me.errorData(\
				cs:C1710.JSONRPC.Init.me.REQUEST_TIMEOUT; \
				$response.error; \
				Null:C1517)
			return $errorResult
		End if 
	End if 
	
	// Process response based on method
	return This:C1470._processResponse($message.method; $response)
	
Function _asyncCallback($response : Object; $method : Text; $formula : 4D:C1709.Function)
	// Process response and call user formula
	var $result : cs:C1710.Result:=This:C1470._processResponse($method; $response)
	$formula.call(This:C1470; $result)
	
Function close()
	If (This:C1470._launched)
		This:C1470._process.kill()
		This:C1470._launched:=False:C215
	End if

Function notify($notification : cs:C1710.JSONRPC.Notification)
	This:C1470._ensureLaunched()
	var $jsonString : Text:=JSON Stringify:C1217($notification)+"\n"
	This:C1470._process.send($jsonString)
	