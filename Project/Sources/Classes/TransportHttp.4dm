// MCP Transport using HTTP (Streamable HTTP protocol)
// Supports both application/json and text/event-stream (SSE) responses

property _url : Text
property _headers : Object
property _timeout : Real
property _sessionId : Text
property _protocolVersion : Text

Class extends Transport

Class constructor($url : Text; $options : Object)
	Super:C1705()
	
	This:C1470._url:=$url
	
	// Initialize default headers
	This:C1470._headers:={Accept: "application/json, text/event-stream"}
	This:C1470._headers["Content-Type"]:="application/json"
	
	// Merge custom headers from options
	If ($options#Null:C1517)
		If ($options.headers#Null:C1517)
			var $key : Text
			For each ($key; $options.headers)
				This:C1470._headers[$key]:=$options.headers[$key]
			End for each 
		End if 
		
		// Set timeout (default 60 seconds)
		This:C1470._timeout:=($options.timeout#Null:C1517) ? $options.timeout : 60
	Else 
		This:C1470._timeout:=60
	End if 
	
Function send($message : cs:C1710.JSONRPC.Request; $formula : 4D:C1709.Function) : cs:C1710.Result
	var $jsonBody : Text:=JSON Stringify:C1217($message)
	var $headers : Object:=OB Copy:C1225(This:C1470._headers)
	
	// Add session ID header if available
	If (Length:C16(This:C1470._sessionId)>0)
		$headers["Mcp-Session-Id"]:=This:C1470._sessionId
	End if 
	
	// Add protocol version header if available
	If (Length:C16(This:C1470._protocolVersion)>0)
		$headers["MCP-Protocol-Version"]:=This:C1470._protocolVersion
	End if 
	
	var $options : Object:={\
		method: "POST"; \
		headers: $headers; \
		body: $jsonBody; \
		timeout: This:C1470._timeout\
		}
	
	// ==== ASYNC MODE ====
	If ($formula#Null:C1517)
		var $method : Text:=$message.method
		var $self : cs:C1710.TransportHttp:=This:C1470
		
		// Create async options with onTerminate callback
		$options.onTerminate:=Formula:C1597($self._onHttpComplete($1; $method; $formula))
		
		// Fire and forget - create request (returns immediately)
		4D:C1709.HTTPRequest.new(This:C1470._url; $options)
		return Null:C1517
	End if 
	
	// ==== SYNC MODE ====
	var $request:=4D:C1709.HTTPRequest.new(This:C1470._url; $options)
	$request.wait()
	
	return This:C1470._handleHttpResponse($request; $message.method)
	
Function _onHttpComplete($request : 4D:C1709.HTTPRequest; $method : Text; $formula : 4D:C1709.Function)
	// Process HTTP response and call user formula
	var $result : cs:C1710.Result:=This:C1470._handleHttpResponse($request; $method)
	$formula.call(This:C1470; $result)
	
Function _handleHttpResponse($request : 4D:C1709.HTTPRequest; $method : Text) : cs:C1710.Result
	var $response : Object:=$request.response
	
	// ==== NETWORK ERROR ====
	If ($response=Null:C1517)
		var $networkError : cs:C1710.Result:=cs:C1710.Result.new()
		$networkError.success:=False:C215
		$networkError.error:=cs:C1710.JSONRPC.Init.me.errorData(\
			cs:C1710.JSONRPC.Init.me.CONNECTION_CLOSED; \
			"Network error: No response received"; \
			Null:C1517)
		return $networkError
	End if 
	
	var $status : Integer:=Num:C11($response.status)
	
	// ==== 202 ACCEPTED (for notifications) ====
	If ($status=202)
		var $acceptedResult : cs:C1710.Result:=cs:C1710.Result.new()
		return $acceptedResult
	End if 
	
	// ==== EXTRACT SESSION ID FROM RESPONSE HEADERS ====
	// Try different header casings (HTTP headers are case-insensitive but 4D object access may not be)
	If ($response.headers#Null:C1517)
		var $newSessionId : Text:=This:C1470._getHeader($response.headers; "mcp-session-id")
		If (Length:C16($newSessionId)>0)
			This:C1470._sessionId:=$newSessionId
		End if 
	End if 
	
	// ==== HTTP ERROR ====
	If ($status<200) | ($status>=300)
		var $httpError : cs:C1710.Result:=cs:C1710.Result.new()
		$httpError.success:=False:C215
		
		var $errorMessage : Text:="HTTP error: "+String:C10($status)
		
		// Try to extract error message from response body
		If ($response.body#Null:C1517)
			var $bodyText : Text
			If (Value type:C1509($response.body)=Is BLOB:K8:12)
				$bodyText:=BLOB to text:C555($response.body; UTF8 C string:K22:15)
			Else 
				$bodyText:=String:C10($response.body)
			End if 
			If (Length:C16($bodyText)>0)
				$errorMessage:=$errorMessage+" - "+$bodyText
			End if 
		End if 
		
		// Map HTTP status to appropriate JSON-RPC error code
		var $errorCode : Integer
		Case of 
			: ($status=401) | ($status=403)
				$errorCode:=cs:C1710.JSONRPC.Init.me.INVALID_REQUEST
			: ($status=404)
				$errorCode:=cs:C1710.JSONRPC.Init.me.METHOD_NOT_FOUND
			: ($status=408) | ($status=504)
				$errorCode:=cs:C1710.JSONRPC.Init.me.REQUEST_TIMEOUT
			Else 
				$errorCode:=cs:C1710.JSONRPC.Init.me.INTERNAL_ERROR
		End case 
		
		$httpError.error:=cs:C1710.JSONRPC.Init.me.errorData($errorCode; $errorMessage; {status: $status})
		return $httpError
	End if 
	
	// ==== PARSE RESPONSE BODY ====
	If (Value type:C1509($response.body)=Is BLOB:K8:12)
		$bodyText:=BLOB to text:C555($response.body; UTF8 C string:K22:15)
	Else 
		If (Value type:C1509($response.body)=Is text:K8:3)
			$bodyText:=$response.body
		Else 
			If (Value type:C1509($response.body)=Is object:K8:27)
				// Already parsed as object
				return This:C1470._processResponse($method; $response.body)
			Else 
				$bodyText:=String:C10($response.body)
			End if 
		End if 
	End if 
	
	// ==== CHECK FOR SSE FORMAT (text/event-stream) ====
	// SSE format: "event: message\ndata: {...json...}\n\n"
	If ((Position:C15("event:"; $bodyText)=1) | (Position:C15("data:"; $bodyText)=1))
		$bodyText:=This:C1470._parseSSE($bodyText)
	End if 
	
	// Parse JSON response
	var $jsonResponse : Object:=JSON Parse:C1218($bodyText; Is object:K8:27)
	
	If ($jsonResponse=Null:C1517)
		var $parseError : cs:C1710.Result:=cs:C1710.Result.new()
		$parseError.success:=False:C215
		$parseError.error:=cs:C1710.JSONRPC.Init.me.errorData(\
			cs:C1710.JSONRPC.Init.me.PARSE_ERROR; \
			"Failed to parse JSON response"; \
			{rawBody: $bodyText})
		return $parseError
	End if 
	
	// ==== EXTRACT PROTOCOL VERSION FROM INITIALIZE RESPONSE ====
	If ($method="initialize")
		If ($jsonResponse.result#Null:C1517)
			If (Value type:C1509($jsonResponse.result.protocolVersion)=Is date:K8:7)
				var $protocolVersion:=String:C10($jsonResponse.result.protocolVersion; "yyyy-MM-dd")
			Else 
				$protocolVersion:=String:C10($jsonResponse.result.protocolVersion)
			End if 
			
			If (Length:C16($protocolVersion)>0)
				This:C1470._protocolVersion:=$protocolVersion
			End if 
		End if 
	End if 
	
	// ==== DELEGATE TO PARENT'S _processResponse ====
	return This:C1470._processResponse($method; $jsonResponse)
	
Function notify($notification : cs:C1710.JSONRPC.Notification)
	var $jsonBody : Text:=JSON Stringify:C1217($notification)
	var $headers : Object:=OB Copy:C1225(This:C1470._headers)
	
	// Add session ID header if available
	If (Length:C16(This:C1470._sessionId)>0)
		$headers["Mcp-Session-Id"]:=This:C1470._sessionId
	End if 
	
	// Add protocol version header if available
	If (Length:C16(This:C1470._protocolVersion)>0)
		$headers["MCP-Protocol-Version"]:=This:C1470._protocolVersion
	End if 
	
	var $options : Object:={\
		method: "POST"; \
		headers: $headers; \
		body: $jsonBody; \
		timeout: This:C1470._timeout\
		}
	
	// Fire and forget - no response expected
	4D:C1709.HTTPRequest.new(This:C1470._url; $options)
	
Function close()
	// HTTP transport is stateless per request, but we can terminate the session
	If (Length:C16(This:C1470._sessionId)>0)
		var $headers : Object:=OB Copy:C1225(This:C1470._headers)
		$headers["Mcp-Session-Id"]:=This:C1470._sessionId
		
		var $options : Object:={\
			method: "DELETE"; \
			headers: $headers; \
			timeout: This:C1470._timeout\
			}
		
		// Try to terminate session, ignore errors
		Try
			4D:C1709.HTTPRequest.new(This:C1470._url; $options).wait()
		Catch
			// Ignore termination errors
		End try
	End if 
	
	// Clear sensitive data
	This:C1470._headers:=Null:C1517
	This:C1470._sessionId:=""
	This:C1470._protocolVersion:=""
	This:C1470._url:=""
	
	// Getter for session ID
Function get sessionId : Text
	return This:C1470._sessionId
	
	// Getter for protocol version
Function get protocolVersion : Text
	return This:C1470._protocolVersion
	
	// Parse SSE (Server-Sent Events) format and extract JSON from data: lines
	// SSE format: "event: message\ndata: {...json...}\n\n"
	// Can have multiple events - we look for the last JSON-RPC response/error
Function _parseSSE($sseText : Text) : Text
	var $lines : Collection:=Split string:C1554($sseText; "\n")
	var $lastJsonData : Text:=""
	var $line : Text
	
	For each ($line; $lines)
		// Check for "data:" prefix
		If (Position:C15("data:"; $line)=1)
			var $data : Text:=Substring:C12($line; 6)  // Remove "data:" prefix
			// Trim leading space if present
			If (Length:C16($data)>0) && ($data[[1]]=" ")
				$data:=Substring:C12($data; 2)
			End if 
			// Skip empty data or "[DONE]" marker
			If (Length:C16($data)>0) && ($data#"[DONE]")
				// Check if it looks like JSON (starts with {)
				If ($data[[1]]="{")
					$lastJsonData:=$data
				End if 
			End if 
		End if 
	End for each 
	
	// Return the last JSON data found, or original text if no data: lines
	If (Length:C16($lastJsonData)>0)
		return $lastJsonData
	End if 
	return $sseText
	
	// Get header value with case-insensitive lookup
	// HTTP headers are case-insensitive but 4D object property access is case-sensitive
Function _getHeader($headers : Object; $name : Text) : Text
	// Try exact match first
	var $value : Text:=String:C10($headers[$name])
	If (Length:C16($value)>0)
		return $value
	End if 
	
	// Try case-insensitive search through all header keys
	var $key : Text
	var $lowerName : Text:=Lowercase:C14($name)
	For each ($key; $headers)
		If (Lowercase:C14($key)=$lowerName)
			return String:C10($headers[$key])
		End if 
	End for each 
	
	return ""
	