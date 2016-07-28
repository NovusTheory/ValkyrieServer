local Module      = {};
local MySQL       = require "lapis.db";
local Encoder     = require("lib.encode");
local PlayerInfo  = require("lib.userinfo");

local YieldError = require"lapis.application".yield_error;

function Module.CreateBan(GID, Player, Reason)
    local Player = PlayerInfo.RobloxToInternal(Player);
  local BanExists = mysql.select("id from bans where player=?", Player);
  if #BanExists > 0 then
    YieldError("That user is already banned!");
  end

  MySQL.insert("bans", {
    player	  = Player;
    from_gid      = GID;
    reason        = Reason;
  });

  return ({success = true; error = ""});
end

function Module.IsBanned(Player)
  local BanExists = mysql.select("* from bans where player=?", PlayerInfo.RobloxToInternal(Player));
  if #BanExists > 0 then
    return ({success = true; error = ""; result = {true, BanExists[1].reason, BanExists[1].from_gid}});
  end
  return ({success = true; error = ""; result = {false}});
end

return Module;
