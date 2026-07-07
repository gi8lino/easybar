--- Tailscale widget for EasyBar.
---
--- Left click toggles Tailscale up/down.
--- Right click toggles automatic exit-node usage.
---
--- This personal widget intentionally keeps command construction simple:
--- TAILSCALE may point to a command/path such as `tailscale` or `/opt/homebrew/bin/tailscale`.
--- Paths with spaces are not supported.

local CHECK_INTERVAL_SECONDS = 60

local function trim(value)
	return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local COLORS = {
	text = easybar.theme.ref.text,
	muted = easybar.theme.ref.muted,
	success = easybar.theme.ref.success,
	accent = easybar.theme.ref.accent,
	popup_bg = easybar.theme.ref.background,
	border = easybar.theme.ref.border_strong,
}

local COMMAND_OPTIONS = {
	timeout_seconds = 10,
	max_output_bytes = 65536,
}

local ACTION_COMMAND_OPTIONS = {
	timeout_seconds = 30,
	max_output_bytes = 65536,
}

local TAILSCALE = trim(os.getenv("TAILSCALE") or "")
if TAILSCALE == "" then
	TAILSCALE = "tailscale"
end

local tailscale_icon
local popup_label
local popup_exit_node_label

local state = {
	available = false,
	tailscale_connected = false,
	exit_node_enabled = false,
	status_detail = "Inactive",
	exit_node_detail = "Exit node unavailable",
}

local refresh

-- Guards against older slower async status reads overwriting newer refresh results.
local refresh_generation = 0
--
-- Prevents double-clicks from starting overlapping up/down or exit-node commands.
local action_running = false

local function script_dir()
	local source = debug.getinfo(1, "S").source or ""
	local path = source:gsub("^@", "")
	return path:match("(.*/)")
end

local function asset_path(name)
	local dir = script_dir()
	if dir == nil then
		return name
	end

	return dir .. "assets/" .. name
end

local function tailscale_command(args)
	return TAILSCALE .. " " .. args
end

--- Runs a Tailscale CLI command asynchronously and normalizes output/code.
local function run_command(command, options, callback)
	easybar.exec_async(command, options or COMMAND_OPTIONS, function(output, code)
		output = trim(output or "")
		code = code or 0

		callback(output, code == 0, code)
	end)
end

local function log_command_result(action, command, output, ok, code)
	if ok then
		if output ~= "" then
			easybar.log(easybar.level.info, action .. " ok", command, output)
		else
			easybar.log(easybar.level.info, action .. " ok", command)
		end
		return
	end

	easybar.log(
		easybar.level.warn,
		action .. " failed",
		command,
		"code=" .. tostring(code),
		output ~= "" and output or "<empty>"
	)
end

--- Decodes `tailscale status --json` output into a Lua table.
local function decode_json(output)
	local ok, value = pcall(easybar.json.decode, output)
	if ok and type(value) == "table" then
		return value, nil
	end

	return nil, value
end

local function status_label(connected)
	return connected and "Active" or "Inactive"
end

local function first_health_message(status)
	local health = status.Health
	if type(health) ~= "table" then
		return nil
	end

	for _, message in ipairs(health) do
		if type(message) == "string" and trim(message) ~= "" then
			return trim(message)
		end
	end

	return nil
end

local function has_exit_node(status)
	return status.ExitNodeStatus ~= nil
end

local function unavailable_snapshot(detail)
	return {
		available = false,
		tailscale_connected = false,
		exit_node_enabled = false,
		status_detail = detail or "Unavailable",
		exit_node_detail = "Exit node unavailable",
	}
end

--- Converts raw `tailscale status --json` data into widget state.
local function snapshot_from_status(status)
	local backend_state = trim(status.BackendState or "")
	local connected = backend_state == "Running"
	local health_message = first_health_message(status)

	local status_detail = trim(health_message or backend_state)
	if status_detail == "" then
		status_detail = status_label(connected)
	end

	local exit_node_enabled = connected and has_exit_node(status)

	local exit_node_detail
	if not connected then
		exit_node_detail = "Exit node unavailable"
	elseif exit_node_enabled then
		exit_node_detail = "Exit node on"
	else
		exit_node_detail = "Exit node off"
	end

	return {
		available = true,
		tailscale_connected = connected,
		exit_node_enabled = exit_node_enabled,
		status_detail = status_detail,
		exit_node_detail = exit_node_detail,
	}
end

--- Reads current Tailscale status and returns a normalized snapshot.
local function read_status(callback)
	local command = tailscale_command("status --json")

	run_command(command, COMMAND_OPTIONS, function(output, ok, code)
		if not ok then
			easybar.log(
				easybar.level.warn,
				"tailscale status failed",
				"code=" .. tostring(code),
				output ~= "" and output or "<empty>"
			)

			callback(unavailable_snapshot("Unavailable"))
			return
		end

		if output == "" then
			easybar.log(easybar.level.warn, "tailscale status returned empty output")
			callback(unavailable_snapshot("Unavailable"))
			return
		end

		local status, err = decode_json(output)
		if status == nil then
			easybar.log(easybar.level.warn, "tailscale status JSON decode failed", tostring(err))
			callback(unavailable_snapshot("Invalid status output"))
			return
		end

		callback(snapshot_from_status(status))
	end)
end

--- Stores the latest snapshot and logs meaningful state transitions.
local function update_state(snapshot)
	if state.tailscale_connected ~= snapshot.tailscale_connected then
		easybar.log(
			easybar.level.debug,
			"tailscale state changed",
			snapshot.tailscale_connected and "active" or "inactive"
		)
	end

	if state.exit_node_enabled ~= snapshot.exit_node_enabled then
		easybar.log(
			easybar.level.debug,
			"tailscale exit node changed",
			snapshot.exit_node_enabled and "enabled" or "disabled"
		)
	end

	state.available = snapshot.available
	state.tailscale_connected = snapshot.tailscale_connected
	state.exit_node_enabled = snapshot.exit_node_enabled
	state.status_detail = snapshot.status_detail
	state.exit_node_detail = snapshot.exit_node_detail

	return snapshot
end

local function current_icon_name(snapshot)
	if not snapshot.tailscale_connected then
		return "tailscale-inactive.png"
	end

	if snapshot.exit_node_enabled then
		return "tailscale-active-exit-node.png"
	end

	return "tailscale-active.png"
end

local function render(snapshot)
	local status_color = snapshot.tailscale_connected and COLORS.success or COLORS.muted
	local exit_node_color = snapshot.exit_node_enabled and COLORS.accent or COLORS.muted

	tailscale_icon:set({
		icon = {
			string = "",
			image = asset_path(current_icon_name(snapshot)),
			image_size = 16,
			image_corner_radius = 0,
		},
		label = {
			string = "",
		},
		opacity = 1.0,
	})

	popup_label:set({
		label = {
			string = snapshot.status_detail or status_label(snapshot.tailscale_connected),
			color = status_color,
		},
	})

	popup_exit_node_label:set({
		drawing = snapshot.tailscale_connected and "on" or "off",
		label = {
			string = snapshot.exit_node_detail,
			color = exit_node_color,
		},
	})
end

local function render_working(text)
	if popup_label == nil then
		return
	end

	popup_label:set({
		label = {
			string = text,
			color = COLORS.accent,
		},
	})
end

--- Re-reads status and ignores stale async results from older refreshes.
refresh = function()
	refresh_generation = refresh_generation + 1
	local generation = refresh_generation

	read_status(function(snapshot)
		if generation ~= refresh_generation then
			return
		end

		render(update_state(snapshot))
	end)
end

local function finish_action()
	action_running = false
	refresh()
end

--- Toggles Tailscale up/down while preventing overlapping actions.
local function toggle_tailscale()
	if action_running then
		easybar.log(easybar.level.debug, "tailscale toggle ignored", "action already running")
		return
	end

	action_running = true
	render_working("Working…")

	read_status(function(snapshot)
		if not snapshot.available then
			easybar.log(easybar.level.warn, "tailscale toggle skipped", "status unavailable")
			finish_action()
			return
		end

		local command
		if snapshot.tailscale_connected then
			command = tailscale_command("down")
		else
			command = tailscale_command("up")
		end

		run_command(command, ACTION_COMMAND_OPTIONS, function(output, ok, code)
			log_command_result("tailscale toggle", command, output, ok, code)
			finish_action()
		end)
	end)
end

--- Toggles automatic exit-node usage while Tailscale is active.
local function toggle_exit_node()
	if action_running then
		easybar.log(easybar.level.debug, "tailscale exit node toggle ignored", "action already running")
		return
	end

	action_running = true
	render_working("Working…")

	read_status(function(snapshot)
		if not snapshot.available then
			easybar.log(easybar.level.warn, "tailscale exit node toggle skipped", "status unavailable")
			finish_action()
			return
		end

		if not snapshot.tailscale_connected then
			easybar.log(easybar.level.warn, "tailscale exit node toggle ignored", "tailscale inactive")
			finish_action()
			return
		end

		local command
		if snapshot.exit_node_enabled then
			command = tailscale_command("set --exit-node= --accept-routes")
		else
			command = tailscale_command("set --exit-node=auto:any --accept-routes")
		end

		run_command(command, ACTION_COMMAND_OPTIONS, function(output, ok, code)
			log_command_result("tailscale exit node toggle", command, output, ok, code)
			finish_action()
		end)
	end)
end

tailscale_icon = easybar.add(easybar.kind.item, "tailscale_icon", {
	position = "right",
	order = 2,
	interval = CHECK_INTERVAL_SECONDS,
	icon = {
		image = asset_path("tailscale-inactive.png"),
		image_size = 16,
	},
	popup = {
		drawing = "on",
		background = {
			color = COLORS.popup_bg,
			border_color = COLORS.border,
			border_width = 1,
			corner_radius = 8,
		},
		padding_x = 10,
		padding_y = 8,
		spacing = 6,
	},
	on_interval = function()
		refresh()
	end,
})

popup_label = easybar.add(easybar.kind.item, "tailscale_popup_label", {
	position = "popup." .. tailscale_icon.name,
	label = {
		string = "",
		color = COLORS.text,
	},
})

popup_exit_node_label = easybar.add(easybar.kind.item, "tailscale_popup_exit_node_label", {
	position = "popup." .. tailscale_icon.name,
	drawing = "off",
	label = {
		string = "",
		color = COLORS.muted,
	},
})

tailscale_icon:subscribe({
	easybar.events.network_change,
	easybar.events.system_woke,
	easybar.events.forced,
}, function()
	refresh()
end)

tailscale_icon:subscribe(easybar.events.mouse.clicked, function(event)
	if event.button == nil or event.button == easybar.events.mouse.left_button then
		toggle_tailscale()
		return
	end

	if event.button == easybar.events.mouse.right_button then
		toggle_exit_node()
	end
end)

refresh()
