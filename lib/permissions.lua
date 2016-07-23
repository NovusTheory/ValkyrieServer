local Module         = {};
local PermissionFile = io.open("permissions.perms", "r");
local Permissions    = {};
local AppHelpers     = require "lapis.application";
local AllPermissions = {
  Modules            = {
    "Require";
    "Function";
  };
  Achievements      = {
    "Award";
    "Create";
    "List";
    "GetReward";
  };
  Auth              = {
    "Check";
  };
  Loadstring        = {
    "Load";
    "LockAsset";
  };
  Messages          = {
    "AddMessage";
    "CheckMessages";
  };
  PlayerInfo        = {
    "GetUserinfo";
    "TryCreateUser";
  };
  Friends           = {
    "GetFriends";
    "SetOnlineGame";
    "GoOffline";
  };
  DataStore         = {
    "SaveData";
    "LoadData";
    "GetSpace";
    "ListKeys";
  };
  Bans              = {
    "CreateBan";
    "IsBanned";
  };
  ["*"]             = {
    "Modules.*";
    "Achievements.*";
    "Auth.*";
    "Loadstring.*";
    "Messages.*";
    "PlayerInfo.*";
    "Friends.*";
    "DataStore.*";
    "Bans.*";
  };
};

local CurrentPermissions  = {Allow = {}, Deny = {}};

-- Do not try to understand this function. It works, k?
local function InsertRecursively(Table, Path, Value, PreviousValue)
  if Path:sub(1, 1) == "*" then
    if PreviousValue then
      for Index, Name in next, AllPermissions[PreviousValue] do
        if Name:find("*") then
          InsertRecursively(Table, Name, Value, nil);
        elseif not Path:find("%.") then
          Table[PreviousValue][Name] = Value;
        else
          if Table[Name:sub(1, (Name:find(".")) - 1)] == nil then
            Table[Name:sub(1, (Name:find(".")) - 1)]  = {};
          end
          InsertRecursively(Table[Name:sub(1, (Name:find(".")) - 1)], Path:sub((path:find("%.")) + 1), Value, Name);
        end
      end
    else
      InsertRecursively(Table, Path:sub((path:find("%.")) + 1), Value, "*");
    end
  end
  if not Path:find("%.") and Path:sub(1, 1) ~= "*" then
    Table[PreviousValue][Path]     = Value;
  elseif Path:sub(1, 1) ~= "*" then
    if Table[Path:sub(1, (Path:find("%.")) - 1)] == nil then
      Table[Path:sub(1, (Path:find("%.")) - 1)]  = {};
    end
    InsertRecursively(Table, Path:sub((Path:find("%.")) + 1), Value, Path:sub(1, (Path:find("%.")) - 1));
  end
end

local function GetRecursively(Table, Path)
  if not Path:find("%.") then
    return Table[Path];
  else
    if Table[Path:sub(1, (Path:find("%.")) - 1)] == nil then
      return nil;
    end
    return GetRecursively(Table[Path:sub(1, (Path:find("%.") - 1))], Path:sub((Path:find("%.") + 1)));
  end
end

function Module.ParsePermissions()
  local Line          = PermissionFile:read("*line");
  local CurrentGID    = "";
  CurrentPermissions  = {allow = {}, deny = {}}
  while Line do
    if Line:sub(1, 1) == ":" then
      if CurrentGID ~= "" then
        Permissions[CurrentGID] = CurrentPermissions;
      end
      CurrentGID    = Line:sub(2);
    elseif Line:sub(1, 1) == "+" then
      InsertRecursively(CurrentPermissions.Allow, Line:sub(2), true);
    elseif Line:sub(1, 1) == "-" then
      InsertRecursively(CurrentPermissions.Deny, Line:sub(2), true);
    end
    Line            = PermissionFile:read("*line");
  end
end

function Module.GetPermission(GID, Key)
    -- Vim's 4-width soft tabs vs Atom's 2-width soft tabs <_<

    if Permissions[GID] == nil then
        AppHelpers.yield_error("This GID does not have any permissions set, or does not exist!");
    end

  local Allowed     = GetRecursively(Permissions[GID].Allow, Key);
  local Denied      = GetRecursively(Permissions[GID].Deny, Key);

  if Allowed then
    if Denied then
      return false;
    else
      return true;
    end
  end
  return false;
end

return Module;
