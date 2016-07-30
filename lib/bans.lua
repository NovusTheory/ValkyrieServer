local Module      = {};
local MySQL       = require "lapis.db";
local PlayerInfo  = require("lib.userinfo");
local GameUtil    = require("lib.game_utils");

local YieldError = require"lapis.application".yield_error;

function Module.CreateBan(GID, Player, Reason, Meta)
  local BanExists = Module.IsBanned(Player, GID);
  if BanExists.IsBanned then
    YieldError("That user is already banned!");
  end

  MySQL.insert("bans", {
    player	      = PlayerInfo.RobloxToInternal(Player);
    from_gid      = GameUtil.GIDToInternal(GID);
    reason        = Reason;
    meta          = Meta;
    global        = 1;
  });

  return nil;
end

function Module.IsBanned(Player, GID)
  local BanExists = MySQL.select("a.reason as reason, b.gid as from_gid, if(a.global=1,'global','local') as type, a.meta from bans a left join game_ids b on a.from_gid=b.id where player=? and (global=1 or from_gid=?)", PlayerInfo.RobloxToInternal(Player), GameUtil.GIDToInternal(GID));
  if #BanExists > 0 then
    return {IsBanned = true, Reason = BanExists[1].reason, GID = BanExists[1].from_gid, Type = BanExists[1].type, Meta = BanExists[1].meta};
  end

  return {IsBanned = false};
end

function Module.CreateGameBan(GID, Player, Reason)
  local BanExists = Module.IsBanned(Player, GID);
  if BanExists.IsBanned then
    YieldError("That user is already banned!");
  end

  MySQL.insert("bans", {
      player = PlayerInfo.RobloxToInternal(Player);
      from_gid = GameUtil.GIDToInternal(GID);
      reason = Reason;
      global = 0;
  });

  return nil;
end

function Module.RemoveGameBan(GID, Player)
    local IsBanned = Module.IsBanned(Player, GID);
  if not IsBanned.IsBanned or IsBanned.Type ~= "local" then
      YieldError("That user is not banned!");
  end

  MySQL.delete("bans", {
    player = PlayerInfo.RobloxToInternal(Player);
    from_gid = GameUtil.GIDToInternal(GID);
    global = 0;
  });

  return nil;
end

return Module;
