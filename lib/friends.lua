local Module     = {};
local MySQL      = require"lapis.db";
local AppHelpers = require"lapis.application";
local HTTP       = require("socket.http");
local JSON       = require("cjson");
local UserInfo   = Library("userinfo");
local GameUtils  = Library("game_utils");
local Socket     = require("socket");

local YieldError = AppHelpers.yield_error;

function Module.GetFriends(ID)
  local Result        = {};
  local Friends       = HTTP.request(("https://api.roblox.com/users/%d/friends"):format(ID));
  local PlayerIDs     = {};
  for i = 1, #Friends do
      table.insert(PlayerIDs, value.Id);
  end
  local IsInGame   = MySQL.select("a.player as player, b.gid as gid from player_ingame a where a.player in (?) left join game_ids b where gid=a.gid", MySQL.raw(table.concat(PlayerIDs, ", ")));
  Friends             = JSON.decode(Friends);

  for Index, Value in next, Friends do
    table.insert(Result, {value.Id; value.Username; IsInGame[value.Id] and true or false; IsInGame[value.Id]});
  end

  return {success = true, error = "", result = Result};
end

function Module.SetOnlineGame(ID, GID, Name)
  Userinfo.TryCreateUser(ID);

  local DoesExist    = MySQL.select("gid from player_ingame where player=?", ID);
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

  local PlayerInfoExists = MySQL.select("gid from player_sessions where player=? and gid=?", ID, GameUtils.GIDToInternal(GID));

  if #PlayerInfoExists < 1 then
    MySQL.insert("player_sessions", {
        player           = UserInfo.RobloxToInternal(ID);
        time_ingame      = 0;
        joined           = math.floor(Socket.gettime());
        last_online      = 0;
        num_sessions     = 0;
        gid              = GameUtils.GIDToInternal(GID);
    });
  else
    MySQL.update("player_sessions", {
        last_online      = 0;
    }, {
        player           = ID;
        gid              = GameUtils.GIDToInternal(GID);
    });
  end

  return {success = true, error = ""};
end

function Module.GoOffline(ID, TimeIngame, GID)
  MySQL.delete("player_ingame", {
    player           = ID;
  });
  MySQL.update("player_sessions", {
    last_online      = math.floor(Socket.gettime());
    time_ingame      = MySQL.raw(("time_ingame+%d"):format(TimeIngame));
    num_sessions     = MySQL.raw("num_sessions+1");
  }, {
    player           = UserInfo.RobloxToInternal(ID);
    GID              = GameUtils.GIDToInternal(GID);
  });

  return {success = true, error = ""};
end

return Module;
