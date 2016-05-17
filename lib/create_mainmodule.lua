-- TODO: Possibly replace with Valkyrie_CI?
local Module    = {};
if not jit then
  error("LuaJIT not installed!");
end
local LZ4       = dofile("lib/lz4.lua");
local BitLib    = require"BitLib";
local Config    = require("lapis.config").get();

function NumberToHex(IN)
    return string.format("%x", IN);
end

function StringToHex(str)
    local hex = ''
    while #str > 0 do
        local hb = num2hex(string.byte(str, 1, 1))
        if #hb < 2 then hb = '0' .. hb end
        hex = hex .. hb
        str = string.sub(str, 2)
    end
    return hex
end

local function ToLittleEndian(int)
  return string.char(BitLib.band(int, 0xFF))
      .. string.char(BitLib.rshift(BitLib.band(int, 0xFF00), 8))
      .. string.char(BitLib.rshift(BitLib.band(int, 0xFF0000), 16))
      .. string.char(BitLib.rshift(BitLib.band(int, 0xFF000000), 24));
end

function Module.EncodeProperty(PropertyName, PropertyType, PropertyData)
  local Return = "\0\0\0\0"; -- Always zeroes since it's the only instance
            .. ToLittleEndian(PropertyName:len());
            .. PropertyName;
            .. string.char(PropertyType);
            .. PropertyData;

  local UncompressedSize = Return:len();
  Return, Error = LZ4.compress(Return);
  if Error then
    error(Error);
  end

  Return = Return:sub(9);
  local CompressedSize = Return:len();
  Return = "PROP" .. ToLittleEndian(CompressedSize) .. toLittleEndian(UncompressedSize) .. "\0\0\0\0" .. Return;

  return Return;
end

function Module.EncodeInstance(InstanceName)
  local Return = "\0\0\0\0";
              .. ToLittleEndian(InstanceName:len());
              .. instName;
              .. "\0"; -- No additional data
              .. "\1\0\0\0"; -- One instance
              .. "\0\0\0\0"; -- Always zeroes since it's the only instance
  local UncompressedSize = Return:len();
  Return, Error = LZ4.compress(Return);
  if Error then
    error(Error);
  end

  Return = Return:sub(9);
  local CompressedSize = Return:len();
  Return = "INST" .. toLittleEndian(CompressedSize) .. ToLittleEndian(UncompressedSize) .. "\0\0\0\0" .. Return;

  return Return;
end

function Module.EncodeParent(Number, ReferentArray, ParentArray)
  local Return = "\0";
              .. ToLittleEndian(Number);
              .. ReferentArray;
              .. ParentArray;

  local UncompressedSize = Return:len();
  Return, Error = LZ4.compress(Return);
  if Error then
    error(Error);
  end

  Return = Return:sub(9);
  local CompressedSize = Return:len();
  Return = "PRNT" .. ToLittleEndian(CompressedSize) .. ToLittleEndian(UncompressedSize) .. "\0\0\0\0" .. Return;

  return Return;
end

function Module.CreateModel(Source)
  local ModelData = "<roblox!\137\255\13\10\26\10\0\0"; -- Header
                 .. "\1\0\0\0\1\0\0\0"; -- One instance total, one unique
                 .. "\0\0\0\0\0\0\0\0"; -- Padding
                 .. Module.EncodeInstance("ModuleScript");
                 .. Module.EncodeProperty("LinkedSource", 1, "\0\0\0\0");
                 .. Module.EncodeProperty("Name", 1, "\n\0\0\0MainModule"); -- \n\0\0\0 == 10 in LE == ("MainModule"):len()
                 .. Module.EncodeProperty("Source", 1, ToLittleEndian(Source:len()) .. Source);
                 .. Module.EncodeParent(1, "\0\0\0\0", "\0\0\0\1");
                 .. "END\0\0\0\0\0\9\0\0\0\0\0\0\0</roblox>";

  return ModelData;
end

local Sockets   = require("socket");
local SSL       = require("ssl");
local Encoder   = Library("encode");
local LapisUtil = require("lapis.util");

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

local function ASPPostBack(URL, CurrentState, EventTarget, FormValues, SessionCookie, Force)
  local ViewState       = CurrentState:match("id = \"__VIEWSTATE\" value          = \"(.-)\"");
  local VSGenerator     = CurrentState:match("id = \"__VIEWSTATEGENERATOR\" value = \"(.-)\"");
  local PreviousPage    = CurrentState:match("id = \"__PREVIOUSPAGE\" value       = \"(.-)\"");
  local EventValidation = CurrentState:match("id = \"__EVENTVALIDATION\" value    = \"(.-)\"");
  local EventArgument   = CurrentState:match("id = \"__EVENTARGUMENT\" value      = \"(.-)\"");

  local URLArgumnets    = {__VIEWSTATE = ViewState, __VIEWSTATEGENERATOR = VSGenerator, __PREVIOUSPAGE = PreviousPage, __EVENTVALIDATION = EventValidation, __EVENTARGUMENT = EventArguments, __EVENTTARGET = EventTarget};
  for Index, Value in pairs(FormValues) do
    URLArguments[Index]  = Value;
  end

  local Encoded        = LapisUtil.encode_query_string(URLArguments);

  local Return         = PostRequest(URL, Encoded, "Content-Type: application/x-www-form-urlencoded\nCookie: " .. SessionCookie .. "\n");
  if Return:match("/Login/Default.aspx") then
    if Force then
      YieldError("ROBLOX LOGIN FAILED! Please contact gskw. Remember to include the time this happened at.");
    end
    return ASPPostBack(URL, CurrentState, EventTarget, FormValues, Module.Login(Config.robloxun, Config.robloxpw), true); -- TODO: Possibly use user-specificed account?
  end

  return Return;
end

function Module.Login(User, Password)
  local Result    = PostRequest("https://www.roblox.com/Services/Secure/LoginService.asmx/ValidateLogin", ("{\"userName\":\"%s\",\"password\":\"%s\",\"isCaptchaOn\":false,\"challenge\":\"\",\"captchaResponse\":\"\"}"):format(User, Password), "X-Requested-With: XMLHttpRequest\nContent-Type: application/json\nAccept-Encoding: gzip\n");
  local Security  = Result:match("(%.ROBLOSECURITY=.-);");
  local CSRF      = Result:match("X-CSRF-TOKEN: (.-)\r\n");

  io.open(("security_%s.sec"):format(User), "w"):write(Security);
  io.open(("csrf_%s.csrf"):format(User), "w"):write(CSRF);

  return Security, CSRF;
end


local function GetPostArguments(URL, SessionCookie)
  local Result    = PostRequest(url, "", "Cookie: " .. (SessionCookie or io.open("security.sec", "r"):read("*all")) .. "\n");
  if Result:match("/Login/Default.aspx") then
    Result        = GetPostArguments(URL, Module.Login(Config.robloxun, Config.robloxpw));
  end

  return StripHeaders(Result);
end

function Module.LockAsset(ModelID)
  local Result    = GetPostArguments("https://www.roblox.com/My/Item.aspx?ID=" .. ModelID);
  print("POSTBACKOUT", ASPPostBack("https://www.roblox.com/My/Item.aspx?ID=" .. ModelID, StripHeaders(Result), "ctl00$cphRoblox$SubmitButtonBottom", {
    ["ctl00$cphRoblox$NameTextBox"]             = "Valkyrie Server Upload",
    ["ctl00$cphRoblox$DescriptionTextBox"]      = "Loadstring model",
    ["ctl00$cphRoblox$EnableCommentsCheckBox"]  = "on",
    ["GenreButtons2"]                           = 1,
    ["ctl00$cphRoblox$actualGenreSelection"]    = 1,
    ["comments"]                                = "",
    ["rdoNotifications"]                        = "on"
  }, io.open("security.sec", "r"):read("*all")));

  return ({success = true, error = ""});
end

function Module.Upload(Data, ModelID, SessionCookie, Force)
  local Result = PostRequest("/Data/Upload.ashx?assetid=" .. ModelID .. "&type=Model&name=Valkyrie%20Server%20Upload&description=Loadstring%20model&genreTypeId=1&ispublic=True&allowComments=True",
    Data, "Cookie: " .. SessionCookie .. "\nContent-Type: text/xml\n");
  if Result:match("/RobloxDefaultErrorPage") then
    if Force then
      YieldError("ROBLOX LOGIN FAILED! Please contact gskw. Remember to include the time this happened at.");
    end
    return Module.Upload(Data, ModelID, Module.Login(Config.robloxun, config.password), true);
  end
  return StripHeaders(Result);
end

function Module.Load(Data, ModelID)
  local Result = Module.Upload(Module.CreateModel(Data), ModelID, io.open("security.sec", "r"):read("*all"));
  return ({success = true; error = ""; result = Result});
end

return Module;
