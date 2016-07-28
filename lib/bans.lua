local Module      = {};
local MySQL       = require "lapis.db";
local Encoder     = Library("encode");
local PlayerInfo  = Library("userinfo");
local GameUtil    = Library("game_utils");

local YieldError = require"lapis.application".yield_error;

function Module.CreateBan(GID, Player, Reason, Meta)
    local Player = PlayerInfo.RobloxToInternal(Player);
  local BanExists = Module.IsBanned(Player, GID);
  if BanExists.result then
    YieldError("That user is already banned!");
  end

  MySQL.insert("bans", {
    player	      = Player;
    from_gid      = GID;
    reason        = Reason;
    meta          = Meta;
  });

  return ({success = true; error = ""});
end

function Module.IsBanned(Player, GID)
  local BanExists = MySQL.select("* from bans where player=?", PlayerInfo.RobloxToInternal(Player));
  if #BanExists > 0 then
    return ({success = true; error = ""; result = {true, BanExists[1].reason, BanExists[1].from_gid, "global"}});
  end

  local LocalBanExists = MySQL.select("* from local_bans where player=? and gid=?", PlayerInfo.RobloxToInternal(Player), GameUtil.GIDToInternal(GID));
  if #BanExists > 0 then
      return {success = true; error = ""; result = {true, BanExists[1].reason, BanExists[1].from_gid, "local"}};
  end
  return ({success = true; error = ""; result = {false}});
end

function Module.CreateGameBan(GID, Player, Reason)
  local Player = PlayerInfo.RobloxToInternal(Player);
  local BanExists = Module.IsBanned(Player, GID);
  if BanExists.result then
    YieldError("That user is already banned!");
  end

  MySQL.insert("local_bans", {
      player = Player;
      gid = GameUtil.GIDToInternal(GID);
      reason = Reason
  });

  return {success = true; error = ""};
end

function Module.RemoveGameBan(GID, Player)
  if not Module.IsBanned(Player, GID).result then
      YieldError("That user is not banned!");
  end

  MySQL.delete("local_bans", {
    player = Player;
    gid = GameUtil.GIDToInternal(GID);
  });

  return {success = true; error = ""};
end

return Module;
