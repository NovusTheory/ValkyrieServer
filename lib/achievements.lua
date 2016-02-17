local module              = {};
local mysql               = require "lapis.db";
local gid_table           = library("gid_table");
local encoder             = library("encode");
local metamanager         = library("meta");
local app_helpers         = require"lapis.application";

local yield_error         = app_helpers.yield_error;

function module.create(gid, id, desc, name, reward, icon)
  if tonumber(reward) < 1 then
    yield_error("The reward can't be less than 1!");
  end

  local uniq_result       = mysql.select("id from ? where achv_id=?", gid_table("achievements", gid), id);

  if #uniq_result ~= 0 then
    yield_error("An achievement with that ID already exists!");
  end

  local usedreward        = metamanager.getMeta("usedreward", gid);
  local maxreward         = 1000 - usedreward;

  if maxreward < tonumber(reward) then
    yield_error("The reward exceeds the maximum available reward (" .. maxreward .. ")!");
  end
  metamanager.setMeta("usedreward", usedreward + reward, gid);

  mysql.insert(("achievements_%s"):format(gid), {
        achv_id           = id,
        description       = desc,
        name              = name,
        reward            = reward,
        icon              = icon
    });

  return ({success = true, error = ""});
end

function module.award(gid, pid, aid)
  local uniq_result       = mysql.select("id from ? where achv_id=?", gid_table("achievements", gid), id);
  if #uniq_result == 0 then
    yield_error("That achievement doesn't exist!");
  end

  local aw_uniq_res       = mysql.select("id from awarded_achv where achv_id=? and player=? and gid=?", aid, pid, gid);
  if #aw_uniq_res ~= 0 then
    yield_error("That achievement has already been awarded to the player");
  end

  mysql.insert(("awarded_achv"):format(pid), {
      achvid              = aid,
      gid                 = gid,
      player              = pid
  });

  return ({success = true, error = ""});
end

local function escape_filter(name, filter)
  return ("AND %s LIKE %s"):format(name, mysql.escape_literal(("%%%s%%"):format(filter)));
end

function module.list(gid, othgid, filter)
  local exists_result   = mysql.select("table_name from information_schema.tables where table_name=?", ("achievements_%s"):format(othgid));
  if #exists_result == 0 then
    yield_error("That game doesn't exist");
  end

  local query = "* from ? where 1=1 ";
  if filter[1] and filter[2] and filter[1] ~= "" then
    if filter[1] == ">" then
      query = query .. ("AND %s>=%d "):format("reward", filter[2]);
    else
      query = query .. ("AND %s<=%d "):format("reward", filter[2]);
    end
  end
  if filter[3] and filter[3] ~= "" then
    query = query .. escape_filter("achv_id", filter[3]);
  end
  if filter[4] and filter[4] ~= "" then
    query = query .. escape_filter("name", filter[4]);
  end
  if filter[5] and filter[5] ~= "" then
    query = query .. escape_filter("description", filter[5]);
  end

  local ret  = mysql.select(query, gid_table("achievements", othgid));
  --[[local ret     = {};
  local row     = result:fetch({}, "a");
  while row do
    table.insert(ret, {tonumber(row.reward), row.achv_id, row.name, row.description, tonumber(row.icon)});
    row         = result:fetch({}, "a");
end]]

  return ({
    success = true,
    error   = "",
    result  = ret
  });
end

function module.getReward(gid)
  local usedreward  = metamanager.getMeta("usedreward", gid);
  local limit       = 1000 - usedreward;

  return ({success = true; error = ""; result = {1000, limit, tonumber(usedreward)}});
end

return module;
