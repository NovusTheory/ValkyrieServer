local Module     = {};
local MySQL      = require"lapis.db";
local AppHelpers = require"lapis.application";
local HTTP       = require("socket.http");
local JSON       = require("cjson");
local UserInfo   = require("lib.userinfo");
local GameUtils  = require("lib.game_utils");
local Socket     = require("socket");
local RealSecret = require"lapis.config".get().APISecret;

local YieldError = AppHelpers.yield_error;

function Module.GetFriends(ID)
  local Result        = {};
  local Friends       = HTTP.request(("https://api.roblox.com/users/%d/friends"):format(ID));
  local PlayerIDs     = {};
  Friends             = JSON.decode(Friends);
  for i = 1, #Friends do
      table.insert(PlayerIDs, Friends[i].Id);
  end
  local IsInGame      = {};
  local FriendsInGame = MySQL.select("select c.robloxid as player, b.gid as gid from player_ingame a left join game_ids b on b.id=a.gid left join player_info c on c.id=a.player where c.robloxid in (?);", MySQL.raw(table.concat(PlayerIDs, ", ")));
  for i = 1, #FriendsInGame do
      IsInGame[FriendsInGame[i].player] = FriendsInGame[i].gid;
  end

  for Index, Value in next, Friends do
    table.insert(Result, {ID = value.Id; Username = value.Username; IsInGame = IsInGame[value.Id] and true or false; Game = IsInGame[value.Id]});
  end

  return Result;
end

function Module.SetOnlineGame(ID, GID, Secret)
  assert(Secret == RealSecret, "You forgot the magic word!");
  UserInfo.TryCreateUser(ID);

  local DoesExist    = MySQL.select("gid from player_ingame where player=?", UserInfo.RobloxToInternal(ID));
  if #DoesExist < 1 then
    MySQL.insert("player_ingame", {
      player          = UserInfo.RobloxToInternal(ID);
      gid             = GameUtils.GIDToInternal(GID);
    });
  else
    MySQL.update("player_ingame", {
      gid             = GameUtils.GIDToInternal(GID);
    }, {
      player          = UserInfo.RobloxToInternal(ID);
    });
  end

  local PlayerInfoExists = MySQL.select("gid from player_sessions where player=? and gid=?", UserInfo.RobloxToInternal(ID), GameUtils.GIDToInternal(GID));

  if #PlayerInfoExists < 1 then
    MySQL.insert("player_sessions", {
        player           = UserInfo.RobloxToInternal(ID);
        time_ingame      = 0;
        joined           = math.floor(Socket.gettime());
        last_online      = 0;
        num_sessions     = 1;
        gid              = GameUtils.GIDToInternal(GID);
    });
  else
    MySQL.update("player_sessions", {
        last_online      = 0;
        num_sessions     = MySQL.raw("num_sessions+1");
    }, {
        player           = UserInfo.RobloxToInternal(ID);
        gid              = GameUtils.GIDToInternal(GID);
    });
  end

  return nil;
end

function Module.PingOnline(ID, GID, Secret)
  assert(Secret == RealSecret, "You forgot the magic word!");
    MySQL.update("player_ingame", {last_updated = MySQL.raw("current_timestamp")}, {player = UserInfo.RobloxToInternal(ID)});
  MySQL.update("player_sessions", {
    time_ingame      = MySQL.raw("time_ingame+60");
  }, {
    player           = UserInfo.RobloxToInternal(ID);
    GID              = GameUtils.GIDToInternal(GID);
  });
end

function Module.GoOffline(ID, GID, Secret)
  assert(Secret == RealSecret, "You forgot the magic word!");
  MySQL.delete("player_ingame", {
    player           = UserInfo.RobloxToInternal(ID);
  });
  MySQL.update("player_sessions", {
    last_online      = math.floor(Socket.gettime());
  }, {
    player           = UserInfo.RobloxToInternal(ID);
    gid              = GameUtils.GIDToInternal(GID);
  });

  return nil;
end

return Module;
