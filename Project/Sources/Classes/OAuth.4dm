// MCP OAuth 2.1 server: acts as BOTH the authorization server (AS) and the
// resource-server (RS) validation layer, with a self-hosted login (no NetKit /
// no external IdP). Tokens are HS256 JWTs signed with a server secret, so the
// same 4D server that issues them also validates them.
//
// Endpoints (wired in HTTPHandlers.json):
//   GET  /.well-known/oauth-protected-resource    -> wellKnownResource   (RFC 9728)
//   GET  /.well-known/oauth-authorization-server  -> wellKnownAuthServer (RFC 8414)
//   GET  /oauth/authorize                          -> authorize  (login form)
//   POST /oauth/authorize                          -> authorize  (credentials -> code)
//   POST /oauth/token                              -> token      (code -> access token)
//   POST /oauth/register                           -> register   (RFC 7591 DCR)
//
// State lives in Storage.oauth (shared): secret, users, clients, codes, refresh.
//
// SECURITY NOTES (read before production):
//   - The user store here is a plain collection (configure(users)). Swap
//     _authenticate() for a real table lookup with hashed passwords.
//   - _nowEpoch() uses local time; use a proper UTC epoch in production.
//   - Authorization codes / refresh tokens are kept in Storage with no sweep;
//     add expiry cleanup for a long-running server.

shared singleton Class constructor
	
	// ============================================================================
	// Configuration (call from On Startup)
	//   $options.secret : HS256 signing secret (generated if omitted)
	//   $options.users  : [ {username; password; sub; scope} ]  (demo store)
	// ============================================================================
	
Function configure($options : Object)
	Use (Storage:C1525)
		If (Storage:C1525.oauth=Null:C1517)
			Storage:C1525.oauth:=New shared object:C1526
		End if 
	End use 
	
	Use (Storage:C1525.oauth)
		// Signing secret
		If (($options.secret#Null:C1517) && (String:C10($options.secret)#""))
			Storage:C1525.oauth.secret:=String:C10($options.secret)
		Else 
			If ((Storage:C1525.oauth.secret=Null:C1517) || (Storage:C1525.oauth.secret=""))
				Storage:C1525.oauth.secret:=Generate UUID:C1066+Generate UUID:C1066
			End if 
		End if 
		
		// User store
		If ($options.users#Null:C1517)
			Storage:C1525.oauth.users:=$options.users.copy(ck shared:K85:29; Storage:C1525.oauth)
		End if 
		
		// Mutable stores (shared sub-objects in the same group)
		If (Storage:C1525.oauth.clients=Null:C1517)
			Storage:C1525.oauth.clients:=New shared object:C1526()
		End if 
		If (Storage:C1525.oauth.codes=Null:C1517)
			Storage:C1525.oauth.codes:=New shared object:C1526()
		End if 
		If (Storage:C1525.oauth.refresh=Null:C1517)
			Storage:C1525.oauth.refresh:=New shared object:C1526()
		End if 
	End use 
	
	// ============================================================================
	// Discovery metadata
	// ============================================================================
	
Function wellKnownResource($request : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $base : Text:=This:C1470._baseURL($request)
	// One protected resource here: the demo MCP endpoint. Extend for more.
	var $doc : Object:={\
		resource: $base+"/mcp/demo"; \
		authorization_servers: [$base]; \
		bearer_methods_supported: ["header"]; \
		scopes_supported: ["mcp:tools"]\
		}
	return This:C1470._json(4D:C1709.OutgoingMessage.new(); $doc; 200)
	
Function wellKnownAuthServer($request : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $base : Text:=This:C1470._baseURL($request)
	var $doc : Object:={\
		issuer: $base; \
		authorization_endpoint: $base+"/oauth/authorize"; \
		token_endpoint: $base+"/oauth/token"; \
		registration_endpoint: $base+"/oauth/register"; \
		response_types_supported: ["code"]; \
		grant_types_supported: ["authorization_code"; "refresh_token"]; \
		code_challenge_methods_supported: ["S256"]; \
		token_endpoint_auth_methods_supported: ["none"]; \
		scopes_supported: ["mcp:tools"]\
		}
	return This:C1470._json(4D:C1709.OutgoingMessage.new(); $doc; 200)
	
	// ============================================================================
	// Authorization endpoint - GET shows a login form, POST processes it and
	// redirects back to the client's callback with an authorization code.
	// ============================================================================
	
Function authorize($request : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $response : 4D:C1709.OutgoingMessage:=4D:C1709.OutgoingMessage.new()
	
	If ($request.verb="get")
		// urlQuery carries response_type, client_id, redirect_uri, code_challenge,
		// code_challenge_method, state, scope, resource
		$response.setBody(This:C1470._loginForm($request.urlQuery; ""))
		$response.setHeader("Content-Type"; "text/html; charset=utf-8")
		$response.setStatus(200)
		return $response
	End if 
	
	// POST: form fields = the oauth params (hidden) + username + password
	var $form : Object:=This:C1470._parseForm($request.getText())
	
	var $sub : Text:=This:C1470._authenticate(String:C10($form.username); String:C10($form.password))
	If ($sub="")
		$response.setBody(This:C1470._loginForm($form; "Invalid credentials"))
		$response.setHeader("Content-Type"; "text/html; charset=utf-8")
		$response.setStatus(401)
		return $response
	End if 
	
	// Validate client + redirect_uri
	var $client : Object:=This:C1470._getClient(String:C10($form.client_id))
	If (($client=Null:C1517) || (Not:C34(This:C1470._redirectAllowed($client; String:C10($form.redirect_uri)))))
		$response.setStatus(400)
		$response.setBody("invalid_request: unknown client_id or redirect_uri")
		return $response
	End if 
	
	// Issue a one-time authorization code bound to the PKCE challenge + resource
	var $code : Text:=Generate UUID:C1066
	This:C1470._storeCode($code; {\
		client_id: String:C10($form.client_id); \
		redirect_uri: String:C10($form.redirect_uri); \
		code_challenge: String:C10($form.code_challenge); \
		resource: String:C10($form.resource); \
		scope: String:C10($form.scope); \
		sub: $sub; \
		exp: This:C1470._nowEpoch()+600\
		})
	
	// Redirect back to the client callback. state + code MUST be percent-encoded
	// so the client gets back the exact bytes it sent (else "state does not match").
	var $sep : Text:=Choose:C955(Position:C15("?"; String:C10($form.redirect_uri))>0; "&"; "?")
	var $location : Text:=String:C10($form.redirect_uri)+$sep+"code="+This:C1470._urlEncode($code)
	If (($form.state#Null:C1517) && (String:C10($form.state)#""))
		$location:=$location+"&state="+This:C1470._urlEncode(String:C10($form.state))
	End if
	$response.setStatus(302)
	$response.setHeader("Location"; $location)
	return $response
	
	// ============================================================================
	// Token endpoint - exchanges an authorization code (+ PKCE verifier) or a
	// refresh token for a signed access token.
	// ============================================================================
	
Function token($request : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $response : 4D:C1709.OutgoingMessage:=4D:C1709.OutgoingMessage.new()
	var $form : Object:=This:C1470._parseForm($request.getText())
	var $issuer : Text:=This:C1470._baseURL($request)
	
	Case of 
		: (String:C10($form.grant_type)="authorization_code")
			var $rec : Object:=This:C1470._consumeCode(String:C10($form.code))
			If ($rec=Null:C1517)
				return This:C1470._tokenError($response; "invalid_grant"; "unknown or used code")
			End if 
			If ($rec.exp<This:C1470._nowEpoch())
				return This:C1470._tokenError($response; "invalid_grant"; "expired code")
			End if 
			If ($rec.redirect_uri#String:C10($form.redirect_uri))
				return This:C1470._tokenError($response; "invalid_grant"; "redirect_uri mismatch")
			End if 
			If ($rec.client_id#String:C10($form.client_id))
				return This:C1470._tokenError($response; "invalid_grant"; "client_id mismatch")
			End if 
			// PKCE S256 verification
			If ($rec.code_challenge#"")
				var $calc : Text:=Generate digest:C1147(String:C10($form.code_verifier); SHA256 digest:K66:4; *)
				If ($calc#$rec.code_challenge)
					return This:C1470._tokenError($response; "invalid_grant"; "PKCE verification failed")
				End if 
			End if 
			
			var $access : Text:=This:C1470._issueAccessToken($rec.sub; $rec.resource; $rec.scope; $issuer)
			var $refresh : Text:=This:C1470._issueRefreshToken($rec.sub; $rec.resource; $rec.scope)
			return This:C1470._json($response; {\
				access_token: $access; \
				token_type: "Bearer"; \
				expires_in: 3600; \
				scope: $rec.scope; \
				refresh_token: $refresh\
				}; 200)
			
		: (String:C10($form.grant_type)="refresh_token")
			var $rt : Object:=This:C1470._getRefresh(String:C10($form.refresh_token))
			If ($rt=Null:C1517)
				return This:C1470._tokenError($response; "invalid_grant"; "unknown refresh_token")
			End if 
			var $access2 : Text:=This:C1470._issueAccessToken($rt.sub; $rt.aud; $rt.scope; $issuer)
			return This:C1470._json($response; {\
				access_token: $access2; \
				token_type: "Bearer"; \
				expires_in: 3600; \
				scope: $rt.scope\
				}; 200)
			
		Else 
			return This:C1470._tokenError($response; "unsupported_grant_type"; "")
	End case 
	
	// ============================================================================
	// Dynamic Client Registration (RFC 7591) - public clients, no secret.
	// ============================================================================
	
Function register($request : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $response : 4D:C1709.OutgoingMessage:=4D:C1709.OutgoingMessage.new()
	var $body : Object:=JSON Parse:C1218($request.getText())
	If (Value type:C1509($body)#Is object:K8:27)
		return This:C1470._json($response; {error: "invalid_client_metadata"}; 400)
	End if 
	
	var $clientId : Text:=Generate UUID:C1066
	var $client : Object:={\
		client_id: $clientId; \
		redirect_uris: $body.redirect_uris || []; \
		client_name: String:C10($body.client_name); \
		token_endpoint_auth_method: "none"; \
		grant_types: ["authorization_code"; "refresh_token"]\
		}
	This:C1470._storeClient($clientId; $client)
	return This:C1470._json($response; $client; 201)
	
	// ============================================================================
	// Resource-server side: token validation + 401 challenge
	// ============================================================================
	
	// Validate the bearer token on an incoming MCP request.
	// Returns {success; claims} or {success: False; reason}.
Function validateBearer($request : 4D:C1709.IncomingMessage) : Object
	var $auth : Text:=$request.getHeader("authorization")
	If (Position:C15("Bearer "; $auth)#1)
		return {success: False:C215; reason: "missing bearer token"}
	End if 
	var $token : Text:=Substring:C12($auth; 8)
	
	var $j : cs:C1710.jwt:=cs:C1710.jwt.new()
	var $status : Object:=$j.verify($token; {secret: This:C1470._secret()})
	If (Not:C34($status.success))
		return {success: False:C215; reason: "bad signature"}
	End if 
	
	var $claims : Object:=$status.payload
	If ($claims.exp<This:C1470._nowEpoch())
		return {success: False:C215; reason: "expired"}
	End if 
	// Audience binding: the token MUST have been issued for THIS endpoint
	var $expectedAud : Text:=This:C1470._baseURL($request)+$request.url
	If ($claims.aud#$expectedAud)
		return {success: False:C215; reason: "audience mismatch"}
	End if 
	
	return {success: True:C214; claims: $claims}
	
	// Build the 401 response that triggers the OAuth discovery flow.
Function challenge($request : 4D:C1709.IncomingMessage; $response : 4D:C1709.OutgoingMessage) : 4D:C1709.OutgoingMessage
	var $prm : Text:=This:C1470._baseURL($request)+"/.well-known/oauth-protected-resource"
	$response.setStatus(401)
	$response.setHeader("WWW-Authenticate"; "Bearer resource_metadata=\""+$prm+"\"")
	$response.setBody("{\"error\":\"invalid_token\"}")
	$response.setHeader("Content-Type"; "application/json")
	return $response
	
	// ============================================================================
	// Token minting
	// ============================================================================
	
Function _issueAccessToken($sub : Text; $aud : Text; $scope : Text; $issuer : Text) : Text
	var $now : Real:=This:C1470._nowEpoch()
	var $payload : Object:={\
		iss: $issuer; \
		sub: $sub; \
		aud: $aud; \
		scope: $scope; \
		iat: $now; \
		exp: $now+3600; \
		jti: Generate UUID:C1066\
		}
	var $j : cs:C1710.jwt:=cs:C1710.jwt.new()
	return $j.sign({alg: "HS256"; typ: "JWT"}; $payload; {algorithm: "HS256"; secret: This:C1470._secret()})
	
Function _issueRefreshToken($sub : Text; $aud : Text; $scope : Text) : Text
	var $rt : Text:=Generate UUID:C1066+Generate UUID:C1066
	This:C1470._storeRefresh($rt; {sub: $sub; aud: $aud; scope: $scope})
	return $rt
	
	// ============================================================================
	// User store (DEMO: plain collection — replace with a table lookup)
	// ============================================================================
	
Function _authenticate($username : Text; $password : Text) : Text
	If ((Storage:C1525.oauth=Null:C1517) || (Storage:C1525.oauth.users=Null:C1517))
		return ""
	End if 
	var $user : Object
	For each ($user; Storage:C1525.oauth.users)
		If (($user.username=$username) && ($user.password=$password))
			return String:C10($user.sub)
		End if 
	End for each 
	return ""
	
	// ============================================================================
	// Client / code / refresh stores (Storage, shared)
	// ============================================================================
	
Function _storeClient($id : Text; $client : Object)
	Use (Storage:C1525.oauth.clients)
		Storage:C1525.oauth.clients[$id]:=OB Copy:C1225($client; ck shared:K85:29; Storage:C1525.oauth.clients)
	End use 
	
Function _getClient($id : Text) : Object
	If ((Storage:C1525.oauth=Null:C1517) || (Storage:C1525.oauth.clients=Null:C1517))
		return Null:C1517
	End if 
	var $c : Object:=Storage:C1525.oauth.clients[$id]
	If ($c=Null:C1517)
		return Null:C1517
	End if 
	return OB Copy:C1225($c)  // plain copy for safe read
	
Function _redirectAllowed($client : Object; $redirectURI : Text) : Boolean
	If (Value type:C1509($client.redirect_uris)#Is collection:K8:32)
		return False:C215
	End if 
	return ($client.redirect_uris.indexOf($redirectURI)>=0)
	
Function _storeCode($code : Text; $rec : Object)
	Use (Storage:C1525.oauth.codes)
		Storage:C1525.oauth.codes[$code]:=OB Copy:C1225($rec; ck shared:K85:29; Storage:C1525.oauth.codes)
	End use 
	
	// Read AND delete (one-time use). Returns a plain copy or Null.
Function _consumeCode($code : Text) : Object
	If ((Storage:C1525.oauth=Null:C1517) || (Storage:C1525.oauth.codes=Null:C1517))
		return Null:C1517
	End if 
	var $rec : Object:=Storage:C1525.oauth.codes[$code]
	If ($rec=Null:C1517)
		return Null:C1517
	End if 
	var $plain : Object:=OB Copy:C1225($rec)
	Use (Storage:C1525.oauth.codes)
		OB REMOVE:C1226(Storage:C1525.oauth.codes; $code)
	End use 
	return $plain
	
Function _storeRefresh($rt : Text; $rec : Object)
	Use (Storage:C1525.oauth.refresh)
		Storage:C1525.oauth.refresh[$rt]:=OB Copy:C1225($rec; ck shared:K85:29; Storage:C1525.oauth.refresh)
	End use 
	
Function _getRefresh($rt : Text) : Object
	If ((Storage:C1525.oauth=Null:C1517) || (Storage:C1525.oauth.refresh=Null:C1517))
		return Null:C1517
	End if 
	var $rec : Object:=Storage:C1525.oauth.refresh[$rt]
	If ($rec=Null:C1517)
		return Null:C1517
	End if 
	return OB Copy:C1225($rec)
	
	// ============================================================================
	// Helpers
	// ============================================================================
	
Function _secret() : Text
	If (Storage:C1525.oauth=Null:C1517)
		return ""
	End if 
	return String:C10(Storage:C1525.oauth.secret)
	
	// Reconstruct the base URL (scheme://host) from the request Host header.
Function _baseURL($request : 4D:C1709.IncomingMessage) : Text
	var $host : Text:=$request.getHeader("host")
	If ($host="")
		$host:="localhost"
	End if 
	var $scheme : Text:="https"
	If ((Position:C15("localhost"; $host)>0) || (Position:C15("127.0.0.1"; $host)>0))
		$scheme:="http"
	End if 
	return $scheme+"://"+$host
	
	// Local epoch seconds. NOTE: ignores timezone; fine for demo, fix for prod.
Function _nowEpoch() : Real
	return ((Current date:C33-(!1970-01-01!))*86400)+(Current time:C178+0)
	
Function _json($response : 4D:C1709.OutgoingMessage; $obj : Object; $status : Integer) : 4D:C1709.OutgoingMessage
	$response.setBody(JSON Stringify:C1217($obj))
	$response.setHeader("Content-Type"; "application/json")
	$response.setHeader("Cache-Control"; "no-store")
	$response.setStatus($status)
	return $response
	
Function _tokenError($response : 4D:C1709.OutgoingMessage; $error : Text; $description : Text) : 4D:C1709.OutgoingMessage
	var $body : Object:={error: $error}
	If ($description#"")
		$body.error_description:=$description
	End if 
	// OAuth token errors use 400 (401 for invalid_client)
	return This:C1470._json($response; $body; 400)
	
	// Minimal HTML login form that re-posts the oauth params as hidden fields.
Function _loginForm($params : Object; $error : Text) : Text
	var $errHtml : Text:=Choose:C955($error=""; ""; "<p style=\"color:#c00\">"+$error+"</p>")
	var $html : Text:=""
	$html:=$html+"<!doctype html><html><head><meta charset=\"utf-8\"><title>Sign in</title></head>"
	$html:=$html+"<body style=\"font-family:sans-serif;max-width:340px;margin:80px auto\">"
	$html:=$html+"<h2>MCP server sign in</h2>"+$errHtml
	$html:=$html+"<form method=\"post\" action=\"/oauth/authorize\">"
	$html:=$html+This:C1470._hidden("response_type"; $params.response_type)
	$html:=$html+This:C1470._hidden("client_id"; $params.client_id)
	$html:=$html+This:C1470._hidden("redirect_uri"; $params.redirect_uri)
	$html:=$html+This:C1470._hidden("code_challenge"; $params.code_challenge)
	$html:=$html+This:C1470._hidden("code_challenge_method"; $params.code_challenge_method)
	$html:=$html+This:C1470._hidden("state"; $params.state)
	$html:=$html+This:C1470._hidden("scope"; $params.scope)
	$html:=$html+This:C1470._hidden("resource"; $params.resource)
	$html:=$html+"<p><input name=\"username\" placeholder=\"username\" style=\"width:100%;padding:8px\"></p>"
	$html:=$html+"<p><input name=\"password\" type=\"password\" placeholder=\"password\" style=\"width:100%;padding:8px\"></p>"
	$html:=$html+"<p><button type=\"submit\" style=\"width:100%;padding:10px\">Authorize</button></p>"
	$html:=$html+"</form></body></html>"
	return $html
	
Function _hidden($name : Text; $value : Variant) : Text
	return "<input type=\"hidden\" name=\""+$name+"\" value=\""+This:C1470._htmlEscape(This:C1470._scalar($value))+"\">"

	// urlQuery may hand back a value as text or as a single-element collection
	// (repeated params). Normalize to the scalar text so it can't become JSON.
Function _scalar($value : Variant) : Text
	If (Value type:C1509($value)=Is collection:K8:32)
		If ($value.length>0)
			return String:C10($value[0])
		End if
		return ""
	End if
	return String:C10($value)
	
	// ============================================================================
	// application/x-www-form-urlencoded parsing
	// ============================================================================
	
Function _parseForm($body : Text) : Object
	var $result : Object:={}
	var $pair : Text
	For each ($pair; Split string:C1554($body; "&"))
		If ($pair#"")
			var $eq : Integer:=Position:C15("="; $pair)
			If ($eq>0)
				var $k : Text:=This:C1470._urlDecode(Substring:C12($pair; 1; $eq-1))
				var $v : Text:=This:C1470._urlDecode(Substring:C12($pair; $eq+1))
				$result[$k]:=$v
			End if 
		End if 
	End for each 
	return $result
	
	// Percent-decode (UTF-8 aware) a form/query token.
Function _urlDecode($s : Text) : Text
	$s:=Replace string:C233($s; "+"; " ")
	var $blob : Blob
	SET BLOB SIZE:C606($blob; 0)
	var $i : Integer:=1
	var $len : Integer:=Length:C16($s)
	While ($i<=$len)
		var $c : Text:=$s[[$i]]
		If (($c="%") && (($i+2)<=$len))
			var $n : Integer:=BLOB size:C605($blob)
			SET BLOB SIZE:C606($blob; $n+1)
			$blob{$n}:=This:C1470._hexByte(Substring:C12($s; $i+1; 2))
			$i:=$i+3
		Else 
			var $cb : Blob
			TEXT TO BLOB:C554($c; $cb; UTF8 text without length:K22:17)
			var $base : Integer:=BLOB size:C605($blob)
			var $add : Integer:=BLOB size:C605($cb)
			SET BLOB SIZE:C606($blob; $base+$add)
			COPY BLOB:C558($cb; $blob; 0; $base; $add)
			$i:=$i+1
		End if 
	End while 
	return BLOB to text:C555($blob; UTF8 text without length:K22:17)
	
Function _hexByte($hex : Text) : Integer
	return (This:C1470._hexDigit($hex[[1]])*16)+This:C1470._hexDigit($hex[[2]])
	
Function _hexDigit($c : Text) : Integer
	return Position:C15(Uppercase:C13($c); "0123456789ABCDEF")-1

	// Percent-encode (UTF-8) everything except RFC 3986 unreserved characters.
	// Used for state/code in the redirect query so they round-trip byte-for-byte.
Function _urlEncode($s : Text) : Text
	var $unreserved : Text:="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~"
	var $hex : Text:="0123456789ABCDEF"
	var $blob : Blob
	TEXT TO BLOB:C554($s; $blob; UTF8 text without length:K22:17)
	var $out : Text:=""
	var $i : Integer
	For ($i; 0; BLOB size:C605($blob)-1)
		var $b : Integer:=$blob{$i}
		var $ch : Text:=Char:C90($b)
		If (($b<128) && (Position:C15($ch; $unreserved)>0))
			$out:=$out+$ch
		Else
			$out:=$out+"%"+$hex[[(Int:C8($b/16)+1)]]+$hex[[(($b%16)+1)]]
		End if
	End for
	return $out

	// Escape a value for safe inclusion in an HTML attribute.
Function _htmlEscape($value : Variant) : Text
	var $s : Text:=String:C10($value)
	$s:=Replace string:C233($s; "&"; "&amp;")
	$s:=Replace string:C233($s; "\""; "&quot;")
	$s:=Replace string:C233($s; "<"; "&lt;")
	$s:=Replace string:C233($s; ">"; "&gt;")
	return $s
	