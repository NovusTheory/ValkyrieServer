local Lapis       = require("lapis");
local App         = Lapis.Application();
local Cache       = require("lapis.cache");

local Modules    = require "interface.modules";
local AppHelpers = require"lapis.application";

local respond_to     = AppHelpers.respond_to;
local capture_errors = AppHelpers.capture_errors;
local yield_error    = AppHelpers.yield_error;
local json_params    = AppHelpers.json_params;

local BanLib     = require "lib.bans";
local GameUtil   = require "lib.game_utils";
local UserInfo   = require "lib.userinfo";

local MySQL       = require "lapis.db";
local LapisHTTP   = require "lapis.nginx.http";
local LapisUtil   = require "lapis.util";
local JSONLib     = require "cjson";
local BuildRequest, HTTPRequestSSL, HTTPRequest, StripHeaders, Login, DataRequest, RunPostBack, FindPostState, HTTPGet = unpack(require("lib.httputil"));

local cachefunc = function(URL, X, self)
    return (self.session.User or "") .. URL;
end

App:enable"etlua"
App.layout = require("views.head");

App:before_filter(function(self)
    self.SignedIn = self.session.User;
end);

App:get("root", "/", function(self)
    return {render = "landing"};
end);

function ErrorFunction(self)
    return    {render = "empty"; layout = false; content_type = "application/json"; json = {success = false; error = self.errors[1]}};
end

App:match("getValkyrie", "/get", function(self)
    self.Title = "Get Valkyrie";
    return {render=true};
end);

App:match("friends", "/friends", function(self)
    self.Title = "Friends";
    return {render=true};
end);

App:match("login", "/login", respond_to{
    before = function(self)
        if self.SignedIn then
            self:write({redirect_to = "/"});
        end
    end;
    GET = function(self)
        self.Invalid = {};
        self.Title = "Valkyrie Login";
        return {render = true};
    end,
    POST = function(self)
        self.Invalid = {};
        self.Bare = true;
        if not self.params.Username or #self.params.Username < 1 then
            self.Invalid.Username = "Enter a username";
        end
        if not self.params.Password or #self.params.Password < 1 then
            self.Invalid.Password = "Enter a password";
        end
        if #self.Invalid > 0 then
            return {layout = false; render = true};
        end

        if MySQL.select("count(*) from users where username=? and password=?", self.params.Username, MySQL.raw("sha2(" .. MySQL.escape_literal(self.params.Password) .. ", 256)"))[1]["count(*)"] == "1" then
            self.session.User = self.params.Username;
            return "<script>window.location.replace('/')</script>";
        else
            self.Invalid.Password = "The username and password do not match";
            return {layout = false; render = true};
        end
    end}
);

App:match("signup1", "/signup/1", respond_to{
    before = function(self)
        if self.SignedIn then
            self:write({redirect_to = "/"});
        end
    end;
    GET = function(self)
        self.Missing = {};
        self.Bare = true;
        self.Page = "signup";
        return {render = "signup", layout = false};
    end;
    POST = function(self)
        local Invalid = {};
        self.Bare = true;
        if not self.params.Username or self.params.Username == "" then
            Invalid.Username = "Enter a username";
        end
        if not self.params.Password or self.params.Password == "" then
            Invalid.Password = "Enter a password";
        end;

        if not Invalid.Username then
            if self.params.Username:len() > 20 then
                Invalid.Username = "There is no such user on Roblox";
            elseif MySQL.select("count(*) from users where username=?", self.params.Username)[1]["count(*)"] ~= "0" then
                Invalid.Username = "This username is already in use";
            elseif ({LapisHTTP.simple("https://api.roblox.com/users/get-by-username?username=" .. self.params.Username)})[1] == '{"success":false,"errorMessage":"User not found"}' then
                Invalid.Username = "There is no such user on Roblox";
            end
        end

        if not Invalid.password then
            if self.params.Password:len() < 6 or self.params.Password:len() > 50 then
                Invalid.Password = "Passwords must be between 6 and 50 characters";
            end
        end

        if Invalid.Username or Invalid.Password then
            self.Invalid = Invalid;
            self.Page = "signup";

            return {render = "signup", layout = false};
        else
            self.Page = "signup2";
            return {render = "signup", layout = false};
        end
    end;
});

App:get('features','/features',function(self)
    return {render=true};
end);

local function CheckCanMessage(ID, Cookie, Force)
    local HTML = HTTPGet("https://www.roblox.com/users/" .. ID .. "/profile", "Cookie: " .. Cookie .. "\n");
    if HTML:match 'data%-userid="0"' then
        if Force then
            error "ROBLOX LOGIN FAILED! Please tell gskw. Remember to include the time this happened at.";
        end
        CheckCanMessage(ID, Login(), true);
    end
    return not not HTML:match 'data%-canmessage=true';
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

local function CheckSentMessage(ID, Token, Cookie, Force)
    local Result = HTTPGet("https://www.roblox.com/messages/api/get-messages?messageTab=0&pageNumber=0&pageSize=20", "Cookie: " .. Cookie .. "\n");
    if Result:match("^HTTP/1.1 302 Found\r\nCache%-Control: private\r\nContent%-Type: text/html; charset=utf%-8\r\nLocation:") then
        if Force then
            error "ROBLOX LOGIN FAILED! Please tell gskw. Remember to include the time this happened at.";
        end
        CheckSentMessage(ID, Token, Login(), true);
    end
    Result = JSONLib.decode(Result:match("\r\n\r\n(.*)$"));
    for i = 1, #Result.Collection do
        if tonumber(Result.Collection[i].Sender.UserId) == tonumber(ID) then
            if htmlunentities(Result.Collection[i].Body):find(Token, 1, true) then
                return true;
            else
                print(htmlunentities(Result.Collection[i].Body))
            end
        end
    end
    return false;
end

App:match("signup2", "/signup/2", respond_to{
    before = function(self)
        if self.SignedIn then
            self:write({redirect_to = "/"});
        end
    end;
    GET = function(self)
        self.Page = "signup2";
        return {render = "signup", layout = false};
    end;
    POST = function(self)
        -- Sanity-check all information again
        local Invalid = {};
        self.Bare = true;
        if not self.params.Username or self.params.Username == "" then
            Invalid.username = "Enter a username";
        end
        if not self.params.Password or self.params.Password == "" then
            Invalid.Password = "Enter a password";
        end;

        if not Invalid.Username then
            if self.params.Username:len() > 20 then
                Invalid.Username = "There is no such user on Roblox";
            elseif MySQL.select("count(*) from users where username=?", self.params.Username)[1]["count(*)"] ~= "0" then
                Invalid.Username = "This username is already in use";
            elseif ({LapisHTTP.simple("https://api.roblox.com/users/get-by-username?username=" .. self.params.Username)})[1] == '{"success":false,"errorMessage":"User not found"}' then
                Invalid.Username = "There is no such user on Roblox";
            end
        end

        if not Invalid.Password then
            if self.params.Password:len() < 6 or self.params.Password:len() > 50 then
                Invalid.Password = "Passwords must be between 6 and 50 characters";
            end
        end

        if Invalid.Username or Invalid.Password then
            self.Invalid = Invalid;
            self.Page = "signup";

            return {render = "signup", layout = false};
        end


        -- New code starts here
        local UserID = ({LapisHTTP.simple("https://api.roblox.com/users/get-by-username?username=" .. self.params.Username)})[1]:match('{"Id":(%d+)');
        local CanMessage = CheckCanMessage(UserID, io.open "security.sec":read "*a");
        if not CanMessage then
            self._Error = "Your privacy settings are configured wrong! Please double-check them!";
        end
        --
        -- TODO: Check for valid token. It's not that important though; I doubt anybody will message ValkyrieBot by accident
        local HasSentMessage = CheckSentMessage(UserID, self.params.Token, io.open "security.sec":read "*a");
        if not HasSentMessage then
            self._Error = "You didn't send a message to ValkyrieBot!";
        end

        if self._Error then
            self.Page = "signup2";
            return {render = "signup", layout = false};
        end

        self.Page = "signup3";

        MySQL.insert("users", {
            username = self.params.Username;
            password = MySQL.raw("sha2(" .. MySQL.escape_literal(self.params.Password) .. ", 256)");
            robloxid = UserID;
        });
        self.SignedIn = true;
        self.session.User = self.params.Username;

        return {render = "signup", layout = false};
    end;
});

App:match("signup", "/signup", respond_to{
    before = function(self)
        if self.SignedIn then
            self:write({redirect_to = "/"});
        end
    end;
    GET = function(self)
        self.Invalid = {};
        self.Page = "signup";
        return {render = true};
    end;
    POST = function(self)
        self.Invalid = {};
        self.Page = "signup";
        self.Bare = true;
        return {render = true, layout = false};
    end
});
App:match("/validate/:Name", function(self) -- Check if username is valid for signup
    return {render = "empty", layout = false, tostring(MySQL.select("count(*) from users where username=?", self.params.Name)[1]["count(*)"] == "0")};
end);

App:match("gamelist", "/user/:User/games", function(self)
    if not self.session.User then
        return {redirect_to = self:url_for "login"};
    end
    self.library = library;
    return {render = true};
end);

local CSRF = require "lapis.csrf";

App:match("newgame", "/game/new", function(self)
    if not self.session.User then
        return {redirect_to = self:url_for "login"};
    end
    self.Invalid = {};
    self.Bare = false;
    self.Library = Library;
    self.CSRFToken = CSRF.generate_token(self, self.session.User); -- Has to be done here for access to 'self'
    -- Or it might work in etlua with getfenv(), but I'm not sure
    return {render = true};
end);

App:match("game", "/game/:GID", respond_to{
    GET = function(self)
        if self.session.User then
          self.CSRFToken = CSRF.generate_token(self, self.session.User)
        end
        return {render = true};
    end,
    PUT = function(self)
        if self.session.User == nil then
            return {redirect_to = self:url_for("login")};
        end
        self.CSRFToken = self.params.CRSFToken;
        self.Invalid = {};

        if not CSRF.validate_token(self, self.session.User) then
            self.Invalid.GID = "Error: Invalid CSRF Token! (This message should never be displayed on a browser. If it has, contant gskw)";
        end

        if not self.params.GID or #self.params.GID < 1 then
            self.Invalid.GID = "Enter a GID";
        end
        if not self.params.GameName or #self.params.GameName < 1 then
            self.Invalid.GameName = "Enter a game name";
        end
        if not self.params.Key or #self.params.Key < 1 then
            self.Invalid.Key = "Enter a key";
        end

        if MySQL.select("count(*) from game_ids where gid=?", self.params.GID)[1]["count(*)"] == "1" then
            self.Invalid.GID = "This GID is already in use!";
            self.Bare = true;
            return {layout = false; render = "newgame"};
        end

        if MySQL.select("count(*) from game_ids where owner=(select id from users where username=?)", self.session.User)[1]["count(*)"] == "5" then
            self.Invalid.GID = "You already own 5 games!";
        end

        if self.params.GID:find "\n" then
            self.Invalid.GID = "GIDs can't contain newlines";
        end

        if self.Invalid.GID or self.Invalid.Key or self.Invalid.GameName then
            self.Bare = true;
            return {layout = false; render = "newgame"};
        end

        ----- DEFAULT PERMISSIONS!
        io.open("permissions.perms", "a"):write(self.params.GID .. "\n!Basic\n:");
        MySQL.insert("game_ids", {
            gid = self.params.GID;
            cokey = MySQL.raw("sha2(" .. MySQL.escape_literal(self.params.Key) .. ", 256)");
            owner = MySQL.select("id from users where username=?", self.session.User)[1].id;
            uses_md5 = false;
        });

        MySQL.insert("trusted_users", {
            connection_key = MySQL.raw("sha2(" .. MySQL.escape_literal(self.params.Key) .. ", 256)");
            uses_md5 = false;
            uid = MySQL.select("robloxid from users where username=?", self.session.User)[1].robloxid;
            gid = MySQL.select("id from game_ids where gid=?", self.params.GID)[1].id;
        });

        local function MakeMeta(Key, Value)
            MySQL.insert("meta", {
                key = Key,
                value = Value,
                gid = MySQL.select("id from game_ids where gid=?", self.params.GID)[1].id;
            });
        end
        MakeMeta("usedReward", 0);
        MakeMeta("usedSpace", 0);
        MakeMeta("name", self.params.GameName);

        return "<script>window.location.replace('/game/" .. self.params.GID .. "');</script>";
    end,
    DELETE = function(self)
      if self.session.User == nil then
        return {redirect_to = self:url_for("login")};
      end
        -- Should this be done? This would save the CSRFToken for the session (kind of)
        --self.CSRFToken = self.params.csrf_token;
        self.Invalid = {};

        if not CSRF.validate_token(self, self.session.User) then
          self.Invalid.GID = "Error: Invalid CSRF Token! (This message should never be displayed on a browser. If it has, contant gskw)";
          return {json = {success = false, error = self.Invalid}}
        end
        
        if MySQL.select("count(b.id) from users a left join game_ids b on b.owner = a.id where a.username = ? and b.gid = ?", self.session.User, self.params.GID)[1]["count(b.id)"] == "1" then
            if MySQL.delete("game_ids", { gid = self.params.GID }) then
              return {json = {success = true}};
            end
        else
          self.Invalid.GID = "Error: User does not own GID"
        end
        
        return {json = {success = false, error = self.Invalid}}
    end
});

-- GET query ?Page=1 returns 100 bans and calling a higher number returns the next 100 bans
App:match("game_bans", "/game/:GID/bans(/:ID)", respond_to{
  GET = function(self)
    if self.session.User then
      local function getBans(page)
        if MySQL.select("count(b.id) from users a left join game_ids b on b.owner = a.id where a.username = ? and b.gid = ?", self.session.User, self.params.GID)[1]["count(b.id)"] == "1" then
          local limit = page * 100
          local offset = limit - 100
          local gid = GameUtil.GIDToInternal(self.params.GID);
          local count = MySQL.select("count(*) as count from bans where from_gid=? and global=0", gid)[1]["count"]
          local result = MySQL.select("b.robloxid as Player, a.reason as Reason from bans a left join player_info b on b.id=a.player where a.from_gid=? limit ? offset ?", gid, limit, offset);
          
          return {json = {success = true, result = {count = count, bans = result}}}
        else
          return {json = {success = false, error = "User does not own GID"}, status = 403}
        end
      end
      
      local function getBan(id)
        if MySQL.select("count(b.id) from users a left join game_ids b on b.owner = a.id where a.username = ? and b.gid = ?", self.session.User, self.params.GID)[1]["count(b.id)"] == "1" then
          local gid = GameUtil.GIDToInternal(self.params.GID);
          local result = MySQL.select("b.robloxid as Player, a.reason as Reason from bans a left join player_info b on b.id=a.player where a.from_gid=? and a.player=b.id", gid);
          
          return {json = {success = true, result = result}}
        else
          return {json = {success = false, error = "User does not own GID"}, status = 403}
        end
      end
      
      if self.params.ID then
        return getBan(self.params.ID)
      else
        if self.params.Page then
          return getBans(self.params.Page);
        else
          return getBans(1);
        end
      end
    else
      return {json = {success = false, error = "403 Unauthorized Access"}, status = 403}
    end
  end,
  
  PUT = function(self)
    if self.session.User then
      if MySQL.select("count(b.id) from users a left join game_ids b on b.owner = a.id where a.username = ? and b.gid = ?", self.session.User, self.params.GID)[1]["count(b.id)"] == "1" then
        self.Invalid = {}
        
        if not CSRF.validate_token(self, self.session.User) then
          self.Invalid.GID = "Error: Invalid CSRF Token! (This message should never be displayed on a browser. If it has, contant gskw)";
          return {json = {success = false, error = self.Invalid}}
        end
        
        UserInfo.TryCreateUser(self.params.Player);
               
        local Success, Message = pcall(function() BanLib.CreateGameBan(self.params.GID, self.params.Player, self.params.Reason) end)
        if not Success then
          self.Invalid.Message = "Failed to create ban" --Message (real variable)
        else
          return {json = {success = true}}
        end
        
        return {json = {success = false, error = self.Invalid}}
      else
        return {json = {success = false, error = "User does not own GID"}, status = 403}
      end
    else
      return {json = {success = false, error = "403 Unauthorized Access"}, status = 403}
    end
  end,
  
  DELETE = function(self)
    if self.session.User then
      if MySQL.select("count(b.id) from users a left join game_ids b on b.owner = a.id where a.username = ? and b.gid = ?", self.session.User, self.params.GID)[1]["count(b.id)"] == "1" then
        self.Invalid = {}
        
        if not CSRF.validate_token(self, self.session.User) then
          self.Invalid.GID = "Error: Invalid CSRF Token! (This message should never be displayed on a browser. If it has, contant gskw)";
          return {json = {success = false, error = self.Invalid}}
        end
        
        local Success, Message = pcall(function() BanLib.RemoveGameBan(self.params.GID, self.params.ID) end)
        if not Success then
          self.Invalid.Message = Message--"Failed to remove ban" --Message (real variable)
        else
          return {json = {success = true}}
        end
        
        return {json = {success = false, error = self.Invalid}}
      else
        return {json = {success = false, error = "User does not own GID"}, status = 403}
      end
    else
      return {json = {success = false, error = "403 Unauthorized Access"}, status = 403}
    end
  end
});

App:match("achievement", "/game/:GID/achievements/:Achievement", respond_to{
    -- TODO
});

App:match("logout", "/logout", function(self)
    self.session.User = nil;
    return {redirect_to = self:url_for('root')};
end);

App:match("webapi", "/webapi/:section", function(self)

end);

App:post("/validate_modal/:Modal/:Field", json_params(function(self)
    return {layout = false, json = require("modals." .. self.params.Modal .. "-validate")[self.params.Field](self.params)};
end));

App:match("/gskw/g_all/ible", -- This was the april fools prank from last year.
function(self)            -- http://forum.roblox.com/Forum/ShowPost.aspx?PostID=159105488
    return "<h1 style='color: red'>APRIL FOOLS!</h1>";
end
);

App:match("/api/:Module/:Function/:GID/:CoKey", json_params(capture_errors({
    on_error = ErrorFunction;
    function(self)
        self.params.CoKey = LapisUtil.unescape(self.params.CoKey);
        local Result;
        local Success, Message = pcall(function() Result = Modules[self.params.Module][self.params.Function](self); end);
        if not Success then
            yield_error(Message, self.params);
        end
        return  {render = "empty"; layout = false; content_type = "application/json"; json = Result};
    end
})));

return App;
