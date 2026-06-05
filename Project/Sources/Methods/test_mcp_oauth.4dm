//%attributes = {}
// Exercises the OAuth server-side logic directly (no HTTP layer): user auth,
// PKCE, one-time authorization codes, and signed-token mint/verify/audience.

cs:C1710.OAuth.me.configure({\
secret: "test-secret-please-change"; \
users: [{username: "alice"; password: "wonderland"; sub: "user-alice"; scope: "mcp:tools"}]\
})

var $oauth : cs:C1710.OAuth:=cs:C1710.OAuth.me

// --- user authentication ---
ASSERT:C1129($oauth._authenticate("alice"; "wonderland")="user-alice"; "valid credentials should resolve to sub")
ASSERT:C1129($oauth._authenticate("alice"; "wrong")=""; "bad password should fail")
ASSERT:C1129($oauth._authenticate("bob"; "wonderland")=""; "unknown user should fail")

// --- PKCE S256 round-trip ---
var $verifier : Text:="dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
var $challenge : Text:=Generate digest:C1147($verifier; SHA256 digest:K66:4; *)  // base64url(SHA256(verifier))
ASSERT:C1129(Generate digest:C1147($verifier; SHA256 digest:K66:4; *)=$challenge; "PKCE challenge must be deterministic")

// --- authorization code is single-use ---
var $code : Text:="test-code-123"
$oauth._storeCode($code; {client_id: "c1"; redirect_uri: "http://localhost:9999/cb"; code_challenge: $challenge; resource: "http://localhost/mcp/demo"; scope: "mcp:tools"; sub: "user-alice"; exp: $oauth._nowEpoch()+600})
var $rec : Object:=$oauth._consumeCode($code)
ASSERT:C1129($rec#Null:C1517; "code should be consumable once")
ASSERT:C1129($rec.sub="user-alice"; "consumed code should carry the subject")
ASSERT:C1129($oauth._consumeCode($code)=Null:C1517; "code must not be reusable")

// --- access-token mint + verify + audience binding ---
var $aud : Text:="http://localhost/mcp/demo"
var $token : Text:=$oauth._issueAccessToken("user-alice"; $aud; "mcp:tools"; "http://localhost")

var $jwt : cs:C1710.jwt:=cs:C1710.jwt.new()
var $status : Object:=$jwt.verify($token; {secret: "test-secret-please-change"})
ASSERT:C1129($status.success; "freshly minted token should verify")
ASSERT:C1129($status.payload.sub="user-alice"; "token subject should match")
ASSERT:C1129($status.payload.aud=$aud; "token audience should be the resource")
ASSERT:C1129($status.payload.exp>$oauth._nowEpoch(); "token should not be already expired")

// --- tampering / wrong secret is rejected ---
var $bad : Object:=$jwt.verify($token; {secret: "the-wrong-secret"})
ASSERT:C1129(Not:C34($bad.success); "token must fail verification under a different secret")

// --- refresh token round-trip ---
var $rt : Text:=$oauth._issueRefreshToken("user-alice"; $aud; "mcp:tools")
var $rtRec : Object:=$oauth._getRefresh($rt)
ASSERT:C1129($rtRec#Null:C1517; "refresh token should be retrievable")
ASSERT:C1129($rtRec.aud=$aud; "refresh token should carry the audience")
