local Module      = {};
local MySQL       = require"lapis.db";
local AppHelpers  = require"lapis.application";
local Socket      = require"socket"; -- For time
local GameUtil    = Library"game_util";
local UserInfo    = Library"userinfo";

local YieldError  = AppHelpers.yield_error;

function Module.AddMessage(User, Message, GID)
  local Time    = math.floor(Socket.gettime());
  local Result  = MySQL.insert("messages", {
    sent        = Time,
    user        = UserInfo.RobloxToInternal(User),
    message     = Message,
    gid         = GID
  });

  return {success = true, error = ""};
end

function Module.CheckMessages(Since, Fresh, GIDFilter)
  if Fresh then
    return {success = true, error = "", result = math.floor(Socket.gettime())};
  end

  local Result  = MySQL.select("message, sent, user from messages where sent > ? and gid=?", Since, GIDFilter);
  local Return  = {math.floor(Socket.gettime())};
  for i = 1, #Result do
    table.insert(Return, Result[i]);
  end

  return {success = true, error = "", result = Result};
end

return Module;
