local M = {}

local function list_widget_files(widget_dir)
	local files = {}
	local command = 'ls "' .. widget_dir .. '" 2>/dev/null'

	local pipe = io.popen(command)
	if not pipe then
		return files
	end

	for file in pipe:lines() do
		if file:match("%.lua$") then
			files[#files + 1] = file
		end
	end

	pipe:close()
	table.sort(files)

	return files
end

local function make_widget_env(registry)
	local env = {
		easybar = registry,
	}

	setmetatable(env, {
		__index = _G,
	})

	return env
end

local function load_widget_file(widget_dir, file, registry, log)
	local path = widget_dir .. "/" .. file
	local env = make_widget_env(registry)
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

function M.load_widgets(widget_dir, registry, log)
	log.info("runtime started")
	log.info("runtime widget_dir=" .. widget_dir)

	for _, file in ipairs(list_widget_files(widget_dir)) do
		load_widget_file(widget_dir, file, registry, log)
	end
end

return M
