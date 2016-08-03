local GameUtils  = {};
local MySQL      = require"lapis.db";
local AppHelpers = require"lapis.application";
local YieldError = AppHelpers.yield_error;

local Cache      = {};

function GameUtils.GIDToInternal(GID)
    if Cache[GID] then return Cache[GID]; end
    local Result = MySQL.select("id from game_ids where gid=?", GID);
    if not Result[1] then
        YieldError("GID " .. GID .. " does not exist");
    end
    Cache[GID]   = Result[1].id;
    return Result[1].id;
end

function GameUtils.GetOnlinePlayers(GID)
    return MySQL.select("b.robloxid as robloxid from player_ingame a left join player_info b on a.player=b.id where gid=? order by a.id desc", GameUtils.GIDToInternal(GID));
end

return GameUtils;
