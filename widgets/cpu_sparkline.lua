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

return {
	id = "cpu_sparkline",
	kind = "sparkline",
	position = "right",
	order = 60,

	icon = "󰍛",
	text = "CPU",
	color = "#a6da95",
	lineWidth = 1.8,
	values = history,

	subscribe = { "init", "second_tick" },

	on_event = function(event, _)
		if event == "init" or event == "second_tick" then
			push_value(read_cpu())

			return {
				values = history,
			}
		end
	end,
}
