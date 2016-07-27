local Module        = {};
local MySQL         = require"lapis.db";
local AppHelpers    = require"lapis.application";
local GameUtils     = Library"game_utils";

local YiedError     = AppHelpers.yield_error;

function Module.GetMeta(Key, GID)
  local Result      = MySQL.select("value from meta where `key`=? and gid=?", Key, GameUtils.GIDToInternal(GID));

  if #Result == 0 then
    error("Invalid meta key!");
  end

  return Result[1].value;
end

function Module.SetMeta(Key, Value, GID)
    local IsUnique    = MySQL.select("value from meta where `key`=? and gid=?", Key, GameUtils.GIDToInternal(GID));

  if #IsUnique == 0 then
    MySQL.insert("meta", {
      key           = Key;
      value         = Value;
      gid           = GID;
    });
  else
    MySQL.update("meta", {
      value         = Value;
    }, {
      key           = Key;
      gid           = GID;
    });
  end
end

return Module;
