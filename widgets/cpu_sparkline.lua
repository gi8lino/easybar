local history = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }

local function read_cpu()
	local handle = io.popen("ps -A -o %cpu | awk '{s+=$1} END {print s}' 2>/dev/null")
	if not handle then
		return 0
	end

	local value = tonumber(handle:read("*a")) or 0
	handle:close()

	if value > 100 then
		value = 100
	end

	return value
end

local function push_value(value)
	table.remove(history, 1)
	table.insert(history, value)
end

easybar.add(easybar.kind.sparkline, "cpu_sparkline", {
	position = "right",
	order = 60,
	interval = 1,
	icon = {
		string = "󰍛",
		color = "#a6da95",
	},
	label = {
		string = "CPU",
		color = "#a6da95",
	},
	values = history,
	line_width = 1.8,
	width = 64,
	height = 18,
	on_interval = function()
		push_value(read_cpu())

		easybar.set("cpu_sparkline", {
			values = history,
		})
	end,
})

easybar.subscribe("cpu_sparkline", easybar.events.forced, function()
	push_value(read_cpu())

	easybar.set("cpu_sparkline", {
		values = history,
	})
end)

push_value(read_cpu())

easybar.set("cpu_sparkline", {
	values = history,
})
