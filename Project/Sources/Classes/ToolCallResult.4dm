// Result of a tool call
// content is a collection of content items (text, image, etc.)

property content : Collection
property isError : Boolean

Class extends Result

Class constructor
	Super:C1705()
	This:C1470.content:=New collection:C1472
	This:C1470.isError:=False:C215
	
Function text() : Text
	// Convenience: get all text content concatenated
	var $result : Text:=""
	var $item : Object
	
	For each ($item; This:C1470.content)
		If ($item.type="text")
			$result:=$result+$item.text
		End if 
	End for each 
	
	return $result
	
Function data() : Object
	// Convenience: parse first text content as JSON
	var $item : Object
	
	For each ($item; This:C1470.content)
		If ($item.type="text")
			return JSON Parse:C1218($item.text)
		End if 
	End for each 
	
	return Null:C1517
	