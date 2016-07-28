local Module                = {};
local MySQL                 = require"lapis.db";
local AppHelpers            = require"lapis.application";
local HTTP                  = require("socket.http");
local Socket                = require("socket");
local JSON                  = require("cjson");
local Meta                  = Library("meta");
local Friends               = Library("friends");

local YieldError           = AppHelpers.yield_error;

local function GetGeneralInfo(ID)
  local Result              = {};
  local IsPlayerInGame      = MySQL.select("b.gid from player_ingame a left join game_ids b on a.gid=b.id left join player_info c on a.player=c.id where c.robloxid=?", id);
  local OtherInfo           = HTTP.request(("https://api.roblox.com/users/%d"):format(ID));
  OtherInfo                 = JSON.decode(OtherInfo);
  local Online              = #IsPlayerInGame > 0;
  local GameName            = nil;

  if Online then
    GameName                = Meta.GetMeta("name", IsPlayerInGame[1].gid);
  end

  return {ID = OtherInfo.Id; Username = OtherInfo.Username; IsInGame = Online; Game = Online and IsPlayerInGame[1].gid or nil; GameName = GameName};
end

local function FixDate(Date, Difference)
  Date                      = Date:gsub("(%d-)y", function(a) return " " .. tostring(tonumber(a) - 1970) .. "y"; end);
  Date                      = Date:gsub("(%d-)([md]) ", function(a, b) return tostring(tonumber(a) - 1) .. b .. " "; end);
  --Date                    = Date:gsub("(%d-)h", function(a) return tostring(tonumber(a) - 2) .. "h"; end);
  Date                      = Date:gsub("(%d-)(%a+)", "%1%2 ");
  Date                      = Date:gsub(" 0+%a+", "");
  Date                      = Date:gsub(" 0+", "");
  Date                      = Date:gsub("^ ", ""):gsub(" $", "");
  if Date:sub(1, 1) == " " then
    return Date:sub(2);
  end

  if Date                   == "" then
    if Difference then
      return "N/A";
    end
    return "just now";
  end

  return Date;
end

local function GetPlayTimes(id)
  local Result              = {HumanReadable = {}, Numeric = {}};
  local UserInfoResult      = MySQL.select("sum(time_ingame) as time_ingame, min(joined) as joined sum(num_sessions) as num_sessions, max(last_online) as last_left, min(last_online) = 0 as internal_still_online from player_sessions where player=?", Module.RobloxToInternal(id));

  local Row                 = UserInfoResult[1];
  if Row then
    Result.Numeric          = {TotalTime = Row.time_ingame, Joined = Row.joined, LastSeen = Row.last_online, Sessions = Row.num_sessions};
    Result.HumanReadable   = {
        TotalTime = FixDate(os.date("%Yy %mm %dd %Hh %Mmin", Row.time_ingame), true);
        Joined = FixDate(os.date("%Yy %mm %dd", math.floor(Socket.gettime()) - Row.joined));
        LastSeen = FixDate(os.date("%Yy %mm %dd %Hh %Mmin", Row.internal_still_online == 1 and 0 or math.floor(Socket.gettime()) - Row.last_left))
        Sessions = Row.num_sessions;
    };
  else
    Result = {HumanReadable = {"N/A","N/A","N/A", "N/A"}, Numeric = {-1, -1, -1, -1}};
  end

  return Result;
end

function Module.TryCreateUser(ID)
  local DoesPlayerExist     = MySQL.select("id from player_info where robloxid=?", ID);
  if #DoesPlayerExist < 1 then
    MySQL.insert("player_info", {
      robloxid              = ID;
    });
  end

  return nil;
end

function Module.GetUserInfo(ID)
  local Result              = {};

  Result.Time = math.floor(Socket.gettime());

  Result.GeneralInfo = GetGeneralInfo(ID);
  Result.PlayTimes = GetPlayTimes(ID);

  local Achievements        = MySQL.select("c.achv_id as AchievementID, c.name as Name, c.description as Description, c.reward as Reward, c.icon as Icon, b.gid as GID, d.value as GameName from awarded_achv a left join game_ids b on a.gid=b.id left join achievements c on a.achv_id=c.id left join meta d on d.`key`='name' and b.id=d.gid where player=?", Module.RobloxToInternal(ID));
  Result.Achievements = Achievements;

  local TotalReward         = MySQL.select("sum(b.reward) as reward from awarded_achv a left join achievements b on a.achv_id=b.id where player=?", Module.RobloxToInternal(ID))[1].reward;
  Result.TotalReward = TotalReward;

  Result.Friends =  Friends.GetFriends(ID);

  return Result;
end

function Module.RobloxToInternal(RobloxID)
    local Result = MySQL.select("id from player_info where robloxid=?", RobloxID);
    if #Result < 1 then
        YieldError("Player R#" .. RobloxID .. " does not exist!");
    end

    return Result[1].id;
end

return Module;
