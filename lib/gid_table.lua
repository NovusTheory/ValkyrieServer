local mysql 		= require "lapis.db";

return function(table, gid)
	return mysql.raw(mysql.escape_identifier(table .. "_" .. gid));
end;
