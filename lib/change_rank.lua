local Module      = {};
local Sockets     = require("socket");
local SSL         = require("ssl");
local JSON        = require("cjson");
local Encoder     = library("encode");
local LapisUtil   = require("lapis.util");
local MetaManager = library("meta");
local Config      = require("lapis.config").get();

local function PostRequest(URL, Fields, ExtraHeaders)
  local Request =  "POST " .. URL .. " HTTP/1.1\n";
                .. "Host: www.roblox.com\n";
                .. "Accept: */*\n";
                .. "Connection: close\n";
                .. "Content-Length: " .. Fields:len() .. "\n";
                .. "Accept-Encoding: gzip\n";
                .. "User-Agent: Roblox/WinINet\n";
                .. ExtraHeaders .. "\n";
                .. Fields;

  local Socket  = Sockets.tcp();
  Socket:connect("www.roblox.com", 443);
  Socket        = ssl.wrap(Socket, {mode = "client", protocol = "tlsv1_2"});
  Socket:dohandshake();
  Socket:send(Request);
  local Response = Socket:receive("*a");
  Socket:close();
  return Response;
end

local function StripHeaders(Response)
  local Index = Response:find("\r\n\r\n");
  return Response:sub(Index + 4);
end

function Module.Login(User, Password)
  local Result    = PostRequest("https://www.roblox.com/Services/Secure/LoginService.asmx/ValidateLogin", ("{\"userName\":\"%s\",\"password\":\"%s\",\"isCaptchaOn\":false,\"challenge\":\"\",\"captchaResponse\":\"\"}"):format(User, Password), "X-Requested-With: XMLHttpRequest\nContent-Type: application/json\nAccept-Encoding: gzip\n");
  local Security  = Result:match("(%.ROBLOSECURITY=.-);");
  local CSRF      = Result:match("X-CSRF-TOKEN: (.-)\r\n");

  io.open(("security_%s.sec"):format(User), "w"):write(Security);
  io.open(("csrf_%s.csrf"):format(User), "w"):write(CSRF);

  return Security, CSRF;
end

function Module.ChangeRank(Username, Password, GroupID, RolesetID, UserID, Force, CSRFForce)
  local Result    = PostRequest("/groups/api/change-member-rank?groupId=" .. GroupID .. "&newRoleSetID=" .. RolesetID .. "&targetUserID=" .. UserID,
  "",
  "Cookie: " .. io.open(("security_%s.sec"):format(Username), "r"):read("*all") .. "\nX-CSRF-TOKEN: " .. io.open("csrf.csrf", "r"):read("*all"));
  if Result:match("GuestData") then
    if Force then
      YieldError("ROBLOX LOGIN FAILED! Please contact gskw. Remember to include the time this happened at.");
    end
    Module.Login(Username, Password);
    Module.ChangeRank(Username, Password, GroupID, RolesetID, UserID, true);
  elseif Result:match("Token Validation Failed") then
    if CSRFForce then
      YieldError("ROBLOX CSRF FETCH FAILED! Please contact gskw. Remember to include the time this happened at.");
    end
    io.open(("csrf_%s.csrf"):format(Username), "w"):write(Result:match("X-CSRF-TOKEN: (.-)\r\n"));
    Module.ChangeRank(Username, Password, GroupID, RolesetID, UserID, false, true);
  end

  return true;
end

function Module.ChangeRankEasy(GID, GroupID, RankID, UserID)
  local Username, Password, Result = nil, nil, {};
  local Success = pcall(function()
    Username = MetaManager.GetMeta("changeRank_easy_username", GID);
    Password = MetaManager.GetMeta("changeRank_easy_password", GID);
  end);

  --[[
  WHAT WAS I THINKING?
  if not Success then
    Result.Warnings = {"Username or password for changing ranks not set; assuming " .. config.robloxun};
    username = config.robloxun;
    password = config.robloxpw;
  end]]

  local Rolesets  = JSON.decode(PostRequest(("https://www.roblox.com/api/groups/%d/RoleSets"):format(GID), "", ""));

  local RolesetID = 0;
  for Index, Role in next, Rolesets do
    if Role.Rank == RankID then
      RolesetID = Role.ID;
    end
  end

  if RolesetID == 0 then
    YieldError("Invalid rank ID!");
  end

  return Module.ChangeRank(Username, Password, GroupID, RolesetID, UserID);
end

return Module;
