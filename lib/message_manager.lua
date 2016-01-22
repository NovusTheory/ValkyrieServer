local module      = {};
local mysql       = require"lapis.db";
local encoder     = library("encode");
local app_helpers = require"lapis.application";
local socket      = require"socket"; -- For time

local yield_error = app_helpers.yield_error;

function module.addMessage(user, message, gid)
  local time    = math.floor(socket.gettime());
  local result  = mysql.insert("messages", {
    sent        = time,
    user        = user,
    message     = message,
    gid         = gid
  });

  return encoder.encode({success = true, error = ""});
end

function module.checkMessages(since, fresh, gidfilter)
  if fresh then
    return encoder.encode({success = true, error = "", result = math.floor(socket.gettime())});
  end

  local result  = mysql.select("message, sent, user from messages where sent > ? and gid=?", since, gidfilter);
  local ret     = {math.floor(socket.gettime())};
  for i = 1, #result do
    table.insert(ret, result[i]);
  end

  return encoder.encode({success = true, error = "", result = ret});
end

return module;
