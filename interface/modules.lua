local Module                  = {};
local Modules                 = require "interface.modulespec";
local Auth                    = require("lib.check_cokey");
local Inspect                 = require("inspect");
local Perms                   = require("lib.permissions");

Module                        = setmetatable(Module, {
  __index                     = function(self, Module)
    Perms.ParsePermissions();
    local ModuleMeta  = Modules[Module];
    if ModuleMeta == nil then
      error("Invalid module name!");
    end

    local Lib                 = require("lib."..ModuleMeta.LibName);

    return setmetatable({}, {
      __index                 = function(self2, FuncName)
        local FunctionMeta    = ModuleMeta.Functions[FuncName];
        if not FunctionMeta then
          error("Invalid function name!");
        end
        return function(Request)
          local PassArgs      = {};
          local MissingArgs   = {};
          local Request       = Request.params;

          for i = 1, #FunctionMeta do
            local MetaType    = type(FunctionMeta[i]);
            local RequiredArg = MetaType == "string" and FunctionMeta[i] or FunctionMeta[i].Name;

            if Request[RequiredArg] ~= nil then
              table.insert(PassArgs, Request[RequiredArg]);
            else
              if MetaType == "table" and FunctionMeta[i].NoRequire then
                table.insert(PassArgs, FunctionMeta[i].Default);
              else
                table.insert(MissingArgs, RequiredArg);
              end
            end -- if parsedbody
          end -- for

          if #MissingArgs ~= 0 then
            error("Missing arguments: " .. table.concat(MissingArgs, ", "));
          end

          if not Perms.GetPermission(Request.GID, "Modules.Require") then
            return {success = false; error = "You do not have the permission Modules.Require"};
          elseif not Perms.GetPermission(Request.GID, "Modules.Function") then
            return {success = false; error = "You do not have the permission Modules.Function"};
          elseif not Perms.GetPermission(Request.GID, ("%s.%s"):format(Module, FuncName)) then
            return {success = false; error = "You do not have the permission " .. ("%s.%s"):format(Module, FuncName)};
          end

          if not ModuleMeta.SkipAuth then
            Auth.CheckNoUID(Request.GID, Request.CoKey);
          end

          return {success = true; error = ""; result = Lib[FuncName](unpack(PassArgs))};
        end; -- return
      end; -- __index
    }); -- setmetatable
  end; -- __index
}); -- setmetatable

return Module;
