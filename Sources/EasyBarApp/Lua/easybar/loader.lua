--- Module contract:
--- Owns widget file discovery, isolated load environments, and widget startup.
--- Returns one helper that loads every widget in one directory.
--- Widget loader module table.
local M = {}

--- Builds one isolated environment for a widget file.
local function make_widget_env(registry, file)
	local env = {
		-- Each widget gets its own scoped EasyBar API instance.
		easybar = registry.make_widget_api(file),
	}

	setmetatable(env, {
		__index = _G,
	})

	return env
end

--- Loads and executes one widget file.
local function load_widget_file(widget_dir, file, registry, log)
	local path = widget_dir .. "/" .. file
	local env = make_widget_env(registry, file)
	local chunk, load_err = loadfile(path, "t", env)

	if not chunk then
		log.error("loader failed to load file=" .. file .. " error=" .. tostring(load_err))
		return
	end

	local ok, err = pcall(chunk)

	if not ok then
		log.error("loader failed to execute file=" .. file .. " error=" .. tostring(err))
		return
	end

	log.info("loader loaded file=" .. file)
end

--- Loads every widget file from the configured widget directory.
function M.load_widgets(widget_dir, widget_files, registry, log)
	log.info("runtime started")
	log.info("runtime widget_dir=" .. widget_dir)

	for _, file in ipairs(widget_files or {}) do
		load_widget_file(widget_dir, file, registry, log)
	end
end

return M
