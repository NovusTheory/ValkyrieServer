local module  = {};

local parseArray;

local function isNum(str)
  return tonumber(str) ~= nil;
end

-- The following two: http://stackoverflow.com/questions/20282054/how-to-urldecode-a-request-uri-string-in-lua#answer-20282998
local hex_to_char = function(x)
  return string.char(tonumber(x, 16))
end

local unescape = function(url)
  return url:gsub("%%(%x%x)", hex_to_char)
end

local function split(str, delim)
  local isEscape    = false;
  local isInString  = false;
  local isInArray   = false;
  local arrayLevel  = 0;
  local ret         = {};
  local buf         = "";
  for i = 1, #str do
    if str:sub(i, i) == "\\" then
      isEscape      = not isEscape;
    elseif str:sub(i, i) == "\"" and not isEscape then
      isInString    = not isInString;
    elseif str:sub(i, i) == "[" and not isInString then
      isInArray     = true;
      arrayLevel    = arrayLevel + 1;
    elseif str:sub(i, i) == "]" and not isInString then
      arrayLevel    = arrayLevel - 1;
      if arrayLevel < 1 then
        isInArray   = false;
      end
    elseif str:sub(i, i) == delim and not isInString and not isInArray then
      table.insert(ret, buf);
      buf = "";
    end
    if str:sub(i, i) ~= delim or isInString or isInArray then
      isEscape      = false;
      buf           = buf .. str:sub(i, i);
    end
  end

  if buf ~= "" then
    table.insert(ret, buf);
  end

  return ret;
end

local function keyval(str)
  return unpack(split(str, "="));
end

local function getType(str)
  if isNum(str)             then return "number";   end
  if str:sub(1, 1) == "\""  then return "string";   end
  if str:sub(1, 1) == "["   then return "array";    end
  if str:sub(1, 1) == "t"
  or str:sub(1, 1) == "f"   then return "boolean";  end

  return "unknown";
end

local function parseString(str)
  local ret   = "";
  local escon = false;
  local str   = str:sub(2, #str - 1);
  for i = 1, #str do
    local currChar = str:sub(i, i);
    if currChar == "\\" and not escon then
      escon = true;
    else
      ret = ret .. currChar;
    end
  end

  return ret;
end

local function parseValues(values, useKeyVal)
  local i = 1;
  local key, value;
  local ret = {};
  for _, v in next, values do
    if useKeyVal then
      key, value = keyval(v);
    else
      key, value = i, v;
      i = i + 1;
    end
    local _type = getType(value);

    if      _type == "number"   then
      ret[key]    = tonumber(value);
    elseif  _type == "string"   then -- string
      ret[key]    = parseString(value);
    elseif  _type == "array"    then -- array
      ret[key]    = parseArray(value);
    elseif  _type == "boolean"  then
      if value == "true" then
        ret[key]  = true;
      else
        ret[key]  = false;
      end
    end
  end
  return ret;
end

parseArray = function(str)
  local str     = str:sub(2, #str - 1); -- strip surrounding []
  local values  = split(str, ",");

  return parseValues(values, false);
end

function module.parse(str)
  if not str or str == "" then
    return {};
  end
  local ret       = {};
  local values    = split(unescape(str), ";");

  return parseValues(values, true);
end

return module;
