local module      = {};
local encoder     = library("encode");
local meta        = library("meta");
local yield_error = require"lapis.application".yield_error;
local lfs         = require("lfs");

local function round(x)
  return math.ceil(x - .4);
end

local function setInaccurate(str, unit, bytes)
  local num       = tonumber(str:sub(1, str:find(" ") - 1));
  if round(num) * 1024 ^ unit ~= round(bytes) then
    return "~" .. str;
  end
  return str;
end

local function properDataRep(bytes)
  if bytes / 1024 ^ 3 >= 1 then -- Should never be the case
    return setInaccurate(("%.3f GiB"):format(bytes / 1024 ^ 3), 3, bytes);
  elseif bytes / 1024 ^ 2 >= 1 then
    return setInaccurate(("%.3f MiB"):format(bytes / 1024 ^ 2), 2, bytes);
  elseif bytes / 1024 >= 1 then
    return setInaccurate(("%.3f KiB"):format(bytes / 1024), 1, bytes);
  else
    return ("%d B"):format(bytes);
  end
end

local function safeMkdir(name)
  name                = name:gsub("'", "\\'");
  local value = os.execute("mkdir -p '" .. name .. "'");
  if value ~= 0 then
    yield_error("mkdir failed with code " .. value);
  end
end

function module.saveData(gid, key, value)
  local usedspc = meta.getMeta("usedSpace", gid);
  local limit   = 1024 * 1024 * 10 - usedspc; -- Give them 10 MiB of space

  if gid:find("%.") or key:find("%.") then
    yield_error("Nice try, you dirty injector! (GID or key can't contain a .)");
  end

  local oldfile     = io.open(("ds/%s/%s.ds"):format(gid, key), "r");
  local oldfilesize = 0;
  if oldfile then
    oldfilesize = oldfile:read("*all"):len();
  end
  local netchange   = oldfilesize - value:len();

  if limit < usedspc - netchange then
    yield_error("You're trying to use too much space! You only have " .. properDataRep(limit) .. " left!");
  end

  safeMkdir(("ds/%s/%s.ds"):format(gid, key):gsub("%w-%.ds", ""));
  local file, err, num = io.open(("ds/%s/%s.ds"):format(gid, key), "w");
  if not file then
    yield_error(err);
  end
  file:write(value);
  meta.setMeta("usedSpace", usedspc - netchange, gid);

  return encoder.encode({success = true; error = ""});
end

function module.loadData(gid, key)
  if gid:find("%.") or key:find("%.") then
    yield_error("Nice try, you dirty injector! (GID or key can't contain a .)");
  end

  local file, err, num = io.open(("ds/%s/%s.ds"):format(gid, key), "r");
  if not file then
    yield_error(err);
  end

  return encoder.encode({success = true; error = ""; result = file:read("*all")});
end

function module.getSpace(gid)
  local usedspc = meta.getMeta("usedSpace", gid);
  local limit   = 1024 * 1024 * 10 - usedspc;

  return encoder.encode({success = true; error = ""; result = {{"10 MiB"; properDataRep(limit); properDataRep(usedspc)}, {1024 * 1024 * 10, limit, tonumber(usedspc)}}});
end

local function getDirectoryRecursively(tbl, path, ignore)
  print(path);
  for file in lfs.dir(path) do
    if lfs.attributes(path .. "/" .. tostring(file), "mode") == "file" then
      table.insert(tbl, ({
          (
            path .. tostring(file)
          ):gsub(ignore, "", 1):gsub("%.ds", "")
        })[1]);
    elseif tostring(file) ~= ".." and tostring(file) ~= "." then
      tbl = getDirectoryRecursively(tbl, (path:sub(path:len()) == "/" and path:sub(1, path:len() - 1) or path) .. "/" .. tostring(file) .. "/", ignore);
    end
  end

  return tbl;
end

function module.listKeys(gid)
  if gid:find("%.") then
    yield_error("Nice try, you dirty injector! (Gid can't contain a .)");
  end

  return encoder.encode({success = true; error = ""; result = getDirectoryRecursively({}, ("ds/%s"):format(gid), ("ds/%s/?"):format(gid))});
end

return module;
