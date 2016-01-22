local module    = {};
if not jit then
  error("LuaJIT not installed!");
end
local lz4       = dofile("lib/lz4.lua");
local bit32     = require"bit32";
local config    = require("lapis.config").get();

function num2hex(IN)
    return string.format("%x", IN);
end

function str2hex(str)
    local hex = ''
    while #str > 0 do
        local hb = num2hex(string.byte(str, 1, 1))
        if #hb < 2 then hb = '0' .. hb end
        hex = hex .. hb
        str = string.sub(str, 2)
    end
    return hex
end

local function toLittleEndian(int)
  return string.char(bit32.band(int, 0xFF))
      .. string.char(bit32.rshift(bit32.band(int, 0xFF00), 8))
      .. string.char(bit32.rshift(bit32.band(int, 0xFF0000), 16))
      .. string.char(bit32.rshift(bit32.band(int, 0xFF000000), 24));
end

function module.encodeProperty(propName, propType, propData)
  local ret = "\0\0\0\0"; -- Always zeroes since it's the only instance
  ret = ret .. toLittleEndian(propName:len());
  ret = ret .. propName;
  ret = ret .. string.char(propType);
  ret = ret .. propData;

  local origLen = ret:len();
  ret, err = lz4.compress(ret);
  if err then
    error(err);
  end

  ret = ret:sub(9);
  local compLen = ret:len();
  ret = "PROP" .. toLittleEndian(compLen) .. toLittleEndian(origLen) .. "\0\0\0\0" .. ret;

  return ret;
end

function module.encodeInstance(instName)
  local ret = "\0\0\0\0";
  ret = ret .. toLittleEndian(instName:len());
  ret = ret .. instName;
  ret = ret .. "\0"; -- No additional data
  ret = ret .. "\1\0\0\0"; -- One instance
  ret = ret .. "\0\0\0\0"; -- Always zeroes since it's the only instance
  local origLen = ret:len();
  ret, err = lz4.compress(ret);
  if err then
    error(err);
  end

  ret = ret:sub(9);
  local compLen = ret:len();
  ret = "INST" .. toLittleEndian(compLen) .. toLittleEndian(origLen) .. "\0\0\0\0" .. ret;

  return ret;
end

function module.encodeParent(num, refarr, pararr)
  local ret = "\0";
  ret = ret .. toLittleEndian(num);
  ret = ret .. refarr;
  ret = ret .. pararr;

  local origLen = ret:len();
  ret, err = lz4.compress(ret);
  if err then
    error(err);
  end

  ret = ret:sub(9);
  local compLen = ret:len();
  ret = "PRNT" .. toLittleEndian(compLen) .. toLittleEndian(origLen) .. "\0\0\0\0" .. ret;

  return ret;
end

function module.createModel(source)
  local modelData = "<roblox!\137\255\13\10\26\10\0\0"; -- Header
  modelData = modelData .. "\1\0\0\0\1\0\0\0"; -- One instance total, one unique
  modelData = modelData .. "\0\0\0\0\0\0\0\0"; -- Padding
  modelData = modelData .. module.encodeInstance("ModuleScript");
  modelData = modelData .. module.encodeProperty("LinkedSource", 1, "\0\0\0\0");
  modelData = modelData .. module.encodeProperty("Name", 1, "\n\0\0\0MainModule"); -- \n\0\0\0 == 10 in LE == ("MainModule"):len()
  modelData = modelData .. module.encodeProperty("Source", 1, toLittleEndian(source:len()) .. source);
  modelData = modelData .. module.encodeParent(1, "\0\0\0\0", "\0\0\0\1");
  modelData = modelData .. "END\0\0\0\0\0\9\0\0\0\0\0\0\0</roblox>";

  return modelData;
end

local sockets   = require("socket");
local ssl       = require("ssl");
local encoder   = library("encode");
local lapisutl  = require("lapis.util");

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
  print(req);

  local sock  = sockets.tcp();
  sock:connect("www.roblox.com", 443);
  sock        = ssl.wrap(sock, {mode = "client", protocol = "tlsv1"});
  sock:dohandshake();
  sock:send(req);
  local rep = sock:receive("*a");
  print(rep);
  sock:close();
  return rep;
end

local function postReqNoSSL(url, fields, extrahead, usegzip)
  print(url, fields, extrahead);
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
  sock:close();
  return rep;
end

local function aspPostBack(url, currstate, evttarget, formvals, security, force)
  local viewstate   = currstate:match("id=\"__VIEWSTATE\" value=\"(.-)\"");
  local vsgenerator = currstate:match("id=\"__VIEWSTATEGENERATOR\" value=\"(.-)\"");
  local prevpage    = currstate:match("id=\"__PREVIOUSPAGE\" value=\"(.-)\"");
  local evtvalid    = currstate:match("id=\"__EVENTVALIDATION\" value=\"(.-)\"");
  local evtarg      = currstate:match("id=\"__EVENTARGUMENT\" value=\"(.-)\"");

  local urlargs     = {__VIEWSTATE = viewstate, __VIEWSTATEGENERATOR = vsgenerator, __PREVIOUSPAGE = prevpage, __EVENTVALIDATION = evtvalid, __EVENTARGUMENT = evtarg, __EVENTTARGET = evttarget};
  for index, value in pairs(formvals) do
    urlargs[index]  = value;
  end

  local encoded     = lapisutl.encode_query_string(urlargs);
  print(encoded);

  local ret         = postReqNoSSL(url, encoded, "Content-Type: application/x-www-form-urlencoded\nCookie: " .. security .. "\n");
  if ret:match("/Login/Default.aspx") then
    if force then
      yield_error("ROBLOX LOGIN FAILED! Please contact gskw. Remember to include the time this happened at.");
    end
    return aspPostBack(url, currstate, evttarget, formvals, module.login(config.robloxun, config.robloxpw), true);
  end

  return ret;
end

local function stripHeaders(str)
  local index = str:find("\r\n\r\n");
  return str:sub(index + 4);
end

function module.login(user, pw)
  local result    = postReq("https://www.roblox.com/Services/Secure/LoginService.asmx/ValidateLogin", ("{\"userName\":\"%s\",\"password\":\"%s\",\"isCaptchaOn\":false,\"challenge\":\"\",\"captchaResponse\":\"\"}"):format(user, pw), "X-Requested-With: XMLHttpRequest\nContent-Type: application/json\nAccept-Encoding: gzip\n");
  local security  = result:match("(%.ROBLOSECURITY=.-);");

  local secfile, err = io.open("security.sec", "w");
  if not secfile then
    error(err);
  end
  secfile:write(security);

  return security;
end

local function getPostArgs(url, security)
  local result    = postReqNoSSL(url, "", "Cookie: " .. (security or io.open("security.sec", "r"):read("*all")) .. "\n");
  if result:match("/Login/Default.aspx") then
    result        = getPostArgs(url, module.login(config.robloxun, config.robloxpw));
  end

  return stripHeaders(result);
end

function module.lockAsset(mid)
  local result    = getPostArgs("http://www.roblox.com/My/Item.aspx?ID=" .. mid);
  print("POSTBACKOUT", aspPostBack("http://www.roblox.com/My/Item.aspx?ID=" .. mid, stripHeaders(result), "ctl00$cphRoblox$SubmitButtonBottom", {
    ["ctl00$cphRoblox$NameTextBox"]             = "loadstring",
    ["ctl00$cphRoblox$DescriptionTextBox"]      = "a",
    ["ctl00$cphRoblox$EnableCommentsCheckBox"]  = "on",
    ["GenreButtons2"]                           = 1,
    ["ctl00$cphRoblox$actualGenreSelection"]    = 1,
    ["comments"]                                = "",
    ["rdoNotifications"]                        = "on"
  }, io.open("security.sec", "r"):read("*all")));

  return encoder.encode({success = true, error = ""});
end

function module.uploadRaw(data, mid)
    return module.upload(data, 0, io.open("security.sec", "r"):read("*all"));
end

function module.upload(data, mid, security, force)
  local result = postReqNoSSL("/Data/Upload.ashx?assetid=" .. mid .. "&type=Model&name=loadstring&description=a&genreTypeId=1&ispublic=True&allowComments=True",
    data, "Cookie: " .. security .. "\nContent-Type: text/xml\n");
  if result:match("/RobloxDefaultErrorPage") then
    if force then
      yield_error("ROBLOX LOGIN FAILED! Please contact gskw. Remember to include the time this happened at.");
    end
    print("NEW LOGIN!");
    return module.upload(data, mid, module.login(config.user .. "Bot", config.password), true);
  end
  return stripHeaders(result);
end

function module.toAID(AVID)
  local result = postReqNoSSL("https://www.roblox.com/redirect-item?avid=" .. AVID, "", "");
  return tonumber(result:match("Location: /.-id=(%d*)"));
end

function module.load(data, mid)
  local ret = module.toAID(module.upload(module.createModel(data), mid, io.open("security.sec", "r"):read("*all")));
  print(ret);
  return encoder.encode({success = true; error = ""; result = ret});
end

return module;
