local GameUtils  = {};
local MySQL      = require"lapis.db";
local AppHelpers = require"lapis.application";
local YieldError = AppHelpers.yield_error;

function GameUtils.GIDToInternal(GID)
    local Result = MySQL.select("id from game_ids where gid=?", GID);
    if not Result[1] then
        YieldError("GID " .. GID .. " does not exist");
    end
    return Result[1].id;
end

return GameUtils;
