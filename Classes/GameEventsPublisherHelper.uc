class GameEventsPublisherHelper extends Object;

static function string CreateJsonPairAsInt(string key, int value) {
    return "\""$key$"\":"@value;
}

static function string CreateJsonPairAsBool(string key, bool value) {
    return "\""$key$"\":"@ConvertIntoJsonBool(value);
}

static function string CreateJsonPairAsString(string key, string value) {
    return "\""$key$"\":"@WrapIntoJsonString(value);
}

// fix new line escape -rX
static function string CreateJsonPairAsStringWithEscape(string key, string value) {
    local string escapedValue;
    
    // Start with the original value
    escapedValue = value;
    
    // Chain replacements on 'escapedValue', not 'value'
    escapedValue = Replace(escapedValue, "\\", "\\\\"); // Backslashes first!
    escapedValue = Replace(escapedValue, "\"", "\\\""); 
    escapedValue = Replace(escapedValue, Chr(10), "");   // Strip LF
    escapedValue = Replace(escapedValue, Chr(13), "");   // Strip CR
    escapedValue = Replace(escapedValue, Chr(9), " ");   // Tab to space

    // Don't use WrapIntoJsonString here as we manually escaped everything
    return "\"" $ key $ "\": \"" $ escapedValue $ "\"";
}

static function string WrapIntoJsonString(string value) {
    return "\""$Replace(value, "\\", "\\\\")$"\"";
}

static function string ConvertIntoJsonBool(bool value) {
    local string temp;
    temp = "false";
    if (value) {
        temp = "true";
    }
    return temp;
}

static function string Replace(string Text, string Match, string Replacement)
{
	local int i;
	
	i = InStr(Text, Match);	

	if(i != -1)
		return Left(Text, i) $ Replacement $ Replace(Mid(Text, i+Len(Match)), Match, Replacement);
	else
		return Text;
}

//
// Returns the string representation of the name of an object without the package
// prefixes.
//
static function String GetItemName( string FullName )
{
	local int pos;

	pos = InStr(FullName, ".");
	While ( pos != -1 )
	{
		FullName = Right(FullName, Len(FullName) - pos - 1);
		pos = InStr(FullName, ".");
	}

	return FullName;
}