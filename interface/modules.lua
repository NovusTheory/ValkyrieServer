local module                  = {};
local modules                 = dofile("interface/modulespec.lua");
local parser                  = library("parse");
local encoder                 = library("encode");
local auth                    = library("check_cokey");
local inspect                 = require("inspect");
local perms                   = library("permissions");

module                        = setmetatable(module, {
  __index                     = function(self, module)
    perms.parsePermissions();
    local moduleMeta  = modules[module];
    if moduleMeta == nil then
      error("Invalid module name!");
    end

    local lib                 = library(moduleMeta.libName);

    return setmetatable({}, {
      __index                 = function(self2, funcName)
        local functionMeta    = moduleMeta.functions[funcName];
        if not functionMeta then
          error("Invalid function name!");
        end
        return function(request, parsedbody)
          local passArgs      = {};
          local missingArgs   = {};
          local request       = request.params;

          for i = 1, #functionMeta do
            local metaType    = type(functionMeta[i]);
            local requiredArg = metaType == "string" and functionMeta[i] or functionMeta[i].name;

            if parsedbody[requiredArg] ~= nil then
              table.insert(passArgs, parsedbody[requiredArg]);
            elseif request[requiredArg] ~= nil then
              table.insert(passArgs, request[requiredArg]);
            else
              if metaType == "table" and functionMeta[i].norequire then
                table.insert(passArgs, functionMeta[i].default);
              else
                table.insert(missingArgs, requiredArg);
              end
            end -- if parsedbody
          end -- for

          if #missingArgs ~= 0 then
            error("Missing arguments: " .. table.concat(missingArgs, ", "));
          end

          if not perms.getPermission(request.gid, "modules.require") then
            return encoder.encode({success = false; error = "You do not have the permission modules.require"});
          elseif not perms.getPermission(request.gid, "modules.function") then
            return encoder.encode({success = false; error = "You do not have the permission modules.function"});
          elseif not perms.getPermission(request.gid, ("%s.%s"):format(module, funcName)) then
            return encoder.encode({success = false; error = "You do not have the permission " .. ("%s.%s"):format(module, funcName)});
          end

          if not moduleMeta.skipAuth then
            auth.check_nouid(request.gid, request.cokey);
          end

          --io.write(("\27[34;1m%s.%s{\27[36m%s\27[0m} - %s:%s\n"):format(module, funcName, table.concat(passArgs, ", "), request.gid, request.cokey));
          return lib[funcName](unpack(passArgs));
        end; -- return
      end; -- __index
    }); -- setmetatable
  end; -- __index
}); -- setmetatable

return module;
