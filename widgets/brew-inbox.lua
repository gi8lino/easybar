-- Inbox-only Homebrew updates. Requires Homebrew in app.env PATH.

local shell = require("shell")
local text = require("text")

local SOURCE = "Homebrew"
local POLL_INTERVAL_SECONDS = 30 * 60

local EXEC = {
	check = { timeout_seconds = 30, max_output_bytes = 1024 * 1024 },
	update = { timeout_seconds = 5 * 60, max_output_bytes = 2 * 1024 * 1024 },
	upgrade = { timeout_seconds = 30 * 60, max_output_bytes = 4 * 1024 * 1024 },
}

local state = {
	formulae = {},
	casks = {},
	warning = nil,
	error = nil,
	operation = nil,
	active_token = nil,
	cancellation_requested = false,
}

local refresh

local function split_outdated_output(raw)
	raw = tostring(raw or "")
	local json_start = raw:find("{", 1, true)
	local json_end = nil
	if json_start ~= nil then
		for index = json_start, #raw do
			if raw:sub(index, index) == "}" then
				json_end = index
			end
		end
	end
	if json_start == nil or json_end == nil then
		return nil, nil, "Homebrew output did not contain a JSON object"
	end
	local warning = text.trim(raw:sub(1, json_start - 1) .. "\n" .. raw:sub(json_end + 1))
	return raw:sub(json_start, json_end), warning, nil
end

local function warning_source(raw)
	local owner, tap, token = tostring(raw or ""):match("/Taps/([^/]+)/homebrew%-([^/]+)/Casks/([^/]+)%.rb:%d+")
	if owner == nil then
		owner, tap, token = tostring(raw or ""):match("/Taps/([^/]+)/homebrew%-([^/]+)/Formula/([^/]+)%.rb:%d+")
	end
	if token == nil then
		return "Homebrew"
	end
	return token .. " · " .. owner .. "/" .. tap
end

local function parse_warning(raw)
	raw = text.trim(raw)
	if raw == "" then
		return nil
	end
	return {
		source = warning_source(raw),
		message = text.truncate(raw, 12000, "…"),
	}
end

local function parse_packages(entries, kind)
	local packages = {}
	for _, entry in ipairs(type(entries) == "table" and entries or {}) do
		local name = entry.name or entry.token or entry.full_token
		if type(name) == "string" and name ~= "" then
			local installed_versions = entry.installed_versions or {}
			local installed = #installed_versions > 0 and table.concat(installed_versions, ", ") or entry.installed_version
			packages[#packages + 1] = {
				id = kind .. ":" .. name,
				kind = kind,
				name = name,
				installed = text.trim(installed) ~= "" and tostring(installed) or "?",
				current = text.trim(entry.current_version) ~= "" and tostring(entry.current_version) or "?",
				pinned = entry.pinned == true,
			}
		end
	end
	table.sort(packages, function(left, right)
		return left.name < right.name
	end)
	return packages
end

local function decode_outdated(output)
	local json, warning, split_error = split_outdated_output(output)
	if json == nil then
		return nil, nil, nil, split_error
	end
	local ok, payload = pcall(easybar.json.decode, json)
	if not ok or type(payload) ~= "table" then
		return nil, nil, nil, "Homebrew returned invalid JSON"
	end
	return parse_packages(payload.formulae, "formula"), parse_packages(payload.casks, "cask"), parse_warning(warning), nil
end

local function all_packages()
	local packages = {}
	for _, package in ipairs(state.formulae) do
		packages[#packages + 1] = package
	end
	for _, package in ipairs(state.casks) do
		packages[#packages + 1] = package
	end
	return packages
end

local function publish()
	local items = {}
	for _, package in ipairs(all_packages()) do
		local actions = {}
		if not package.pinned and state.active_token == nil then
			actions = { { id = "upgrade", title = "Upgrade" } }
		end
		items[#items + 1] = {
			id = package.id,
			title = package.name,
			body = package.installed .. " → " .. package.current .. (package.pinned and " · pinned" or ""),
			category = package.kind == "cask" and "Casks" or "Formulae",
			severity = package.pinned and "warning" or "info",
			unread = true,
			actions = actions,
		}
	end

	if state.warning ~= nil then
		items[#items + 1] = {
			id = "warning",
			title = state.warning.source .. " warning",
			body = state.warning.message,
			severity = "warning",
			unread = true,
		}
	end

	if state.error ~= nil then
		items[#items + 1] = {
			id = "error",
			title = state.error.title,
			body = state.error.message,
			severity = "error",
			unread = true,
			actions = { { id = "refresh", title = "Refresh" } },
		}
	end

	local context_actions
	if state.active_token ~= nil then
		context_actions = { { id = "cancel", title = state.cancellation_requested and "Cancelling…" or "Cancel" } }
	else
		context_actions = {
			{ id = "refresh", title = "Refresh" },
			{ id = "update", title = "Update" },
			{ id = "upgrade_all", title = "Upgrade all" },
		}
	end
	easybar.inbox.configure(SOURCE, { actions = context_actions })
	easybar.inbox.replace(SOURCE, items)
end

local function apply_outdated(output)
	local formulae, casks, warning, decode_error = decode_outdated(output)
	if formulae == nil then
		state.error = { title = "Could not check outdated packages", message = decode_error }
		return false
	end
	state.formulae = formulae
	state.casks = casks
	state.warning = warning
	state.error = nil
	return true
end

refresh = function()
	if state.active_token ~= nil then
		return
	end
	state.operation = "Checking outdated packages…"
	state.cancellation_requested = false
	publish()
	state.active_token = easybar.exec_async(
		"HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --json=v2",
		EXEC.check,
		function(output, code)
			state.active_token = nil
			state.operation = nil
			if code ~= 0 then
				state.error = {
					title = "Could not check outdated packages",
					message = text.trim(output) ~= "" and text.truncate(output, 12000, "…")
						or "brew outdated exited with code " .. tostring(code),
				}
			else
				apply_outdated(output)
			end
			publish()
		end
	)
	publish()
end

local function run_operation(label, command, options)
	if state.active_token ~= nil then
		return
	end
	state.operation = label
	state.error = nil
	state.cancellation_requested = false
	state.active_token = easybar.exec_async(command, options, function(output, code)
		local cancelled = state.cancellation_requested
		state.active_token = nil
		state.operation = nil
		state.cancellation_requested = false
		if not cancelled and code ~= 0 then
			state.error = {
				title = label .. " failed",
				message = text.trim(output) ~= "" and text.truncate(output, 12000, "…")
					or "Command exited with code " .. tostring(code),
			}
			publish()
			return
		end
		refresh()
	end)
	publish()
end

local function package_for_id(id)
	for _, package in ipairs(all_packages()) do
		if package.id == id then
			return package
		end
	end
	return nil
end

easybar.inbox.on_action(SOURCE, function(event)
	if event.action_id == "refresh" then
		refresh()
	elseif event.action_id == "upgrade" then
		local package = package_for_id(event.target_widget_id)
		if package ~= nil and not package.pinned then
			local command = "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ASK=1 brew upgrade --"
				.. package.kind
				.. " --yes "
				.. shell.quote(package.name)
			run_operation("Upgrade " .. package.name, command, EXEC.upgrade)
		end
	end
end)

easybar.inbox.on_context_action(SOURCE, function(event)
	if event.action_id == "cancel" then
		if state.active_token ~= nil then
			state.cancellation_requested = true
			state.operation = "Cancelling Homebrew operation…"
			easybar.cancel_async(state.active_token)
			publish()
		end
	elseif event.action_id == "refresh" then
		refresh()
	elseif event.action_id == "update" then
		run_operation("Homebrew update", "brew update", EXEC.update)
	elseif event.action_id == "upgrade_all" then
		run_operation("Homebrew upgrade", "HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_NO_ASK=1 brew upgrade --yes", EXEC.upgrade)
	end
end)

local timer = easybar.add(easybar.kind.item, "brew_inbox_timer", {
	drawing = false,
	interval = POLL_INTERVAL_SECONDS,
	on_interval = refresh,
})
timer:subscribe({ easybar.events.forced, easybar.events.system_woke, easybar.events.session_active }, refresh)
refresh()
