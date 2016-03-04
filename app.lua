local lapis       = require("lapis");
local app         = lapis.Application();
local cache       = require("lapis.cache");

function library(name) return require("valkyrie_server.lib." .. name); end
local intmodules  = require "valkyrie_server.interface.modules";
local permstest   = library("permissions");
local parser      = library("parse");
local creator     = library("create_mainmodule");
local gid_table   = library("gid_table");
local app_helpers = require"lapis.application";
local respond_to  = require("lapis.application").respond_to;

local capture_errors  = app_helpers.capture_errors;
local yield_error     = app_helpers.yield_error;
local json_params     = app_helpers.json_params;

local mysql       = require "lapis.db";
local mysql_schm  = require "lapis.db.schema";
local http        = require "lapis.nginx.http";
local util        = require "lapis.util";
local json        = require "cjson";
local BuildRequest, HTTPRequestSSL, HTTPRequest, StripHeaders, Login, DataRequest, RunPostBack, FindPostState, HTTPGet = unpack(library("httputil"));

local cachefunc = function(url, x, self)
  return (self.session.user or "") .. url;
end;

app:enable"etlua"
app.layout = require("views.head");

app:before_filter(function(self)
    self.SignedIn = self.session.user;
end);

app:get("root", "/", function(self)
  return {render = "landing"};
end);

function err_func(self)
  return    {render = "empty"; layout = false; content_type = "application/json"; json = {success = false; error = self.errors[1]}};
end

-- Documentation
app:match("docs", "/docs", cache.cached{function(self)
  self.title = "Valkyrie Docs";
  return {render = "docs"};
end,
dict_name = "docs_cache";
exptime = 24*60*60;
cache_key = cachefunc;
});

app:match("docscat", "/docs/:subtype", cache.cached{function(self)
  self.title = "Valkyrie Docs";
  return {render = "docs"};
end,
dict_name = "docs_cache";
exptime = 60*60;
cache_key = cachefunc;
});

app:match("docsobj", "/docs/:subtype/:name", cache.cached{function(self)
  self.title = "Valkyrie Docs";
  return {render = "docs"};
end,
dict_name = "docs_cache";
exptime = 60;
cache_key = cachefunc;
});

app:match("getValkyrie", "/get", function(self)
  self.title = "Get Valkyrie";
  return {render=true};
end);

app:match("friends", "/friends", function(self)
  self.title = "Friends";
  return {render=true};
end);

app:match("login", "/login", respond_to{
  before = function(self)
    if self.SignedIn then
      self:write({redirect_to = "/"});
    end
  end;
  GET = function(self)
    self.invalid = {};
    self.title = "Valkyrie Login";
    return {render = true};
  end,
  POST = function(self)
    self.invalid = {};
    self.bare = true;
    if not self.params.username or #self.params.username < 1 then
        self.invalid.username = "Enter a username";
    end
    if not self.params.password or #self.params.password < 1 then
        self.invalid.password = "Enter a password";
    end
    if #self.invalid > 0 then
        return {layout = false; render = true};
    end

    if mysql.select("count(*) from users where username=? and password=?", self.params.username, mysql.raw("sha2(" .. mysql.escape_literal(self.params.password) .. ", 256)"))[1]["count(*)"] == "1" then
        self.session.user = self.params.username;
        return "<script>window.location.replace('/')</script>";
    else
        self.invalid.password = "The username and password do not match";
        return {layout = false; render = true};
    end
  end}
);

app:match("signup1", "/signup/1", respond_to{
  before = function(self)
    if self.SignedIn then
      self:write({redirect_to = "/"});
    end
  end;
  GET = function(self)
    self.missing = {};
    self.bare = true;
    self.page = "signup";
    return {render = "signup", layout = false};
  end;
  POST = function(self)
    local invalid = {};
    self.bare = true;
    if not self.params.username or self.params.username == "" then
      invalid.username = "Enter a username";
    end
    if not self.params.password or self.params.password == "" then
      invalid.password = "Enter a password";
    end;

    if not invalid.username then
      if self.params.username:len() > 20 then
        invalid.username = "There is no such user on Roblox";
      elseif mysql.select("count(*) from users where username=?", self.params.username)[1]["count(*)"] ~= "0" then
        invalid.username = "This username is already in use";
      elseif ({http.simple("http://api.roblox.com/users/get-by-username?username=" .. self.params.username)})[1] == '{"success":false,"errorMessage":"User not found"}' then
        invalid.username = "There is no such user on Roblox";
      end
    end

    if not invalid.password then
      if self.params.password:len() < 6 or self.params.password:len() > 50 then
        invalid.password = "Passwords must be between 6 and 50 characters";
      end
    end

    if invalid.username or invalid.password then
      self.invalid = invalid;
      self.page = "signup";

      return {render = "signup", layout = false};
    else
      self.page = "signup2";
      return {render = "signup", layout = false};
    end
  end;
});

app:get('features','/features',function(self)
  return {render=true};
end);

local function checkCanMessage(id, cookie, force)
  local html = HTTPGet("http://www.roblox.com/users/" .. id .. "/profile", "Cookie: " .. cookie .. "\n");
  if html:match 'data%-userid="0"' then
    if force then
      error "ROBLOX LOGIN FAILED! Please tell gskw. Remember to include the time this happened at.";
    end
    checkCanMessage(id, Login(), true);
  end
  return not not html:match 'data%-canmessage=true';
end

local function htmlunentities(str)
   local entities = {
      nbsp = ' ' ,
      iexcl = '¡' ,
      cent = '¢' ,
      pound = '£' ,
      curren = '¤' ,
      yen = '¥' ,
      brvbar = '¦' ,
      sect = '§' ,
      uml = '¨' ,
      copy = '©' ,
      ordf = 'ª' ,
      laquo = '«' ,
      ['not'] = '¬' ,
      shy = '­' ,
      reg = '®' ,
      macr = '¯' ,
      ['deg'] = '°' ,
      plusmn = '±' ,
      sup2 = '²' ,
      sup3 = '³' ,
      acute = '´' ,
      micro = 'µ' ,
      para = '¶' ,
      middot = '·' ,
      cedil = '¸' ,
      sup1 = '¹' ,
      ordm = 'º' ,
      raquo = '»' ,
      frac14 = '¼' ,
      frac12 = '½' ,
      frac34 = '¾' ,
      iquest = '¿' ,
      Agrave = 'À' ,
      Aacute = 'Á' ,
      Acirc = 'Â' ,
      Atilde = 'Ã' ,
      Auml = 'Ä' ,
      Aring = 'Å' ,
      AElig = 'Æ' ,
      Ccedil = 'Ç' ,
      Egrave = 'È' ,
      Eacute = 'É' ,
      Ecirc = 'Ê' ,
      Euml = 'Ë' ,
      Igrave = 'Ì' ,
      Iacute = 'Í' ,
      Icirc = 'Î' ,
      Iuml = 'Ï' ,
      ETH = 'Ð' ,
      Ntilde = 'Ñ' ,
      Ograve = 'Ò' ,
      Oacute = 'Ó' ,
      Ocirc = 'Ô' ,
      Otilde = 'Õ' ,
      Ouml = 'Ö' ,
      times = '×' ,
      Oslash = 'Ø' ,
      Ugrave = 'Ù' ,
      Uacute = 'Ú' ,
      Ucirc = 'Û' ,
      Uuml = 'Ü' ,
      Yacute = 'Ý' ,
      THORN = 'Þ' ,
      szlig = 'ß' ,
      agrave = 'à' ,
      aacute = 'á' ,
      acirc = 'â' ,
      atilde = 'ã' ,
      auml = 'ä' ,
      aring = 'å' ,
      aelig = 'æ' ,
      ccedil = 'ç' ,
      egrave = 'è' ,
      eacute = 'é' ,
      ecirc = 'ê' ,
      euml = 'ë' ,
      igrave = 'ì' ,
      iacute = 'í' ,
      icirc = 'î' ,
      iuml = 'ï' ,
      eth = 'ð' ,
      ntilde = 'ñ' ,
      ograve = 'ò' ,
      oacute = 'ó' ,
      ocirc = 'ô' ,
      otilde = 'õ' ,
      ouml = 'ö' ,
      divide = '÷' ,
      oslash = 'ø' ,
      ugrave = 'ù' ,
      uacute = 'ú' ,
      ucirc = 'û' ,
      uuml = 'ü' ,
      yacute = 'ý' ,
      thorn = 'þ' ,
      yuml = 'ÿ' ,
      quot = '"' ,
      lt = '<' ,
      gt = '>' ,
      amp = '&'
   }

  str = string.gsub(str, "&%a+;",
	       function (entity)
		  return entities[string.sub(entity, 2, -2)] or entity
	       end)
   return str
end

local function checkSentMessage(id, token, cookie, force)
  local result = HTTPGet("http://www.roblox.com/messages/api/get-messages?messageTab=0&pageNumber=0&pageSize=20", "Cookie: " .. cookie .. "\n");
  print(result);
  if result:match("^HTTP/1.1 302 Found\r\nCache%-Control: private\r\nContent%-Type: text/html; charset=utf%-8\r\nLocation:") then
    if force then
      error "ROBLOX LOGIN FAILED! Please tell gskw. Remember to include the time this happened at.";
    end
    checkSentMessage(id, token, Login(), true);
  end
  result = json.decode(result:match("\r\n\r\n(.*)$"));
  for i = 1, #result.Collection do
    if tonumber(result.Collection[i].Sender.UserId) == tonumber(id) then
      if htmlunentities(result.Collection[i].Body):find(token, 1, true) then
        return true;
      else
        print(htmlunentities(result.Collection[i].Body))
      end
    end
  end
  return false;
end

app:match("signup2", "/signup/2", respond_to{
  before = function(self)
    if self.SignedIn then
      self:write({redirect_to = "/"});
    end
  end;
  GET = function(self)
    self.page = "signup2";
    return {render = "signup", layout = false};
  end;
  POST = function(self)
    -- Sanity-check all information again
    local invalid = {};
    self.bare = true;
    if not self.params.username or self.params.username == "" then
      invalid.username = "Enter a username";
    end
    if not self.params.password or self.params.password == "" then
      invalid.password = "Enter a password";
    end;

    if not invalid.username then
      if self.params.username:len() > 20 then
        invalid.username = "There is no such user on Roblox";
      elseif mysql.select("count(*) from users where username=?", self.params.username)[1]["count(*)"] ~= "0" then
        invalid.username = "This username is already in use";
      elseif ({http.simple("http://api.roblox.com/users/get-by-username?username=" .. self.params.username)})[1] == '{"success":false,"errorMessage":"User not found"}' then
        invalid.username = "There is no such user on Roblox";
      end
    end

    if not invalid.password then
      if self.params.password:len() < 6 or self.params.password:len() > 50 then
        invalid.password = "Passwords must be between 6 and 50 characters";
      end
    end

    if invalid.username or invalid.password then
      self.invalid = invalid;
      self.page = "signup";

      return {render = "signup", layout = false};
    end


    -- New code starts here
    local userid = ({http.simple("http://api.roblox.com/users/get-by-username?username=" .. self.params.username)})[1]:match('{"Id":(%d+)');
    local canMessage = checkCanMessage(userid, io.open "security.sec":read "*a");
    if not canMessage then
      self._error = "Your privacy settings are configured wrong! Please double-check them!";
    end

    -- TODO: Check for valid token. It's not that important though; I doubt anybody will message ValkyrieBot by accident
    local hasSentMessage = checkSentMessage(userid, self.params.token, io.open "security.sec":read "*a");
    if not hasSentMessage then
      self._error = "You didn't send a message to ValkyrieBot!";
    end

    if self._error then
      self.page = "signup2";
      return {render = "signup", layout = false};
    end

    self.page = "signup3";

    mysql.insert("users", {
        username = self.params.username;
        password = mysql.raw("sha2(" .. mysql.escape_literal(self.params.password) .. ", 256)");
        robloxid = userid;
    });
    self.SignedIn = true;
    self.session.user = self.params.username;

    return {render = "signup", layout = false};
  end;
});

app:match("signup", "/signup", respond_to{
  before = function(self)
    if self.SignedIn then
      self:write({redirect_to = "/"});
    end
  end;
  GET = function(self)
    self.invalid = {};
    self.page = "signup";
    return {render = true};
  end;
  POST = function(self)
    self.invalid = {};
    self.page = "signup";
    self.bare = true;
    return {render = true, layout = false};
  end
});
app:match("/validate/:name", function(self) -- Check if username is valid for signup
  return {render = "empty", layout = false, tostring(mysql.select("count(*) from users where username=?", self.params.name)[1]["count(*)"] == "0")};
end);

app:match("gamelist", "/user/:user/games", function(self)
    if not self.session.user then
        return {redirect_to = self:url_for "login"};
    end
    return {render = true};
end);

local CSRF = require "lapis.csrf";

app:match("newgame", "/game/new", function(self)
    if not self.session.user then
        return {redirect_to = self:url_for "login"};
    end
    self.invalid = {};
    self.bare = false;
    self.CSRFToken = CSRF.generate_token(self, self.session.user); -- Has to be done here for access to 'self'
    -- Or it might work in etlua with getfenv(), but I'm not sure
    return {render = true};
end);

app:match("game", "/game/:gid", respond_to{
    GET = function(self)
        return {render = true};
    end,
    PUT = function(self)
        if self.session.user == nil then
            return {redirect_to = self:url_for("login")};
        end
        self.CSRFToken = self.params.csrf_token;
        self.invalid = {};

        if not CSRF.validate_token(self, self.session.user) then
            self.invalid.gid = "Error: Invalid CSRF Token! (This message should never be displayed on a browser. If it has, contant gskw)";
        end

        if not self.params.gid or #self.params.gid < 1 then
            self.invalid.gid = "Enter a GID";
        end
        if not self.params.game_name or #self.params.game_name < 1 then
            self.invalid.game_name = "Enter a game name";
        end
        if not self.params.key or #self.params.key < 1 then
            self.invalid.key = "Enter a key";
        end

        if mysql.select("count(*) from game_ids where gid=?", self.params.gid)[1]["count(*)"] == "1" then
            self.invalid.gid = "This GID is already in use!";
	    self.bare = true;
            return {layout = false; render = "newgame"};
        end

        if mysql.select("count(*) from game_ids where owner=(select id from users where username=?)", self.session.user)[1]["count(*)"] == "5" then
            self.invalid.gid = "You already own 5 games!";
        end

        if self.params.gid:find "\n" then
            self.invalid.gid = "GIDs can't contain newlines";
        end

        if self.invalid.gid or self.invalid.key or self.invalid.game_name then
            self.bare = true;
            return {layout = false; render = "newgame"};
        end

        ----- DEFAULT PERMISSIONS!
        io.open("permissions.perms", "a"):write(self.params.gid .. "\n+*.*\n:");
        -- TODO: Implement SHA2 instead of MD5
        mysql.insert("game_ids", {
            gid = self.params.gid;
            cokey = mysql.raw("md5(" .. mysql.escape_literal(self.params.key) .. ")");
            owner = mysql.select("id from users where username=?", self.session.user)[1].id;
        });
        local function create_like(base)
            mysql.query("create table ? like ?", mysql.raw(mysql.escape_identifier(base .. "_" .. self.params.gid)), mysql.raw(base .. "_template"));
        end
        create_like("achievements");
        create_like("meta");
        create_like("trusted_users");

        mysql.insert(mysql.raw(mysql.escape_identifier("trusted_users_" .. self.params.gid)), {
            connection_key = mysql.raw("md5(" .. mysql.escape_literal(self.params.key) .. ")");
            uid = mysql.select("robloxid from users where username=?", self.session.user)[1].robloxid;
        });

        local function make_meta(key, value)
            mysql.insert(mysql.raw(mysql.escape_identifier("meta_" .. self.params.gid)), {
                key = key,
                value = value
            });
        end
        make_meta("usedReward", 0);
        make_meta("usedSpace", 0);
        make_meta("name", self.params.game_name);

        return "<script>window.location.replace('/game/" .. self.params.gid .. "');</script>";
    end
});
app:match("achievement", "/game/:gid/achievements/:achvid", respond_to{
    -- TODO
});

app:match("logout", "/logout", function(self)
    self.session.user = nil;
    return {redirect_to = self:url_for('root')};
end);

app:match("webapi", "/webapi/:section", function(self)

end);

app:post("/validate_modal/:modal/:field", json_params(function(self)
    return {layout = false, json = require("modals." .. self.params.modal .. "-validate")[self.params.field](self.params)};
end));

app:match("/gskw/g_all/ible", -- This was the april fools prank from last year.
    function(self)            -- http://forum.roblox.com/Forum/ShowPost.aspx?PostID=159105488
      return "<h1 style='color: red'>APRIL FOOLS!</h1>";
    end
);

app:match("/api/:module/:funct/:gid/:cokey", json_params(capture_errors({
  on_error = err_func;
  function(self)
    local success, message = pcall(function() result = intmodules[self.params.module][self.params.funct](self); end);
    if not success then
      yield_error(message, self.params);
    end
    return  {render = "empty"; layout = false; content_type = "application/json"; json = result};
  end
})));

--[[app:match("/api/:module/:funct/:gid/:cokey/:valkargs", capture_errors({
  on_error = err_func;
  function(self)
    local result       = nil;
    local success, message = pcall(function() result = intmodules[self.params.module][self.params.funct](self, parser.parse(self.params.valkargs)); end);
    if not success then
      yield_error(message);
    end
    return  {render = "empty"; layout = false; content_type = "text/valkyrie-return"; result};
  end
}));]]

app:match("/item-thumbnails-proxy", function(self) -- I HATE YOU ROBLOX
    return {render = "empty"; layout = false; content_type = "application/json"; ({http.simple("http://www.roblox.com/item-thumbnails?" .. util.encode_query_string(self.params))})[1]};
end);

return app;
