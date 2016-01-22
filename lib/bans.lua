local module      = {};
local mysql       = require "lapis.db";
local encoder     = library("encode");

local yield_error = require"lapis.application".yield_error;

function module.createBan(gid, player, reason)
  local exists_result = mysql.select("id from bans where player=?", player);
  if #exists_result > 0 then
    yield_error("That user is already banned!");
  end

  mysql.insert("bans", {
    player	  = player;
    from_gid      = gid;
    reason        = reason;
  });

  return encoder.encode({success = true; error = ""});
end

function module.isBanned(player)
  local exists_result = mysql.select("* from bans where player=?", player);
  if #exists_result > 0 then
    return encoder.encode({success = true; error = ""; result = {true, exists_result[1].reason, exists_result[1].from_gid}});
  end
  return encoder.encode({success = true; error = ""; result = {false}});
end

return module;
