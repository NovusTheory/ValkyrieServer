local Module     = {};
local MySQL      = require "lapis.db";
local GIDTable   = Library "gid_table";
local AppHelpers = require"lapis.application";

local YieldError = AppHelpers.yield_error;

function Module.Check(GID, CoKey, UID)
  local GameIDResult  = MySQL.select("id from game_ids where gid=? and (uses_md5=1 and cokey=md5(?) or cokey=sha2(?, 256))", GID, CoKey, CoKey); -- Don't worry, Lapis will escape the strings
  if #GameIDResult < 1 then
    YieldError("Invalid UID-GID-CoKey combination!");
  end

  local UserIDResult = MySQL.select("id from trusted_users where uid=? and gid=? and (uses_md5=1 and connection_key=md5(?) or connection_key=sha2(?, 256))", UID, GID, CoKey, CoKey);
  if #UserIDResult < 1 then
    YieldError("Invalid UID-CoKey-GID combination!");
  end

  return ({success = true, error = "", result = true});
end

function Module.CheckNoUID(gid, cokey)
  local GameIDResult  = MySQL.select("id from game_ids where gid=? and (uses_md5=1 and cokey=md5(?) or cokey=sha2(?, 256))", GID, CoKey, CoKey);
  if #GameIDResult < 1 then
    YieldError("Invalid GID-CoKey pair!");
  end

  return {success = true, error = "", result = true};
end

return Module;
