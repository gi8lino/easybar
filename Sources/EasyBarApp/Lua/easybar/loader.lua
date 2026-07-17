--- Module contract:
--- Owns widget file discovery, user-library search paths, isolated load environments, and widget startup.
--- Returns one helper that loads every widget in one directory.
--- Widget loader module table.
local M = {}

--- Prepends one package path entry unless it is already configured.
local function prepend_package_path(entry)
	for existing in package.path:gmatch("[^;]+") do
		if existing == entry then
			return
		end
	end

	package.path = entry .. ";" .. package.path
end

--- Makes modules below `<widgets_dir>/lib` available through standard `require` calls.
local function configure_widget_library_path(widget_dir)
	-- Prepend in reverse order so direct module files are checked before package init files.
	prepend_package_path(widget_dir .. "/lib/?/init.lua")
	prepend_package_path(widget_dir .. "/lib/?.lua")
end

--- Builds one isolated environment for a widget file.
local function make_widget_env(registry, source_path)
	local env = {
		-- Each widget gets its own scoped EasyBar API instance.
		easybar = registry.make_widget_api(source_path),
	}

	setmetatable(env, {
		__index = _G,
	})

	return env
end

--- Loads and executes one widget file.
local function load_widget_file(widget_dir, file, registry, log)
	local path = widget_dir .. "/" .. file
	local env = make_widget_env(registry, path)
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

	log.debug("loader loaded file=" .. file)
end

--- Loads every widget file from the configured widget directory.
function M.load_widgets(widget_dir, widget_files, registry, log)
	log.debug("runtime started")
	log.debug("runtime widget_dir=" .. widget_dir)

	configure_widget_library_path(widget_dir)
	log.debug("runtime widget_lib=" .. widget_dir .. "/lib")

	for _, file in ipairs(widget_files or {}) do
		load_widget_file(widget_dir, file, registry, log)
	end
end

return M
