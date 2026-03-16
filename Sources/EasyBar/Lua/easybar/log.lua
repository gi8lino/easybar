local M = {}

-- Writes one structured log line to stderr.
local function write(level, message)
	io.stderr:write(level .. ": " .. tostring(message) .. "\n")
	io.stderr:flush()
end

function M.debug(message)
	write("DEBUG", message)
end

function M.info(message)
	write("INFO", message)
end

function M.error(message)
	write("ERROR", message)
end

return M
