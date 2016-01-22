local module    = {};
local sockets   = require("socket");
local ssl       = require("ssl");
local json      = require("cjson");
local encoder   = library("encode");
local lapisutl  = require("lapis.util");
local metamgr   = library("meta");
local config    = require("lapis.config").get();

local function postReq(url, fields, extrahead)
  local req = "POST " .. url .. " HTTP/1.1\n";
  req = req .. "Host: www.roblox.com\n";
  req = req .. "Accept: */*\n";
  req = req .. "Connection: close\n";
  req = req .. "Content-Length: " .. fields:len() .. "\n";
  req = req .. "Accept-Encoding: gzip\n";
  req = req .. "User-Agent: Roblox/WinINet\n";
  req = req .. extrahead .. "\n";
  req = req .. fields;

  local sock  = sockets.tcp();
  sock:connect("www.roblox.com", 443);
  sock        = ssl.wrap(sock, {mode = "client", protocol = "tlsv1"});
  sock:dohandshake();
  print(req);
  sock:send(req);
  local rep = sock:receive("*a");
  print(rep);
  sock:close();
  return rep;
end

local function postReqNoSSL(url, fields, extrahead, usegzip)
  local req = "POST " .. url .. " HTTP/1.1\n";
  req = req .. "Host: www.roblox.com\n";
  req = req .. "Accept: */*\n";
  req = req .. "Connection: close\n";
  req = req .. "Content-Length: " .. fields:len() .. "\n";
  req = req .. "User-Agent: Roblox/WinINet\n";
  req = req .. extrahead .. "\n";
  req = req .. fields;

  local sock  = sockets.tcp();
  sock:connect("www.roblox.com", 80);
  sock:send(req);
  print("\27[33mRequest:\27[0m\n", req);
  local rep = sock:receive("*a");
  print("\27[33mReturn:\27[0m\n", rep);
  print(rep, "LEN = ", rep:len());
  sock:close();
  return rep;
end

local function stripHeaders(str)
  local index = str:find("\r\n\r\n");
  return str:sub(index + 4);
end

function module.login(user, pw)
  local result    = postReq("https://www.roblox.com/Services/Secure/LoginService.asmx/ValidateLogin", ("{\"userName\":\"%s\",\"password\":\"%s\",\"isCaptchaOn\":false,\"challenge\":\"\",\"captchaResponse\":\"\"}"):format(user, pw), "X-Requested-With: XMLHttpRequest\nContent-Type: application/json\nAccept-Encoding: gzip\n");
  local security  = result:match("(%.ROBLOSECURITY=.-);");
  local csrf      = result:match("X-CSRF-TOKEN: (.-)\r\n");

  io.open(("security_%s.sec"):format(user), "w"):write(security);
  io.open(("csrf_%s.csrf"):format(user), "w"):write(csrf);

  return security, csrf;
end

function module.changeRank(un, pw, gid, rsid, uid, force, csrfforce)
  local result    = postReqNoSSL("/groups/api/change-member-rank?groupId=" .. gid .. "&newRoleSetID=" .. rsid .. "&targetUserID=" .. uid,
  "",
  "Cookie: " .. io.open(("security_%s.sec"):format(un), "r"):read("*all") .. "\nX-CSRF-TOKEN: " .. io.open("csrf.csrf", "r"):read("*all"));
  if result:match("GuestData") then
    if force then
      yield_error("ROBLOX LOGIN FAILED! Please contact gskw. Remember to include the time this happened at.");
    end
    module.login(un, pw);
    module.changeRank(un, pw, gid, rsid, uid, true);
  elseif result:match("Token Validation Failed") then
    if csrfforce then
      yield_error("ROBLOX CSRF FETCH FAILED! Please contact gskw. Remember to include the time this happened at.");
    end
    io.open(("csrf_%s.csrf"):format(un), "w"):write(result:match("X-CSRF-TOKEN: (.-)\r\n"));
    module.changeRank(un, pw, gid, rsid, uid, false, true);
  end

  return true;
end

function module.changeRank_easy(gameid, gid, rnkid, uid)
  local username, password, ret = nil, nil, {};
  local succ = pcall(function()
    username = metamgr.getMeta("changeRank_easy_username", gameid);
    password = metamgr.getMeta("changeRank_easy_password", gameid);
  end);

  if not succ then
    ret.warn = {"Username or password for changing ranks not set; assuming " .. config.robloxun};
    username = config.robloxun;
    password = config.robloxpw;
  end

  local rolesets  = json.decode(postReqNoSSL(("http://www.roblox.com/api/groups/%d/RoleSets"):format(gid), "", ""));

  local rsid = 0;
  for index, role in next, rolesets do
    if role.Rank == rnkid then
      rsid = role.ID;
    end
  end

  if rsid == 0 then
    yield_error("Invalid rank ID!");
  end

  return module.changeRank(username, password, gid, rsid, uid);
end

return module;
