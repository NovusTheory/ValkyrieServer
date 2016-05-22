local Module     = {};
local MySQL      = require"lapis.db";
local Encoder    = Library("encode");
local AppHelpers = require"lapis.application";
local HTTP       = require("socket.http");
local JSON       = require("cjson");
local UserInfo   = Library("userinfo");
local Socket     = require("socket");

local YieldError = AppHelpers.yield_error;

function Module.GetFriends(ID)
  local Result        = {};
  local IsInGame   = MySQL.select("gid, player from player_ingame");
  local Friends       = HTTP.request(("https://api.roblox.com/users/%d/friends"):format(ID));
  Friends             = JSON.decode(Friends);

  for Index, Value in next, Friends do
    table.insert(Result, {value.Id; value.Username; IsInGame[value.Id] and true or false; IsInGame[value.Id]});
  end

  return ({success = true, error = "", result = Result});
end

function Module.SetOnlineGame(ID, GID, Name)
  local DoesExist    = MySQL.select("gid from player_ingame where player=?", ID);
  if #DoesExist < 1 then
    MySQL.insert("player_ingame", {
      player          = ID;
      gid             = GID;
      name            = Name;
    });
  else
    MySQL.update("player_ingame", {
      player           = ID;
      gid              = GID;
      name             = Name;
    }, {
      player           = ID;
    });
  end

  Userinfo.TryCreateUser(ID);

  MySQL.update("player_info", {
    last_online      = 0;
  }, {
    player           = ID;
  });

  return ({success = true, error = ""});
end

function Module.GoOffline(ID, TimeIngame)
  MySQL.delete("player_ingame", {
    player           = ID;
  });
  MySQL.update("player_info", {
    last_online      = math.floor(Socket.gettime());
    time_ingame      = MySQL.raw(("time_ingame+%d"):format(TimeIngame));
  }, {
    player           = ID;
  });

  return ({success = true, error = ""})
end

return Module;
