local Module      = {};
local Meta        = Library("meta");
local YieldError = require"lapis.application".yield_error;
local LFS         = require("lfs");

local function Round(x)
  return math.ceil(x - .4);
end

local function SetInaccurate(Representation, Unit, Bytes)
  local Number    = tonumber(Representation:sub(1, Representation:find(" ") - 1));
  if Round(Number) * 1024 ^ Unit ~= Round(Bytes) then
    return "~" .. Representation;
  end
  return Representation;
end

local function ProperDataRepresentation(Bytes)
  if Bytes / 1024 ^ 3 >= 1 then -- Should never be the case
    return SetInaccurate(("%.3f GiB"):format(Bytes / 1024 ^ 3), 3, Bytes);
  elseif Bytes / 1024 ^ 2 >= 1 then
    return SetInaccurate(("%.3f MiB"):format(Bytes / 1024 ^ 2), 2, Bytes);
  elseif Bytes / 1024 >= 1 then
    return SetInaccurate(("%.3f KiB"):format(Bytes / 1024), 1, Bytes);
  else
    return ("%d B"):format(Bytes);
  end
end

local function SafeMKDir(Name)
  Name                = Name:gsub("'", "\\'");
  local Value = os.execute("mkdir -p '" .. Name .. "'");
  if Value ~= 0 then
    YieldError("mkdir failed with code " .. Value);
  end
end

function Module.SaveData(GID, Key, Value)
  local UsedSpace = Meta.GetMeta("usedSpace", GID);
  local Limit   = 1024 * 1024 * 10 - UsedSpace; -- Give them 10 MiB of space

  if GID:find("%.") or Key:find("%.") then
    YieldError("Nice try, you dirty injector! (GID or key can't contain a .)");
  end

  local OldFile     = io.open(("ds/%s/%s.ds"):format(gid, Key), "r");
  local OldFileSize = 0;
  if OldFile then
    OldFileSize = OldFile:read("*all"):len();
  end
  local Change     = OldFileSize - Value:len();

  if Limit < UsedSpace - Change then
    YieldError("You're trying to use too much space! You only have " .. ProperDataRepresentation(Limit) .. " left!");
  end

  SafeMKDir(("ds/%s/%s.ds"):format(GID, Key):gsub("%w-%.ds", ""));
  local File, Error = io.open(("ds/%s/%s.ds"):format(GID, Key), "w");
  if not File then
    YieldError(Error);
  end
  file:write(Value);
  Meta.SetMeta("usedSpace", UsedSpace - Change, GID);

  return ({success = true; error = ""});
end

function Module.LoadData(GID, Key)
  if GID:find("%.") or Key:find("%.") then
    YieldError("Nice try, you dirty injector! (GID or key can't contain a .)");
  end

  local File, Error = io.open(("ds/%s/%s.ds"):format(GID, Key), "r");
  if not File then
    YieldError(Error);
  end

  return ({success = true; error = ""; result = File:read("*all")});
end

function Module.GetSpace(gid)
  local UsedSpace = Meta.GetMeta("usedSpace", GID);
  local Limit   = 1024 * 1024 * 10 - UsedSpace;

  return ({success = true; error = ""; result = {{"10 MiB"; ProperDataRepresentation(Limit); ProperDataRepresentation(usedspc)}, {1024 * 1024 * 10, Limit, tonumber(UsedSpace)}}});
end

local function GetDirectoryRecursively(Table, Path, Ignore)
  for file in LFS.dir(Path) do
    if LFS.attributes(Path .. "/" .. tostring(File), "mode") == "file" then
      table.insert(Table, ({
          (
            Path .. tostring(File)
          ):gsub(Ignore, "", 1):gsub("%.ds", "")
        })[1]);
    elseif tostring(File) ~= ".." and tostring(File) ~= "." then
      Table = GetDirectoryRecursively(Table, (Path:sub(Path:len()) == "/" and Path:sub(1, Path:len() - 1) or Path) .. "/" .. tostring(File) .. "/", Ignore);
    end
  end

  return Table;
end

function Module.ListKeys(GID)
  if GID:find("%.") then
    YieldError("Nice try, you dirty injector! (Gid can't contain a .)");
  end

  return ({success = true; error = ""; result = GetDirectoryRecursively({}, ("ds/%s"):format(GID), ("ds/%s/?"):format(GID))});
end

return Module;
