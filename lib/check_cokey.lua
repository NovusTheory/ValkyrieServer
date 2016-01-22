local module      = {};
local mysql       = require "lapis.db";
local encoder     = library("encode");
local gid_table   = library "gid_table";
local app_helpers = require"lapis.application";

local yield_error = app_helpers.yield_error;

function module.check(gid, cokey, uid)
  local game_id_result  = mysql.select("id from game_ids where gid=? and cokey=md5(?)", gid, cokey); -- Don't worry, Lapis will escape the strings
  if #game_id_result < 1 then
    yield_error("Invalid UID-GID-CoKey combination!");
  end

  local user_id_result = mysql.select("id from ? where uid=? and connection_key=md5(?)", gid_table("trusted_users", gid), uid, cokey);
  if #user_id_result < 1 then
    yield_error("Invalid UID-CoKey-GID combination!");
  end

  return encoder.encode({success = true, error = ""});
end

function module.check_nouid(gid, cokey)
  local game_id_result  = mysql.select("id from game_ids where gid=? and cokey=md5(?)", gid, cokey);
  if #game_id_result < 1 then
    yield_error("Invalid GID-CoKey pair!");
  end

  return "success=true;error=\"\"";
end

return module;
