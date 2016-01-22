local module      = {};
local app_helpers = require"lapis.application";

local yield_error = app_helpers.yield_error;

local createArray;

local function createString(str)
  local ret = str:gsub("\\", "\\\\");
  ret       = ret:gsub("\"", "\\\"");

  return "\"" .. ret .. "\"";
end

local function createValues(arr, assoc)
  local ret     = "";
  local delim   = assoc and ";" or ",";

  for i, v in pairs(arr) do
    if assoc then
      ret = ret .. i .. "=";
    end
    if type(v) == "number" or type(v) == "boolean" then
      ret = ret .. tostring(v);
    elseif type(v) == "string" then
      ret = ret .. createString(v);
    elseif type(v) == "table" then
      ret = ret .. createArray(v);
    end
    ret = ret .. delim;
  end

  if ret:sub(#ret) == delim then
    ret = ret:sub(1, #ret - 1);
  end

  return ret;
end

createArray = function(arr)
  local ret = "[";
  ret = ret .. createValues(arr, false);
  return ret .. "]";
end

function module.encode(arr)
  return createValues(arr, true);
end

return module;
