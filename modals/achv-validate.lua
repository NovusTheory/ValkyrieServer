local IgnoreAbsence = {description = true};
local MySQL = require "lapis.db";
local MetaManager = require "lib.meta";

local Checks = {
    name = function(Params)
        if #Params.name > 255 then
            return "The name is too long (max 255)";
        end

        return true;
    end;
    id = function(Params)
        if #Params.id > 255 then
            return "The ID is too long (max 255)";
        end

        if MySQL.select("count(*) from ? where achv_id=?", gid_table("achievements", Params.gid), self.params.id)[1]["count(*)"] == "1" then
            return "A achievement with this ID already exists!";
        end

        return true;
    end;
    description = function(Params)
        return true;
    end;
    reward = function(Params)
        if tonumber(Params.reward) < 5 or tonumber(Params.reward) > 1000 or tonumber(Params.reward) % 5 ~= 0 then
            return "Rewards range 5-1000 points and must be multiplies of 5";
        end

        local UsedReward = MetaManager.getMeta("usedReward", Params.gid);
        if UsedReward + Params.reward > 1000 then
            return "You only have " .. (1000 - UsedReward) .. " points left";
        end

        return true;
    end;
};
return setmetatable({}, {__index = function(_, Field) 
    return function(Params)
        if (not Params[Field] or #Params[Field] < 1) and not IgnoreAbsence[Field] then
            return "Enter a value";
        else
            return Checks[Field](Params);
        end
    end
end});
