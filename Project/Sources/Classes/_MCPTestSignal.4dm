// Test helper for async MCP operations

property result : cs:C1710.Result
property signal : 4D:C1709.Signal

shared singleton Class constructor
	
Function init()
	Use (This:C1470)
		This:C1470.signal:=New signal:C1641(Current method name:C684)
		This:C1470.result:=Null:C1517
	End use 
	
Function reset()
	Use (This:C1470)
		This:C1470.result:=Null:C1517
	End use 
	
Function wait($time : Integer)
	This:C1470.signal.wait($time)
	
Function trigger($result : cs:C1710.Result)
	Use (This:C1470)
		This:C1470.result:=OB Copy:C1225($result; ck shared:K85:29; This:C1470)
	End use 
	This:C1470.signal.trigger()
	