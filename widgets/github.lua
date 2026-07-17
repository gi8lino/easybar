local shell = require("shell")
local text = require("text")

local POLL_INTERVAL_SECONDS = 300
local MAX_POPUP_ITEMS = 6
local HOVER_CLOSE_DELAY_SECONDS = 0.20
local NOTIFICATIONS_URL = "https://github.com/notifications"

local GITHUB_ICON_PATH = easybar.asset("assets/github-mark.svg")

local COLORS = {
	text = easybar.theme.ref.text,
	muted = easybar.theme.ref.muted,
	accent = easybar.theme.ref.accent,
	danger = easybar.theme.ref.danger,
	background = easybar.theme.ref.background,
	border = easybar.theme.ref.border_strong,
	surface = easybar.theme.ref.surface,
	surface_hover = easybar.theme.ref.surface_hover,
}

local state = {
	notifications = {},
	error = nil,
	loading = false,
	popup_open = false,
	trigger_hovered = false,
	popup_hovered = false,
	hover_revision = 0,
	hover_close_job = nil,
	active_job = nil,
}

local github
local popup_header
local popup_rows = {}
local popup_footer

local function notification_text(notification)
	local repository = "GitHub"
	if type(notification.repository) == "table" then
		repository = text.trim(notification.repository.full_name)
		if repository == "" then
			repository = "GitHub"
		end
	end

	local title = "Untitled notification"
	local reason = nil
	if type(notification.subject) == "table" then
		local candidate = text.trim(notification.subject.title)
		if candidate ~= "" then
			title = candidate
		end
	end

	if type(notification.reason) == "string" then
		reason = text.trim(notification.reason)
	end

	local summary = repository .. "  ·  " .. title
	if reason ~= nil and reason ~= "" then
		summary = summary .. "  [" .. reason .. "]"
	end

	return text.truncate(summary, 96)
end

local function decode_notifications(output)
	local ok, pages = pcall(easybar.json.decode, output)
	if not ok then
		return nil, "GitHub returned invalid JSON"
	end

	if type(pages) ~= "table" then
		return nil, "GitHub returned an unexpected response"
	end

	local notifications = {}
	for _, page in ipairs(pages) do
		if type(page) == "table" then
			for _, notification in ipairs(page) do
				if type(notification) == "table" and notification.unread ~= false then
					table.insert(notifications, notification)
				end
			end
		end
	end

	return notifications, nil
end

local function should_draw()
	return state.error ~= nil or #state.notifications > 0
end

local function render_popup()
	local count = #state.notifications

	if state.error ~= nil then
		popup_header:set({
			drawing = true,
			label = {
				string = "GitHub notifications unavailable",
				color = COLORS.danger,
			},
		})

		popup_rows[1]:set({
			drawing = true,
			label = {
				string = text.truncate(state.error, 96),
				color = COLORS.text,
			},
		})

		for index = 2, MAX_POPUP_ITEMS do
			popup_rows[index]:set({ drawing = false })
		end
	elseif count == 0 then
		popup_header:set({ drawing = false })
		for _, row in ipairs(popup_rows) do
			row:set({ drawing = false })
		end
	else
		popup_header:set({
			drawing = true,
			label = {
				string = count == 1 and "1 unread GitHub notification" or tostring(count) .. " unread GitHub notifications",
				color = COLORS.accent,
			},
		})

		for index, row in ipairs(popup_rows) do
			local notification = state.notifications[index]
			if notification ~= nil then
				row:set({
					drawing = true,
					label = {
						string = notification_text(notification),
						color = COLORS.text,
					},
				})
			else
				row:set({ drawing = false })
			end
		end
	end

	popup_footer:set({
		drawing = should_draw(),
		label = {
			string = "Left-click to open · Right-click to refresh",
			color = COLORS.muted,
		},
	})
end

local function popup_props(drawing)
	return {
		drawing = drawing,
		padding_x = 10,
		padding_y = 8,
		margin_y = 8,
		spacing = 5,
		background = {
			color = COLORS.background,
			border_color = COLORS.border,
			border_width = 1,
			corner_radius = 10,
		},
	}
end

local function render()
	local count = #state.notifications
	local visible = should_draw()
	local color = state.error ~= nil and COLORS.danger or COLORS.accent

	if not visible then
		state.popup_open = false
		state.trigger_hovered = false
		state.popup_hovered = false
	end

	github:set({
		drawing = visible,
		icon = {
			image = {
				path = GITHUB_ICON_PATH,
				size = 15,
				corner_radius = 0,
			},
			color = color,
		},
		label = {
			string = state.error ~= nil and "!" or tostring(count),
			color = color,
		},
		background = {
			color = (state.trigger_hovered or state.popup_hovered) and COLORS.surface_hover or easybar.theme.ref.transparent,
			border_color = easybar.theme.ref.transparent,
			border_width = 0,
			corner_radius = 8,
		},
		popup = popup_props(visible and state.popup_open),
	})

	render_popup()
end

local function refresh()
	if state.loading then
		return
	end

	state.loading = true

	local command = table.concat({
		"gh api",
		"--paginate",
		"--slurp",
		"-H",
		shell.quote("Accept: application/vnd.github+json"),
		shell.quote("notifications?all=false&per_page=100"),
	}, " ")

	state.active_job = easybar.exec_async(command, {
		timeout_seconds = 20,
		max_output_bytes = 1048576,
	}, function(output, code)
		state.active_job = nil
		state.loading = false

		if code ~= 0 then
			local message = text.trim(output)
			if message == "" then
				message = "Run 'gh auth login' and verify that gh is available in app.env PATH"
			end

			state.error = message
			state.notifications = {}
			render()
			return
		end

		local notifications, decode_error = decode_notifications(output)
		if notifications == nil then
			state.error = decode_error
			state.notifications = {}
		else
			state.error = nil
			state.notifications = notifications
		end

		render()
	end)
end

github = easybar.add(easybar.kind.item, "github_notifications", {
	position = "right",
	order = 0,
	drawing = false,
	interval = POLL_INTERVAL_SECONDS,
	on_interval = refresh,
	icon = {
		image = {
			path = GITHUB_ICON_PATH,
			size = 15,
			corner_radius = 0,
		},
		color = COLORS.muted,
	},
	label = {
		string = "",
		color = COLORS.muted,
	},
	background = {
		color = easybar.theme.ref.transparent,
		border_color = easybar.theme.ref.transparent,
		border_width = 0,
		corner_radius = 8,
	},
	padding_x = 7,
	padding_y = 3,
	popup = popup_props(false),
})

popup_header = easybar.add(easybar.kind.item, "github_notifications_header", {
	position = "popup." .. github.name,
	order = 0,
	drawing = false,
	label = {
		string = "GitHub notifications",
		color = COLORS.accent,
	},
	padding_x = 8,
	padding_y = 5,
})

for index = 1, MAX_POPUP_ITEMS do
	popup_rows[index] = easybar.add(easybar.kind.item, "github_notification_" .. tostring(index), {
		position = "popup." .. github.name,
		order = index,
		drawing = false,
		label = {
			string = "",
			color = COLORS.text,
		},
		background = {
			color = COLORS.surface,
			border_color = easybar.theme.ref.transparent,
			border_width = 0,
			corner_radius = 6,
		},
		padding_x = 8,
		padding_y = 5,
	})
end

popup_footer = easybar.add(easybar.kind.item, "github_notifications_footer", {
	position = "popup." .. github.name,
	order = MAX_POPUP_ITEMS + 1,
	drawing = false,
	label = {
		string = "Left-click to open · Right-click to refresh",
		color = COLORS.muted,
	},
	padding_x = 8,
	padding_y = 5,
})

local function cancel_hover_close()
	if state.hover_close_job == nil then
		return
	end

	easybar.cancel_async(state.hover_close_job)
	state.hover_close_job = nil
end

local function open_popup(source)
	cancel_hover_close()
	state.hover_revision = state.hover_revision + 1
	if source == "trigger" then
		state.trigger_hovered = true
	else
		state.popup_hovered = true
	end

	state.popup_open = true
	render()
end

local function schedule_popup_close(source)
	state.hover_revision = state.hover_revision + 1
	if source == "trigger" then
		state.trigger_hovered = false
	else
		state.popup_hovered = false
	end

	cancel_hover_close()
	local revision = state.hover_revision
	local command = "sleep " .. tostring(HOVER_CLOSE_DELAY_SECONDS)
	state.hover_close_job = easybar.exec_async(command, {
		timeout_seconds = 1,
		max_output_bytes = 256,
	}, function()
		state.hover_close_job = nil
		if revision ~= state.hover_revision then
			return
		end

		if state.trigger_hovered or state.popup_hovered then
			return
		end

		state.popup_open = false
		render()
	end)
end

local function attach_popup_hover(node)
	node:subscribe(easybar.events.mouse.entered, function()
		open_popup("popup")
	end)

	node:subscribe(easybar.events.mouse.exited, function()
		schedule_popup_close("popup")
	end)
end

github:subscribe(easybar.events.mouse.entered, function()
	open_popup("trigger")
end)

github:subscribe(easybar.events.mouse.exited, function()
	schedule_popup_close("trigger")
end)

attach_popup_hover(popup_header)
for _, row in ipairs(popup_rows) do
	attach_popup_hover(row)
end
attach_popup_hover(popup_footer)

github:subscribe(easybar.events.mouse.clicked, function(event)
	if event.button == easybar.events.mouse.right_button then
		refresh()
		return
	end

	if event.button ~= nil and event.button ~= easybar.events.mouse.left_button then
		return
	end

	easybar.exec_async("open " .. shell.quote(NOTIFICATIONS_URL), {
		timeout_seconds = 5,
		max_output_bytes = 4096,
	}, function(_, code)
		if code ~= 0 then
			easybar.log(easybar.level.warn, "failed to open GitHub notifications")
		end
	end)
end)

github:subscribe({
	easybar.events.forced,
	easybar.events.system_woke,
}, function()
	refresh()
end)

render()
refresh()
