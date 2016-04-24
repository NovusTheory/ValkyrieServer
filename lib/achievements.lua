local Module      = {};
local MySQL       = require "lapis.db";
local GIDTable    = library("gid_table");
local Encoder     = library("encode");
local MetaManager = library("meta");
local AppHelpers  = require"lapis.application";

local YieldError  = app_helpers.yield_error;

function Module.Create(GID, ID, Description, Name, Reward, Icon)
  if tonumber(Reward) < 1 then
    YieldError("The reward can't be less than 1!");
  end

  local IsUnique       = MySQL.select("id from ? where achv_id=?", GIDTable("achievements", GID), ID);

  if #IsUnique ~= 0 then
    YieldError("An achievement with that ID already exists!");
  end

  local UsedReward        = MetaManager.GetMeta("usedreward", GID);
  local MaxReward         = 1000 - UsedReward;

  if MaxReward < tonumber(Reward) then
    YieldError("The reward exceeds the maximum available reward (" .. MaxReward .. ")!");
  end
  MetaManager.SetMeta("usedreward", UsedReward + Reward, GID);

  MySQL.insert(("achievements_%s"):format(GID), {
        achv_id           = ID,
        description       = Description,
        name              = Name,
        reward            = Reward,
        icon              = Icon
    });

  return {success = true, error = ""};
end

function Module.Award(GID, PlayerID, AchievementID)
  local IsUnique = MySQL.select("id from ? where achv_id=?", GIDTable("achievements", GID), ID);
  if #IsUnique == 0 then
    YieldError("That achievement doesn't exist!");
  end

  local IsAwarded       = mysql.select("id from awarded_achv where achv_id=? and player=? and gid=?", aid, pid, gid);
  if #IsAwarded ~= 0 then
    YieldError("That achievement has already been awarded to the player");
  end

  MySQL.insert(("awarded_achv"):format(PlayerID), { -- No I have no clue either
      achvid              = AchievementID,
      gid                 = GID,
      player              = PlayerID
  });

  return ({success = true, error = ""});
end

local function EscapeFilter(Name, Filter)
  return ("AND %s LIKE %s"):format(Name, MySQL.escape_literal(("%%%s%%"):format(Filter)));
end

function Module.List(GID, TargetGID, Filter)
  local TargetExists   = mysql.select("table_name from information_schema.tables where table_name=?", ("achievements_%s"):format(TargetGID));
  if #TargetExists == 0 then
    YieldError("That game doesn't exist");
  end

  local Query = "* from ? where 1=1 ";
  if Filter[1] and Filter[2] and Filter[1] ~= "" then -- TODO: Convert to named keys
    if Filter[1] == ">" then
      Query = Query .. ("AND %s>=%d "):format("reward", Filter[2]);
    else
      Query = Query .. ("AND %s<=%d "):format("reward", Filter[2]);
    end
  end
  if Filter[3] and Filter[3] ~= "" then
    Query = Query .. EscapeFilter("achv_id", Filter[3]);
  end
  if Filter[4] and Filter[4] ~= "" then
    Query = Query .. EscapeFilter("name", Filter[4]);
  end
  if Filter[5] and Filter[5] ~= "" then
    Query = Query .. EscapeFilter("description", Filter[5]);
  end

  local Ret  = MySQL.select(Query, GIDTable("achievements", TargetGID));

  return ({
    success = true,
    error   = "",
    result  = Ret
  });
end

function Module.GetReward(gid)
  local UsedReward  = MetaManager.GetMeta("usedreward", GID);
  local Limit       = 1000 - UsedReward;

  return ({success = true; error = ""; result = {1000, Limit, tonumber(UsedReward)}});
end

return Module;
