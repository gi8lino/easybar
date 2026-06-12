-- Homebrew outdated widget for EasyBar.
--
-- Icon-only widget for the bar, with a popup that shows outdated packages and
-- actions for updating Homebrew and upgrading packages.

local WIDGET_ID = "brew_outdated"

local ID_TITLE = WIDGET_ID .. "_title"
local ID_SUMMARY = WIDGET_ID .. "_summary"
local ID_TIME = WIDGET_ID .. "_time"
local ID_ACTIONS = WIDGET_ID .. "_actions"
local ID_UPGRADE = WIDGET_ID .. "_upgrade"
local ID_UPDATE = WIDGET_ID .. "_update"

local CHECK_INTERVAL_SECONDS = 30 * 60
local MAX_POPUP_ITEMS = 30
local EXEC = {
	brew = {
		timeout_seconds = 30,
	},
}

local POPUP_ORDER = {
	title = 10,
	summary = 20,
	time = 30,
	actions = 40,
	dynamic_start = 100,
}

local ICONS = {
	checking = "󰑐",
	updating = "󰚰",
	upgrading = "󰏖",
	up_to_date = "󰄬",
	outdated = "󰚭",
	error = "󰅚",
}

local COLORS = {
	info = easybar.theme.ref.accent_secondary,
	ok = easybar.theme.ref.success,
	warn = easybar.theme.ref.warning,
	orange = easybar.theme.ref.orange,
	error = easybar.theme.ref.error,
	muted = easybar.theme.ref.muted,
	text = easybar.theme.ref.text,
	popup_bg = easybar.theme.ref.background,
	button_bg = easybar.theme.ref.surface,
	button_border = easybar.theme.ref.border_strong,
}

local THRESHOLDS = {
	[3] = COLORS.warn,
	[5] = COLORS.orange,
	[10] = COLORS.error,
}

local running = false
local dynamic_rows = {}

local brew_widget
local title_item
local summary_item
local time_item
local actions_row
local upgrade_button
local update_button

local state = {
	formulae = {},
	casks = {},
	error = nil,
	status = "Checking outdated packages…",
	last_attempted_at = nil,
	last_checked = nil,
	phase = "checking",
}

--- Logs a debug message with a widget-specific prefix.
local function log_debug(...)
	easybar.log(easybar.level.debug, "[brew_outdated]", ...)
end

--- Returns the current time as HH:MM.
local function now_label()
	return os.date("%H:%M")
end

--- Returns the current Unix timestamp.
local function now_timestamp()
	return os.time()
end

--- Returns a trimmed string value.
local function trim(value)
	return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

--- Returns whether the widget should run another Homebrew update now.
local function check_due()
	if state.last_attempted_at == nil then
		return true
	end

	return (now_timestamp() - state.last_attempted_at) >= CHECK_INTERVAL_SECONDS
end

--- Returns the next scheduled check time as HH:MM or `now` when overdue.
local function next_check_label()
	if check_due() then
		return "now"
	end

	return os.date("%H:%M", state.last_attempted_at + CHECK_INTERVAL_SECONDS)
end

--- Truncates a value to a maximum visible length.
local function truncate(value, max)
	value = tostring(value or "")

	if max <= 1 then
		return value:sub(1, max)
	end

	if #value <= max then
		return value
	end

	return value:sub(1, max - 1) .. "…"
end

--- Returns the threshold color for the outdated package count.
local function threshold_color(count)
	local threshold_keys = {}

	for key in pairs(THRESHOLDS) do
		table.insert(threshold_keys, key)
	end

	table.sort(threshold_keys, function(a, b)
		return a > b
	end)

	for _, threshold in ipairs(threshold_keys) do
		if tonumber(count) >= threshold then
			return THRESHOLDS[threshold]
		end
	end

	return COLORS.ok
end

--- Parses Homebrew JSON package entries into normalized rows.
local function parse_package_list(entries, kind)
	local packages = {}

	for _, entry in ipairs(entries or {}) do
		local installed_versions = entry.installed_versions or {}
		local installed = "?"

		if #installed_versions > 0 then
			installed = table.concat(installed_versions, ", ")
		elseif type(entry.installed_version) == "string" and entry.installed_version ~= "" then
			installed = entry.installed_version
		end

		packages[#packages + 1] = {
			kind = kind,
			name = entry.name or entry.token or entry.full_token or "unknown",
			installed = installed,
			current = entry.current_version or "?",
			pinned = entry.pinned == true,
		}
	end

	return packages
end

--- Stores parsed Homebrew outdated JSON in widget state.
local function apply_outdated_json(raw)
	local parsed = easybar.json.decode(raw)

	state.formulae = parse_package_list(parsed.formulae, "formula")
	state.casks = parse_package_list(parsed.casks, "cask")
	state.error = nil
	state.last_checked = now_label()
	state.phase = "ready"

	log_debug("apply_outdated_json", "formulae=" .. tostring(#state.formulae), "casks=" .. tostring(#state.casks))
end

--- Returns the number of outdated packages.
local function count_packages()
	return #state.formulae + #state.casks
end

--- Removes all dynamically created popup rows.
local function remove_dynamic_rows()
	for _, row in ipairs(dynamic_rows) do
		if row ~= nil then
			row:remove()
		end
	end

	dynamic_rows = {}
end

--- Adds a popup text row and tracks it for later cleanup.
local function add_popup_row(id, text, opts)
	opts = opts or {}

	local props = {
		position = "popup." .. WIDGET_ID,
		order = opts.order,
		label = {
			string = text,
			color = opts.color or COLORS.text,
			font = {
				size = opts.size or 12,
			},
		},
	}

	local row = easybar.add(easybar.kind.item, id, props)
	dynamic_rows[#dynamic_rows + 1] = row

	return row
end

--- Renders a package section in the popup.
local function render_list_section(title, packages, row_prefix, order, remaining_rows)
	if #packages == 0 or remaining_rows <= 0 then
		return order, 0
	end

	add_popup_row(row_prefix .. "_heading", title, {
		order = order,
		size = 12,
		color = COLORS.muted,
	})

	order = order + 1

	local rendered_count = 0

	for _, package in ipairs(packages) do
		if rendered_count >= remaining_rows then
			return order, rendered_count
		end

		local pin = package.pinned and "  pinned" or ""
		local text = string.format(
			"  • %s  %s → %s%s",
			truncate(package.name, 28),
			truncate(package.installed, 18),
			truncate(package.current, 18),
			pin
		)

		add_popup_row(row_prefix .. "_" .. tostring(order), text, {
			order = order,
		})

		order = order + 1
		rendered_count = rendered_count + 1
	end

	return order, rendered_count
end

--- Returns the bar icon and color for the current widget state.
local function current_bar_visual()
	local total = count_packages()

	if running then
		if state.phase == "updating" then
			return ICONS.updating, COLORS.info
		end

		if state.phase == "upgrading" then
			return ICONS.upgrading, COLORS.orange
		end

		return ICONS.checking, COLORS.warn
	end

	if state.error ~= nil or state.phase == "error" then
		return ICONS.error, COLORS.error
	end

	if total == 0 then
		return ICONS.up_to_date, COLORS.ok
	end

	return ICONS.outdated, threshold_color(total)
end

--- Returns labels for action buttons based on the current phase.
local function action_button_labels()
	if not running then
		return "Upgrade", "Update"
	end

	if state.phase == "upgrading" then
		return "Upgrading…", "Working…"
	end

	if state.phase == "updating" then
		return "Working…", "Updating…"
	end

	if state.phase == "checking" then
		return "Working…", "Checking…"
	end

	return "Working…", "Working…"
end

--- Renders the popup contents.
local function render_popup()
	local total = count_packages()
	local count_color = threshold_color(total)

	title_item:set({
		order = POPUP_ORDER.title,
		label = {
			string = "Homebrew",
			color = COLORS.text,
		},
	})

	if running then
		summary_item:set({
			order = POPUP_ORDER.summary,
			label = {
				string = state.status,
				color = COLORS.warn,
			},
		})
	elseif state.error ~= nil then
		summary_item:set({
			order = POPUP_ORDER.summary,
			label = {
				string = "Could not check outdated packages",
				color = COLORS.error,
			},
		})
	elseif total == 0 then
		summary_item:set({
			order = POPUP_ORDER.summary,
			label = {
				string = "Everything is up to date",
				color = COLORS.ok,
			},
		})
	elseif total == 1 then
		summary_item:set({
			order = POPUP_ORDER.summary,
			label = {
				string = "1 outdated package",
				color = count_color,
			},
		})
	else
		summary_item:set({
			order = POPUP_ORDER.summary,
			label = {
				string = tostring(total) .. " outdated packages",
				color = count_color,
			},
		})
	end

	local checked = state.last_checked or "never"

	time_item:set({
		order = POPUP_ORDER.time,
		label = {
			string = "Last checked: " .. checked .. "   Next check: " .. next_check_label(),
			color = COLORS.muted,
			font = {
				size = 11,
			},
		},
	})

	actions_row:set({
		order = POPUP_ORDER.actions,
	})

	local upgrade_label, update_label = action_button_labels()

	upgrade_button:set({
		order = 1,
		label = {
			string = upgrade_label,
			color = COLORS.text,
		},
	})

	update_button:set({
		order = 2,
		label = {
			string = update_label,
			color = COLORS.text,
		},
	})

	remove_dynamic_rows()

	if state.error ~= nil then
		add_popup_row(WIDGET_ID .. "_error", state.error, {
			order = POPUP_ORDER.dynamic_start,
			color = COLORS.error,
		})

		return
	end

	if running and total == 0 then
		add_popup_row(WIDGET_ID .. "_running_hint", "Waiting for Homebrew…", {
			order = POPUP_ORDER.dynamic_start,
			color = COLORS.muted,
		})

		return
	end

	if total == 0 then
		return
	end

	local available_rows = MAX_POPUP_ITEMS
	local order = POPUP_ORDER.dynamic_start
	local rendered_packages = 0

	local rendered_formulae
	order, rendered_formulae =
		render_list_section("Formulae", state.formulae, WIDGET_ID .. "_formula", order, available_rows)

	rendered_packages = rendered_packages + rendered_formulae
	available_rows = available_rows - rendered_formulae

	local rendered_casks
	order, rendered_casks = render_list_section("Casks", state.casks, WIDGET_ID .. "_cask", order, available_rows)

	rendered_packages = rendered_packages + rendered_casks

	local hidden = total - rendered_packages
	if hidden > 0 then
		add_popup_row(WIDGET_ID .. "_hidden", "  … " .. tostring(hidden) .. " more", {
			order = order,
			color = COLORS.muted,
		})
	end
end

--- Renders the bar widget as a compact icon-only item.
local function render_bar()
	local icon, color = current_bar_visual()

	log_debug(
		"render_bar",
		"running=" .. tostring(running),
		"phase=" .. tostring(state.phase),
		"error=" .. tostring(state.error ~= nil),
		"total=" .. tostring(count_packages())
	)

	brew_widget:set({
		icon = {
			string = icon,
			color = color,
		},
		label = {
			string = "",
		},
	})
end

--- Renders both the bar widget and popup.
local function render()
	render_bar()
	render_popup()
end

--- Runs a Homebrew command asynchronously and updates widget state.
local function run_brew_async(status_label, phase, command, on_success)
	if running then
		log_debug("run_brew_async skipped", "status=" .. tostring(status_label))
		return
	end

	running = true
	state.status = status_label
	state.error = nil
	state.last_attempted_at = now_timestamp()
	state.phase = phase or "checking"

	log_debug(
		"run_brew_async start",
		"status=" .. tostring(status_label),
		"phase=" .. tostring(state.phase),
		"command=" .. tostring(command)
	)

	render()

	local token = easybar.exec_async(command, EXEC.brew, function(output, code)
		running = false

		log_debug(
			"run_brew_async complete",
			"status=" .. tostring(status_label),
			"phase=" .. tostring(state.phase),
			"code=" .. tostring(code)
		)

		if code ~= 0 then
			local message = truncate(trim(output), 400)

			if message == "" then
				message = "brew command failed with exit code " .. tostring(code)
			end

			state.error = message
			state.phase = "error"

			log_debug("run_brew_async error", message)
			render()

			return
		end

		local ok, err = pcall(on_success, output)

		if not ok then
			state.error = "Could not parse brew output: " .. tostring(err)
			state.phase = "error"

			log_debug("run_brew_async parse_error", tostring(err))
		end

		render()
	end)

	log_debug("run_brew_async token", tostring(token))
end

--- Checks outdated packages without updating Homebrew.
local function check_outdated(status_label)
	run_brew_async(
		status_label or "Checking outdated packages…",
		"checking",
		"HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --json=v2",
		apply_outdated_json
	)
end

--- Updates Homebrew, then checks outdated packages.
local function update_now()
	local command = [[
tmp="${TMPDIR:-/tmp}/easybar-brew-update.$$"

brew update >"$tmp" 2>&1
update_rc=$?

if [ "$update_rc" -ne 0 ]; then
  tail -n 40 "$tmp"
  rm -f "$tmp"
  exit "$update_rc"
fi

rm -f "$tmp"
HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --json=v2
]]

	run_brew_async("Updating Homebrew…", "updating", command, apply_outdated_json)
end

--- Updates Homebrew only when the widget is due.
local function update_if_due()
	if running or not check_due() then
		return
	end

	update_now()
end

--- Upgrades packages, then checks outdated packages.
local function upgrade_now()
	local command = [[
tmp="${TMPDIR:-/tmp}/easybar-brew-upgrade.$$"

HOMEBREW_NO_ASK=1 brew upgrade --yes >"$tmp" 2>&1
upgrade_rc=$?

if [ "$upgrade_rc" -ne 0 ]; then
  tail -n 40 "$tmp"
  rm -f "$tmp"
  exit "$upgrade_rc"
fi

rm -f "$tmp"
HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --json=v2
]]

	run_brew_async("Upgrading packages…", "upgrading", command, apply_outdated_json)
end

--- Returns a fresh button background configuration.
local function button_background()
	return {
		color = COLORS.button_bg,
		border_color = COLORS.button_border,
		border_width = 1,
		corner_radius = 6,
		padding_left = 8,
		padding_right = 8,
	}
end

easybar.default({
	label = {
		color = COLORS.text,
		font = {
			size = 12,
		},
	},
})

brew_widget = easybar.add(easybar.kind.item, WIDGET_ID, {
	position = "right",
	order = 20,
	interval = CHECK_INTERVAL_SECONDS,
	popup = {
		drawing = true,
		background = {
			color = COLORS.popup_bg,
			border_color = COLORS.button_border,
			border_width = 1,
			corner_radius = 8,
		},
		padding_x = 10,
		padding_y = 8,
		spacing = 6,
	},
	height = 24,
	icon = {
		string = ICONS.checking,
		color = COLORS.warn,
		font = {
			size = 15,
		},
		offset_x = -1,
		offset_y = 0,
	},
	label = {
		string = "",
	},
	on_interval = function()
		if not running then
			update_now()
		end
	end,
})

title_item = easybar.add(easybar.kind.item, ID_TITLE, {
	position = "popup." .. brew_widget.name,
	order = POPUP_ORDER.title,
	label = {
		string = "Homebrew",
		color = COLORS.text,
		font = {
			size = 13,
		},
	},
})

summary_item = easybar.add(easybar.kind.item, ID_SUMMARY, {
	position = "popup." .. brew_widget.name,
	order = POPUP_ORDER.summary,
	label = {
		string = "Checking outdated packages…",
		color = COLORS.text,
	},
})

time_item = easybar.add(easybar.kind.item, ID_TIME, {
	position = "popup." .. brew_widget.name,
	order = POPUP_ORDER.time,
	label = {
		string = "Last checked: never",
		color = COLORS.muted,
		font = {
			size = 11,
		},
	},
})

actions_row = easybar.add(easybar.kind.row, ID_ACTIONS, {
	position = "popup." .. brew_widget.name,
	order = POPUP_ORDER.actions,
	spacing = 8,
})

upgrade_button = easybar.add(easybar.kind.item, ID_UPGRADE, {
	parent = actions_row.name,
	order = 1,
	label = {
		string = "Upgrade now",
		color = COLORS.text,
	},
	background = button_background(),
})

update_button = easybar.add(easybar.kind.item, ID_UPDATE, {
	parent = actions_row.name,
	order = 2,
	label = {
		string = "Update",
		color = COLORS.text,
	},
	background = button_background(),
})

brew_widget:subscribe(easybar.events.mouse.entered, function()
	log_debug("mouse entered", "running=" .. tostring(running))
end)

brew_widget:subscribe(easybar.events.mouse.exited, function()
	log_debug("mouse exited", "running=" .. tostring(running))
end)

update_button:subscribe(easybar.events.mouse.clicked, function(event)
	if (event.button == nil or event.button == "left") and not running then
		log_debug("update click")
		update_now()
	end
end)

upgrade_button:subscribe(easybar.events.mouse.clicked, function(event)
	if (event.button == nil or event.button == "left") and not running then
		log_debug("upgrade click")
		upgrade_now()
	end
end)

brew_widget:subscribe({
	easybar.events.system_woke,
	easybar.events.session_active,
}, function(event)
	log_debug("lifecycle event", tostring(event and event.name), "due=" .. tostring(check_due()))
	update_if_due()
end)

brew_widget:subscribe(easybar.events.forced, function()
	if not running then
		check_outdated("Checking outdated packages…")
	end
end)

update_now()
