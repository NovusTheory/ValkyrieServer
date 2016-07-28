local Module      = {};
local MySQL       = require "lapis.db";
local MetaManager = Library("meta");
local PlayerInfo  = Library("userinfo");
local AppHelpers  = require"lapis.application";

local YieldError  = app_helpers.yield_error;

function Module.Create(GID, ID, Description, Name, Reward, Icon)
    local GID = MySQL.select("id from game_ids where gid=?", GID)[1].id;
  if tonumber(Reward) < 1 then
    YieldError("The reward can't be less than 1!");
  end

  local IsUnique       = MySQL.select("id from achievements where achv_id=? and gid=?", ID, GID); -- Achievements do not need to be unique across games

  if #IsUnique ~= 0 then
    YieldError("An achievement with that ID already exists!");
  end

  local UsedReward        = MetaManager.GetMeta("usedreward", GID);
  local MaxReward         = 1000 - UsedReward;

  if MaxReward < tonumber(Reward) then
    YieldError("The reward exceeds the maximum available reward (" .. MaxReward .. ")!");
  end
  MetaManager.SetMeta("usedreward", UsedReward + Reward, GID);

  MySQL.insert("achievements", {
        achv_id           = ID,
        description       = Description,
        name              = Name,
        reward            = Reward,
        icon              = Icon,
        gid               = GID
    });

  return nil;
end

function Module.Award(GID, PlayerID, AchievementID)
    local GID = MySQL.select("id from game_ids where gid=?", GID)[1].id;
  local IsUnique = MySQL.select("id from ? where achv_id=? and gid=?", ID, GID);
  if #IsUnique == 0 then
    YieldError("That achievement doesn't exist!");
  end

  local IsAwarded       = mysql.select("id from awarded_achv where achv_id=? and player=? and gid=?", AchievementID, PlayerInfo.RobloxToInternal(PlayerID), GID);
  if #IsAwarded ~= 0 then
    YieldError("That achievement has already been awarded to the player");
  end

  MySQL.insert(("awarded_achv"):format(PlayerID), { -- No I have no clue either
      achvid              = AchievementID,
      gid                 = GID,
      player              = PlayerID
  });

  return nil;
end

local function EscapeFilter(Name, Filter)
  return ("AND %s LIKE %s"):format(Name, MySQL.escape_literal(("%%%s%%"):format(Filter)));
end

function Module.List(GID, TargetGID, Filter)
    local GID = MySQL.select("id from game_ids where gid=?", GID)[1].id;
  local Query = "achv_id as AchievementID, name as Name, description as Description, icon as Icon, reward as Reward from achievements where GID=? ";
  if Filter.Reward then
    if Filter.Reward:sub(1,1) == ">" then
      Query = Query .. ("AND reward>%d "):format(Filter.Reward:sub(2));
    else
      Query = Query .. ("AND reward<%d "):format(Filter.Reward:sub(2));
    end
  end
  if Filter.ID then
    Query = Query .. EscapeFilter("achv_id", Filter.ID);
  end
  if Filter.Name then
    Query = Query .. EscapeFilter("name", Filter.Name);
  end
  if Filter.Description then
    Query = Query .. EscapeFilter("description", Filter.Description);
  end

  local Ret  = MySQL.select(Query, GID);

  return Ret;
end

function Module.GetReward(GID)
  local UsedReward  = MetaManager.GetMeta("usedreward", GID);
  local Limit       = 1000 - UsedReward;

  return result = {Limit = Limit, Quota = Limit, Used = tonumber(UsedReward)};
end

return Module;
