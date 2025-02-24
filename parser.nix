string:
let
  inherit (builtins)
    map
    head
    isString
    length
    filter
    match
    elemAt
    split
    concatStringsSep
    substring
    stringLength
    ;

  mod = base: int: base - (int * (builtins.div base int));
  isEven = n: (mod n 2) == 0;
  isOdd = n: !(isEven n);
  # If Value is not null, return value. Otherwise, return Other
  orElse = value: other: if value == null then other else value;
  # Returns whether str starts with token
  startsWith = token: str: (match "^[[:space:]]*${token}.*" str) != null;
  # Skip the first num characters of str
  skip = num: str: substring num ((stringLength str) - num) str;
  # Skip from str the length of prefix
  skipPrefix = prefix: str: skip (stringLength prefix) str;

  # Used for easier debugging
  # traceElem = e: builtins.trace e e;

  textWithoutComments =
    let
      # Given a line, remove any comments from it. This will look for any
      # double-slash at the end of the line that is not inside a quote.
      stripCommentsFromLine =
        line:
        let
          # Split the line at any <quote> character that's not escaped.
          quotePieces = filter isString (split "\"" line);

          # Check if character a index `charIndex` inside the string is escaped.
          # Note that <backslashes> can escape other <backslashes>. This means \\" is
          # not actually escaping the quote, but \\\" is. \\\\" Is not.
          isEscaped =
            str: charIndex:
            if charIndex == 0 then
              false
            else if substring (charIndex - 1) 1 str == "\\" then
              !(isEscaped str (charIndex - 1))
            else
              true;

          # Takes in the line that was split by quotes and check the parts outside
          # quotes for comments. If a part has a comment, it is removed and all further
          # parts are ignored. This helper function is here because it is recursive.
          removeCommentsHelper =
            pieces: n: isInsideQuote: result:
            if n >= length pieces then
              result
            else
              (
                let
                  piece = elemAt pieces n;
                  matchComment = match "^([^/][^/])*//.*" piece;
                in
                # Check if the split quote was actually escaped. If it was, call the function
                # again on the next piece, but don't change the `isInsideQuote` value.
                if isInsideQuote && (isEscaped piece (stringLength piece)) then
                  removeCommentsHelper pieces (n + 1) isInsideQuote (result ++ [ piece ])
                else if isInsideQuote || matchComment == null then
                  removeCommentsHelper pieces (n + 1) (!isInsideQuote) (result ++ [ piece ])
                else
                  result ++ [ (head matchComment) ]
              );
          # Removes the comment pieces from the line and concatenate it all
          # again using quotes as separators.
          removeComments = pieces: concatStringsSep "\"" (removeCommentsHelper pieces 0 false [ ]);
        in
        # Get the part of the line that does not contain the last quote piece.
        removeComments quotePieces;

      lines = filter isString (split "\n" string);
      linesNoComments = map stripCommentsFromLine lines;
    in
    concatStringsSep "\n" linesNoComments;

  parseField =
    str:
    let
      attrStringOrNull =
        let
          name = ''[a-zA-Z_][a-zA-Z0-9_\-]+'';
        in
        # Note: attribute names can be in the form of .attr_name or .@"attr-name"
        match ''^([[:space:]]*\.@?"?(${name})"?[[:space:]]*=[[:space:]]).*'' str;
      attrString =
        if attrStringOrNull == null then throw "Invalid attribute at ${str}" else attrStringOrNull;
      wholeMatch = elemAt attrString 0;
      name = elemAt attrString 1;

      inherit (parseValue (skipPrefix wholeMatch str)) value newStr;
    in
    {
      newStr = newStr;
      result = {
        ${name} = value;
      };
    };

  parseObjectArray =
    str: list:
    let
      matchedClose = match ''(^[[:space:]]*}).*'' str;
    in
    if matchedClose == null then
      let
        value = parseValue str;
        newStr = value.newStr;
        hasComma = match ''(^[[:space:]]*,).*'' newStr;
        newStr' = if hasComma != null then skipPrefix (head hasComma) newStr else newStr;
      in
      parseObjectArray newStr' (list ++ [ value.value ])
    else
      {
        value = list;
        newStr = skipPrefix (head matchedClose) str;
      };

  parseObjectAttrSet =
    str: value:
    let
      matchedClose = match ''(^[[:space:]]*}).*'' str;
    in
    if matchedClose != null then
      {
        inherit value;
        newStr = skipPrefix (head matchedClose) str;
      }
    else if startsWith "\\." str then
      let
        inherit (parseField str) newStr result;
        hasComma = match ''(^[[:space:]]*,).*'' newStr;
        newStr' = if hasComma != null then skipPrefix (head hasComma) newStr else newStr;
      in
      parseObjectAttrSet newStr' (value // result)
    else
      throw "Failed to parse object attribute set at ${str}";

  parseObject =
    str: if startsWith "\\." str then parseObjectAttrSet str { } else parseObjectArray str [ ];

  parseValue =
    str:
    let
      matchedString = match ''(^[[:space:]]*"([[:print:]]*)").*'' str;
      # TODO - make better number regex
      # TODO - parse numbers
      matchedNumber = match ''(^[[:space:]]*([0-9.]+)).*'' str;
      matchedObject = match ''(^[[:space:]]*\.\{).*'' str;
      matchedBool = match ''(^[[:space:]]*(true|false)).*'' str;
    in
    if matchedObject != null then
      parseObject (skipPrefix (head matchedObject) str)
    else if matchedString != null then
      {
        newStr = skipPrefix (head matchedString) str;
        value = elemAt matchedString 1;
      }
    else if matchedNumber != null then
      {
        newStr = skipPrefix (head matchedNumber) str;
        value = elemAt matchedNumber 1;
      }
    else if matchedBool != null then
      {
        newStr = skipPrefix (head matchedBool) str;
        value = if elemAt matchedBool 1 == "true" then true else false;
      }
    else
      throw "Unknown object value at ${str}";
in
(parseValue textWithoutComments).value
