local module        = {};
local mysql         = require"lapis.db";
local app_helpers   = require"lapis.application";
local gid_table     = library"gid_table";

local yield_error   = app_helpers.yield_error;

function module.getMeta(key, gid)
  local result      = mysql.select("value from ? where `key`=?", gid_table("meta", gid), key);

  if #result == 0 then
    error("Invalid meta key!");
  end

  return result[1].value;
end

function module.setMeta(key, value, gid)
  local uniq_res    = mysql.select("value from ? where `key`=?", gid_table("meta", gid), key);

  if #uniq_res == 0 then
    mysql.insert(("meta_%s"):format(gid), {
      key           = key;
      value         = value;
    });
  else
    mysql.update(("meta_%s"):format(gid), {
      value         = value;
    }, {
      key           = key;
    });
  end
end

return module;
