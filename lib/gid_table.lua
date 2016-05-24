local MySQL 		= require "lapis.db";

return function(Table, GID)
	return MySQL.raw(MySQL.escape_identifier(Table .. "_" .. GID));
end;
