local M = {}

-- Merges one widget update table back into the live widget state.
local function merge_update(widget, update)
	if type(update) ~= "table" then
		return
	end

	for key, value in pairs(update) do
		widget[key] = value
	end
end

-- Lists all Lua widget files in one directory.
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

-- Runs the synthetic init event for a widget.
local function run_widget_init(widget, log)
	if type(widget.on_event) ~= "function" then
		return
	end

	local ok, result = pcall(widget.on_event, "init", {})
	if ok and type(result) == "table" then
		merge_update(widget, result)
		return
	end

	if not ok then
		log.error("widget " .. widget.id .. " init failed error=" .. tostring(result))
	end
end

-- Loads and executes one widget file.
local function load_widget_file(widget_dir, file, widgets, render, log, json)
	local path = widget_dir .. "/" .. file
	local chunk, load_err = loadfile(path)

	if not chunk then
		log.error("loader failed to load file=" .. file .. " error=" .. tostring(load_err))
		return
	end

	local ok, widget = pcall(chunk)
	if not ok then
		log.error("loader failed to execute file=" .. file .. " error=" .. tostring(widget))
		return
	end

	if type(widget) ~= "table" then
		log.error("loader file=" .. file .. " returned " .. type(widget) .. " instead of table")
		return
	end

	widget.__file = file
	widget.id = widget.id or file
	widget.position = widget.position or "right"
	widget.order = tonumber(widget.order or 0) or 0

	widgets[widget.id] = widget
	log.info("loader loaded file=" .. file .. " id=" .. widget.id)

	run_widget_init(widget, log)
	render.emit_tree(widget, log, json)
end

-- Loads all widgets and emits the initial ready message.
function M.load_widgets(widget_dir, widgets, render, log, json)
	log.info("runtime started")
	log.info("runtime widget_dir=" .. widget_dir)

	io.stdout:write('{"type":"ready"}\n')
	io.stdout:flush()

	for _, file in ipairs(list_widget_files(widget_dir)) do
		load_widget_file(widget_dir, file, widgets, render, log, json)
	end
end

return M
