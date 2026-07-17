--- Reusable POSIX shell helpers for user widgets.
local M = {}

--- Returns one value safely quoted as a single POSIX shell argument.
function M.quote(value)
	return "'" .. tostring(value or ""):gsub("'", [['"'"']]) .. "'"
end

return M
