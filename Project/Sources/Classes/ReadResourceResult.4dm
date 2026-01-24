// Result of a resources/read request

property contents : Collection  // TextResourceContents | BlobResourceContents

Class extends Result

Class constructor
	Super:C1705()
	This:C1470.contents:=New collection:C1472
	
	// Get text content from first resource
Function text() : Text
	var $item : Object
	For each ($item; This:C1470.contents)
		If ($item.text#Null:C1517)
			return $item.text
		End if 
	End for each 
	return ""
	
	// Get blob (base64) content from first resource
Function blob() : Text
	var $item : Object
	For each ($item; This:C1470.contents)
		If ($item.blob#Null:C1517)
			return $item.blob
		End if 
	End for each 
	return ""
	
	