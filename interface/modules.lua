local Module                  = {};
local Modules                 = require "interface.modulespec";
local Auth                    = Library("check_cokey");
local Inspect                 = require("inspect");
local Perms                   = Library("permissions");

Module                        = setmetatable(Module, {
  __index                     = function(self, Module)
    Perms.ParsePermissions();
    local ModuleMeta  = Modules[Module];
    if ModuleMeta == nil then
      error("Invalid module name!");
    end

    local Lib                 = Library(ModuleMeta.LibName);

    return setmetatable({}, {
      __index                 = function(self2, FuncName)
        local FunctionMeta    = ModuleMeta.Functions[FuncName];
        if not FunctionMeta then
          error("Invalid function name!");
        end
        return function(Request)
          local PassArgs      = {};
          local MissingArgs   = {};
          local Request       = Request.Params;

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

          if not Perms.GetPermission(Request.GID, "modules.require") then
            return {success = false; error = "You do not have the permission modules.require"};
          elseif not Perms.GetPermission(Request.GID, "modules.function") then
            return {success = false; error = "You do not have the permission modules.function"};
          elseif not Perms.GetPermission(Request.GID, ("%s.%s"):format(Module, FuncName)) then
            return {success = false; error = "You do not have the permission " .. ("%s.%s"):Format(Module, FuncName)};
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

return module;
