local Module     = {};
local MySQL      = require "lapis.db";
local GIDTable   = Library "gid_table";
local AppHelpers = require"lapis.application";

local YieldError = AppHelpers.yield_error;

function Module.Check(GID, CoKey, UID)
  local GameIDResult  = MySQL.select("id from game_ids where gid=? and cokey=md5(?)", GID, CoKey); -- Don't worry, Lapis will escape the strings
  if #GameIDResult < 1 then
    YieldError("Invalid UID-GID-CoKey combination!");
  end

  local UserIDResult = MySQL.select("id from ? where uid=? and connection_key=md5(?)", gid_table("trusted_users", GID), UID, CoKey);
  if #UserIDResult < 1 then
    YieldError("Invalid UID-CoKey-GID combination!");
  end

  return ({success = true, error = "", result = true});
end

function Module.CheckNoUID(gid, cokey)
  local GameIDResult  = MySQL.select("id from game_ids where gid=? and cokey=md5(?)", GID, CoKey);
  if #GameIDResult < 1 then
    YieldError("Invalid GID-CoKey pair!");
  end

  return {success = true, error = "", result = true};
end

return Module;
