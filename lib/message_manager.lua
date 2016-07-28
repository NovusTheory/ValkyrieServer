local Module      = {};
local MySQL       = require"lapis.db";
local AppHelpers  = require"lapis.application";
local Socket      = require"socket"; -- For time
local GameUtil    = require"lib.game_util";
local UserInfo    = require"lib.userinfo";

local YieldError  = AppHelpers.yield_error;

function Module.AddMessage(User, Message, GID)
  local Time    = math.floor(Socket.gettime());
  local Result  = MySQL.insert("messages", {
    sent        = Time,
    user        = UserInfo.RobloxToInternal(User),
    message     = Message,
    gid         = GameUtil.GIDToInternal(GID)
  });

  return nil;
end

function Module.CheckMessages(Since, Fresh, GIDFilter)
  if Fresh then
    return math.floor(Socket.gettime());
  end

  local Result  = MySQL.select("a.message as Message, a.sent as Sent, b.robloxid as User from messages a left join player_info b on a.user=b.id where sent > ? and gid=?", Since, GameUtil.GIDToInternal(GIDFilter));
  Result.Time   = math.floor(Socket.gettime());

  return Result;
end

return Module;
