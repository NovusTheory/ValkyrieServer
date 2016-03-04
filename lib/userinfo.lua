local module                = {};
local mysql                 = require"lapis.db";
local encoder               = library("encode");
local app_helpers           = require"lapis.application";
local inspect               = require"inspect";
local http                  = require("socket.http");
local socket                = require("socket");
local json                  = require("cjson");
local meta                  = library("meta");
local friends               = {};
local gid_table             = library("gid_table");

local yield_error           = app_helpers.yield_error;

function friends.getFriends(id)
  local ret           = {};
  local ingamep_ret   = mysql.select("gid, player from player_ingame");
  local friends       = http.request(("http://api.roblox.com/users/%d/friends"):format(id));
  friends             = json.decode(friends);
  local ingameplayers = {};
  for i = 1, #ingamep_ret do
    ingameplayers[tonumber(ingamep_ret[i].player)] = ingamep_ret[i].gid;
  end

  for index, value in next, friends do
    local toinsert    = {value.Id; value.Username; ingameplayers[value.Id] and true or false};
    table.insert(toinsert, ingameplayers[value.Id]);
    table.insert(ret, toinsert);
  end

  return ({success = true, error = "", result = ret});
end

local function getGeneralInfo(id)
  local ret                 = {};
  local ingamep_ret         = mysql.select("gid, player from player_ingame where player=?", id);
  local otherinfo           = http.request(("http://api.roblox.com/users/%d"):format(id));
  otherinfo                 = json.decode(otherinfo);
  local online              = #ingamep_ret > 0;
  local gamename            = nil;

  if online then
    gamename                = meta.getMeta("name", ingamep_ret[1].gid);
  end

  return {otherinfo.Id; otherinfo.Username; online and true or false; online and ingamep_ret[1].gid or nil; gamename};
end

local function fixDate(date, diff)
  date                      = date:gsub("(%d-)a", function(a) return " " .. tostring(tonumber(a) - 1970) .. "a"; end);
  date                      = date:gsub("(%d-)([md]) ", function(a, b) return tostring(tonumber(a) - 1) .. b .. " "; end);
  --date                    = date:gsub("(%d-)h", function(a) return tostring(tonumber(a) - 2) .. "h"; end);
  date                      = date:gsub("(%d-)(%a+)", "%1%2 ");
  date                      = date:gsub(" 0+%a+", "");
  date                      = date:gsub(" 0+", "");
  date                      = date:gsub("^ ", ""):gsub(" $", "");
  if date:sub(1, 1) == " " then
    return date:sub(2);
  end

  if date                   == "" then
    if diff then
      return "N/A";
    end
    return "just now";
  end

  return date;
end

local function getDBGeneralInfo(id)
  local ret                 = {{}, {}};
  local userinfo_ret        = mysql.select("* from player_info where player=?", id);

  local row                 = userinfo_ret[1];
  if row then
    ret[2]                  = {row.time_ingame, row.joined, row.last_online};
    table.insert(ret[1], fixDate(os.date("%Ya %mm %dd %Hh %Mmin", row.time_ingame), true));
    table.insert(ret[1], fixDate(os.date("%Ya %mm %dd", math.floor(socket.gettime()) - row.joined)));
    table.insert(ret[1], fixDate(os.date("%Ya %mm %dd %Hh %Mmin", row.last_online == "0" and 0 or math.floor(socket.gettime()) - row.last_online)));
  else
    ret = {{"N/A","N/A","N/A"}, {-1, -1, -1}};
  end

  return ret;
end

function module.tryCreateUser(id)
  local exists_ret          = mysql.select("id from player_info where player=?", id);
  if #exists_ret < 1 then
    mysql.insert("player_info", {
      player                = id;
      time_ingame           = 0;
      joined                = math.floor(socket.gettime());
      last_online           = 0;
    });
  end

  return ({success = true; error = ""});
end

function module.getUserinfo(id)
  local ret                 = {};

  table.insert(ret, math.floor(socket.gettime()));

  table.insert(ret, getGeneralInfo(id));
  table.insert(ret, getDBGeneralInfo(id));

  local exists_result       = mysql.select("table_name from information_schema.tables where table_name=?", ("player_achv_%d"):format(id));
  if #exists_result > 0 then
    local achvs_result      = mysql.select("* from ?", gid_table("player_achv", id));
    local checkedGames      = {};
    local insertret         = {};
    for _, row in next, achvs_result do
      if checkedGames[row.gid] == nil then
        local game_achv_res   = mysql.select("* from ?", gid_table("achievements", row.gid));
        local insertretchk    = {};
        for __, row2 in next, game_achv_res do
          insertretchk[row2.achv_id] = row2;
        end
        checkedGames[row.gid] = insertretchk;
      end
      local insinsret         = {};
      table.insert(insinsret, row.achvid);
      table.insert(insinsret, row.gid);
      table.insert(insinsret, checkedGames[row.gid][row.achvid].name);
      table.insert(insinsret, checkedGames[row.gid][row.achvid].description);
      table.insert(insinsret, tonumber(checkedGames[row.gid][row.achvid].reward));
      table.insert(insinsret, tonumber(checkedGames[row.gid][row.achvid].icon));
      table.insert(insinsret, meta.getMeta("name", row.gid));
      insertret[row.achvid]   = insinsret;
    end
    table.insert(ret, insertret);

    local totalreward         = 0;
    for i, v in next, insertret do
      totalreward             = totalreward + v[5];
    end
    table.insert(ret, totalreward);
  else
    table.insert(ret, {}); -- achievements
    table.insert(ret, 0);  -- total reward
  end

  table.insert(ret, (friends.getFriends(id)).result);

  --print(inspect(parser.parse((ret))));

  return ({success = true; error = ""; result = ret});
end

return module;
