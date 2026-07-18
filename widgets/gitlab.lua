-- GitLab work-items widget. Requires an authenticated `glab` CLI.
-- GitLab work-items widget. Requires an authenticated `glab` CLI.
-- Set GITLAB_HOST in app.env for a self-managed or dedicated instance.

local shell = require("shell")
local text = require("text")

local POLL_INTERVAL_SECONDS = 300
local MAX_POPUP_ITEMS = 8
local HOVER_CLOSE_DELAY_SECONDS = 0.20

local configured_host = text.trim(os.getenv("GITLAB_HOST"))
if configured_host == "" then
	configured_host = "https://gitlab.com"
elseif not configured_host:match("^https?://") then
	configured_host = "https://" .. configured_host
end
local GITLAB_URL = configured_host:gsub("/+$", "")

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
	items = {},
	error = nil,
	loading = false,
	popup_open = false,
	trigger_hovered = false,
	popup_hovered = false,
	hover_revision = 0,
	hover_close_job = nil,
}

local gitlab
local popup_header
local popup_rows = {}
local popup_footer

local function open_url(url)
	url = text.trim(url)
	if url == "" then
		return
	end

	easybar.exec_async("open " .. shell.quote(url), {
		timeout_seconds = 5,
		max_output_bytes = 4096,
	}, function(_, code)
		if code ~= 0 then
			easybar.log(easybar.level.warn, "failed to open GitLab URL", url)
		end
	end)
end

local function item_reference(item)
	if type(item.references) == "table" then
		local reference = text.trim(item.references.full)
		if reference ~= "" then
			return reference
		end
	end

	return item.kind == "merge_request" and "Merge request" or "Issue"
end

local function item_text(item)
	local title = text.trim(item.title)
	if title == "" then
		title = "Untitled"
	end

	return text.truncate(item_reference(item) .. "  ·  " .. title, 100)
end

local function append_items(target, source, kind)
	if type(source) ~= "table" then
		return false
	end

	for _, item in ipairs(source) do
		if type(item) == "table" then
			item.kind = kind
			table.insert(target, item)
		end
	end

	return true
end

local function decode_items(output)
	local ok, response = pcall(easybar.json.decode, output)
	if not ok or type(response) ~= "table" then
		return nil, "GitLab returned invalid JSON"
	end

	local items = {}
	if
		not append_items(items, response.issues, "issue")
		or not append_items(items, response.merge_requests, "merge_request")
	then
		return nil, "GitLab returned an unexpected response"
	end

	table.sort(items, function(left, right)
		return text.trim(left.updated_at) > text.trim(right.updated_at)
	end)

	return items, nil
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

local function render_popup()
	local count = #state.items

	if state.error ~= nil then
		popup_header:set({
			drawing = true,
			label = { string = "GitLab work items unavailable", color = COLORS.danger },
		})
		popup_rows[1]:set({
			drawing = true,
			label = { string = text.truncate(state.error, 100), color = COLORS.text },
		})
		for index = 2, MAX_POPUP_ITEMS do
			popup_rows[index]:set({ drawing = false })
		end
	else
		popup_header:set({
			drawing = true,
			label = {
				string = count == 1 and "1 assigned GitLab work item" or tostring(count) .. " assigned GitLab work items",
				color = count == 0 and COLORS.muted or COLORS.accent,
			},
		})

		for index, row in ipairs(popup_rows) do
			local item = state.items[index]
			if item == nil then
				row:set({ drawing = false })
			else
				row:set({
					drawing = true,
					label = { string = item_text(item), color = COLORS.text },
				})
			end
		end
	end

	popup_footer:set({
		drawing = true,
		label = {
			string = state.loading and "Refreshing..." or "Click an item to open it · Right-click to refresh",
			color = COLORS.muted,
		},
	})
end

local function render()
	local color = state.error ~= nil and COLORS.danger or (#state.items > 0 and COLORS.accent or COLORS.muted)

	gitlab:set({
		icon = {
			string = "󰮠",
			color = color,
		},
		label = {
			string = state.error ~= nil and "!" or tostring(#state.items),
			color = color,
		},
		background = {
			color = (state.trigger_hovered or state.popup_hovered) and COLORS.surface_hover or easybar.theme.ref.transparent,
			border_color = easybar.theme.ref.transparent,
			border_width = 0,
			corner_radius = 8,
		},
		popup = popup_props(state.popup_open),
	})

	render_popup()
end

local function refresh()
	if state.loading then
		return
	end

	state.loading = true
	render()

	local issues_endpoint = "issues?scope=assigned_to_me&state=opened&order_by=updated_at&sort=desc&per_page=100"
	local merge_requests_endpoint =
		"merge_requests?scope=assigned_to_me&state=opened&order_by=updated_at&sort=desc&per_page=100"
	local command = table.concat({
		"set -e",
		"issues=$(GLAB_NO_PROMPT=1 glab api --paginate " .. shell.quote(issues_endpoint) .. ")",
		"merge_requests=$(GLAB_NO_PROMPT=1 glab api --paginate " .. shell.quote(merge_requests_endpoint) .. ")",
		[[printf '{"issues":%s,"merge_requests":%s}\n' "$issues" "$merge_requests"]],
	}, "; ")

	easybar.exec_async(command, {
		timeout_seconds = 30,
		max_output_bytes = 2097152,
	}, function(output, code)
		state.loading = false

		if code ~= 0 then
			local message = text.trim(output)
			if message == "" then
				message = "Run 'glab auth login' and verify GITLAB_HOST and app.env PATH"
			end
			state.error = message
			state.items = {}
			render()
			return
		end

		local items, decode_error = decode_items(output)
		if items == nil then
			state.error = decode_error
			state.items = {}
		else
			state.error = nil
			state.items = items
		end
		render()
	end)
end

gitlab = easybar.add(easybar.kind.item, "gitlab_work_items", {
	position = "right",
	order = 0,
	interval = POLL_INTERVAL_SECONDS,
	on_interval = refresh,
	icon = { string = "GL", color = COLORS.muted },
	label = { string = "0", color = COLORS.muted },
	background = {
		color = easybar.theme.ref.transparent,
		border_color = easybar.theme.ref.transparent,
		border_width = 0,
		corner_radius = 8,
	},
	padding_x = 7,
	padding_y = 3,
	popup = popup_props(false),
	context_menu = {
		{ id = "refresh", title = "Refresh" },
		{ id = "open", title = "Open GitLab" },
	},
})

popup_header = easybar.add(easybar.kind.item, "gitlab_work_items_header", {
	position = "popup." .. gitlab.name,
	order = 0,
	drawing = true,
	label = { string = "GitLab work items", color = COLORS.accent },
	padding_x = 8,
	padding_y = 5,
})

for index = 1, MAX_POPUP_ITEMS do
	popup_rows[index] = easybar.add(easybar.kind.item, "gitlab_work_item_" .. tostring(index), {
		position = "popup." .. gitlab.name,
		order = index,
		drawing = false,
		label = { string = "", color = COLORS.text },
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

popup_footer = easybar.add(easybar.kind.item, "gitlab_work_items_footer", {
	position = "popup." .. gitlab.name,
	order = MAX_POPUP_ITEMS + 1,
	drawing = true,
	label = { string = "Click an item to open it · Right-click to refresh", color = COLORS.muted },
	padding_x = 8,
	padding_y = 5,
})

local function cancel_hover_close()
	if state.hover_close_job ~= nil then
		easybar.cancel_async(state.hover_close_job)
		state.hover_close_job = nil
	end
end

local function open_popup(source)
	cancel_hover_close()
	state.hover_revision = state.hover_revision + 1
	state.trigger_hovered = source == "trigger" or state.trigger_hovered
	state.popup_hovered = source == "popup" or state.popup_hovered
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
	local job_token
	job_token = easybar.exec_async("sleep " .. tostring(HOVER_CLOSE_DELAY_SECONDS), {
		timeout_seconds = 1,
		max_output_bytes = 256,
	}, function()
		if state.hover_close_job == job_token then
			state.hover_close_job = nil
		end
		if revision == state.hover_revision and not state.trigger_hovered and not state.popup_hovered then
			state.popup_open = false
			render()
		end
	end)
	state.hover_close_job = job_token
end

local function attach_popup_hover(node)
	node:subscribe(easybar.events.mouse.entered, function()
		open_popup("popup")
	end)
	node:subscribe(easybar.events.mouse.exited, function()
		schedule_popup_close("popup")
	end)
end

gitlab:subscribe(easybar.events.mouse.entered, function()
	open_popup("trigger")
end)
gitlab:subscribe(easybar.events.mouse.exited, function()
	schedule_popup_close("trigger")
end)

attach_popup_hover(popup_header)
attach_popup_hover(popup_footer)
for index, row in ipairs(popup_rows) do
	local row_index = index
	attach_popup_hover(row)
	row:subscribe(easybar.events.mouse.clicked, function(event)
		if event.button ~= nil and event.button ~= easybar.events.mouse.left_button then
			return
		end
		local item = state.items[row_index]
		if item ~= nil then
			open_url(item.web_url)
		end
	end)
end

gitlab:subscribe(easybar.events.mouse.clicked, function(event)
	if event.button == nil or event.button == easybar.events.mouse.left_button then
		open_url(GITLAB_URL .. "/dashboard/issues")
	end
end)

gitlab:subscribe(easybar.events.context_menu.clicked, function(event)
	if event.action_id == "refresh" then
		refresh()
	elseif event.action_id == "open" then
		open_url(GITLAB_URL)
	end
end)

gitlab:subscribe({ easybar.events.forced, easybar.events.system_woke }, function()
	refresh()
end)

render()
refresh()
-- Set GITLAB_HOST in app.env for a self-managed or dedicated instance.

local shell = require("shell")
local text = require("text")

local POLL_INTERVAL_SECONDS = 300
local MAX_POPUP_ITEMS = 8
local HOVER_CLOSE_DELAY_SECONDS = 0.20

local configured_host = text.trim(os.getenv("GITLAB_HOST"))
if configured_host == "" then
	configured_host = "https://gitlab.com"
elseif not configured_host:match("^https?://") then
	configured_host = "https://" .. configured_host
end
local GITLAB_URL = configured_host:gsub("/+$", "")

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
	items = {},
	error = nil,
	loading = false,
	popup_open = false,
	trigger_hovered = false,
	popup_hovered = false,
	hover_revision = 0,
	hover_close_job = nil,
}

local gitlab
local popup_header
local popup_rows = {}
local popup_footer

local function open_url(url)
	url = text.trim(url)
	if url == "" then
		return
	end

	easybar.exec_async("open " .. shell.quote(url), {
		timeout_seconds = 5,
		max_output_bytes = 4096,
	}, function(_, code)
		if code ~= 0 then
			easybar.log(easybar.level.warn, "failed to open GitLab URL", url)
		end
	end)
end

local function item_reference(item)
	if type(item.references) == "table" then
		local reference = text.trim(item.references.full)
		if reference ~= "" then
			return reference
		end
	end

	return item.kind == "merge_request" and "Merge request" or "Issue"
end

local function item_text(item)
	local title = text.trim(item.title)
	if title == "" then
		title = "Untitled"
	end

	return text.truncate(item_reference(item) .. "  ·  " .. title, 100)
end

local function append_items(target, source, kind)
	if type(source) ~= "table" then
		return false
	end

	for _, item in ipairs(source) do
		if type(item) == "table" then
			item.kind = kind
			table.insert(target, item)
		end
	end

	return true
end

local function decode_items(output)
	local ok, response = pcall(easybar.json.decode, output)
	if not ok or type(response) ~= "table" then
		return nil, "GitLab returned invalid JSON"
	end

	local items = {}
	if
		not append_items(items, response.issues, "issue")
		or not append_items(items, response.merge_requests, "merge_request")
	then
		return nil, "GitLab returned an unexpected response"
	end

	table.sort(items, function(left, right)
		return text.trim(left.updated_at) > text.trim(right.updated_at)
	end)

	return items, nil
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

local function render_popup()
	local count = #state.items

	if state.error ~= nil then
		popup_header:set({
			drawing = true,
			label = { string = "GitLab work items unavailable", color = COLORS.danger },
		})
		popup_rows[1]:set({
			drawing = true,
			label = { string = text.truncate(state.error, 100), color = COLORS.text },
		})
		for index = 2, MAX_POPUP_ITEMS do
			popup_rows[index]:set({ drawing = false })
		end
	else
		popup_header:set({
			drawing = true,
			label = {
				string = count == 1 and "1 assigned GitLab work item" or tostring(count) .. " assigned GitLab work items",
				color = count == 0 and COLORS.muted or COLORS.accent,
			},
		})

		for index, row in ipairs(popup_rows) do
			local item = state.items[index]
			if item == nil then
				row:set({ drawing = false })
			else
				row:set({
					drawing = true,
					label = { string = item_text(item), color = COLORS.text },
				})
			end
		end
	end

	popup_footer:set({
		drawing = true,
		label = {
			string = state.loading and "Refreshing..." or "Click an item to open it · Right-click to refresh",
			color = COLORS.muted,
		},
	})
end

local function render()
	local color = state.error ~= nil and COLORS.danger or (#state.items > 0 and COLORS.accent or COLORS.muted)

	gitlab:set({
		icon = { string = "GL", color = color },
		label = {
			string = state.error ~= nil and "!" or tostring(#state.items),
			color = color,
		},
		background = {
			color = (state.trigger_hovered or state.popup_hovered) and COLORS.surface_hover or easybar.theme.ref.transparent,
			border_color = easybar.theme.ref.transparent,
			border_width = 0,
			corner_radius = 8,
		},
		popup = popup_props(state.popup_open),
	})

	render_popup()
end

local function refresh()
	if state.loading then
		return
	end

	state.loading = true
	render()

	local issues_endpoint = "issues?scope=assigned_to_me&state=opened&order_by=updated_at&sort=desc&per_page=100"
	local merge_requests_endpoint =
		"merge_requests?scope=assigned_to_me&state=opened&order_by=updated_at&sort=desc&per_page=100"
	local command = table.concat({
		"set -e",
		"issues=$(GLAB_NO_PROMPT=1 glab api --paginate " .. shell.quote(issues_endpoint) .. ")",
		"merge_requests=$(GLAB_NO_PROMPT=1 glab api --paginate " .. shell.quote(merge_requests_endpoint) .. ")",
		[[printf '{"issues":%s,"merge_requests":%s}\n' "$issues" "$merge_requests"]],
	}, "; ")

	easybar.exec_async(command, {
		timeout_seconds = 30,
		max_output_bytes = 2097152,
	}, function(output, code)
		state.loading = false

		if code ~= 0 then
			local message = text.trim(output)
			if message == "" then
				message = "Run 'glab auth login' and verify GITLAB_HOST and app.env PATH"
			end
			state.error = message
			state.items = {}
			render()
			return
		end

		local items, decode_error = decode_items(output)
		if items == nil then
			state.error = decode_error
			state.items = {}
		else
			state.error = nil
			state.items = items
		end
		render()
	end)
end

gitlab = easybar.add(easybar.kind.item, "gitlab_work_items", {
	position = "right",
	order = 0,
	interval = POLL_INTERVAL_SECONDS,
	on_interval = refresh,
	icon = { string = "GL", color = COLORS.muted },
	label = { string = "0", color = COLORS.muted },
	background = {
		color = easybar.theme.ref.transparent,
		border_color = easybar.theme.ref.transparent,
		border_width = 0,
		corner_radius = 8,
	},
	padding_x = 7,
	padding_y = 3,
	popup = popup_props(false),
	context_menu = {
		{ id = "refresh", title = "Refresh" },
		{ id = "open", title = "Open GitLab" },
	},
})

popup_header = easybar.add(easybar.kind.item, "gitlab_work_items_header", {
	position = "popup." .. gitlab.name,
	order = 0,
	drawing = true,
	label = { string = "GitLab work items", color = COLORS.accent },
	padding_x = 8,
	padding_y = 5,
})

for index = 1, MAX_POPUP_ITEMS do
	popup_rows[index] = easybar.add(easybar.kind.item, "gitlab_work_item_" .. tostring(index), {
		position = "popup." .. gitlab.name,
		order = index,
		drawing = false,
		label = { string = "", color = COLORS.text },
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

popup_footer = easybar.add(easybar.kind.item, "gitlab_work_items_footer", {
	position = "popup." .. gitlab.name,
	order = MAX_POPUP_ITEMS + 1,
	drawing = true,
	label = { string = "Click an item to open it · Right-click to refresh", color = COLORS.muted },
	padding_x = 8,
	padding_y = 5,
})

local function cancel_hover_close()
	if state.hover_close_job ~= nil then
		easybar.cancel_async(state.hover_close_job)
		state.hover_close_job = nil
	end
end

local function open_popup(source)
	cancel_hover_close()
	state.hover_revision = state.hover_revision + 1
	state.trigger_hovered = source == "trigger" or state.trigger_hovered
	state.popup_hovered = source == "popup" or state.popup_hovered
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
	local job_token
	job_token = easybar.exec_async("sleep " .. tostring(HOVER_CLOSE_DELAY_SECONDS), {
		timeout_seconds = 1,
		max_output_bytes = 256,
	}, function()
		if state.hover_close_job == job_token then
			state.hover_close_job = nil
		end
		if revision == state.hover_revision and not state.trigger_hovered and not state.popup_hovered then
			state.popup_open = false
			render()
		end
	end)
	state.hover_close_job = job_token
end

local function attach_popup_hover(node)
	node:subscribe(easybar.events.mouse.entered, function()
		open_popup("popup")
	end)
	node:subscribe(easybar.events.mouse.exited, function()
		schedule_popup_close("popup")
	end)
end

gitlab:subscribe(easybar.events.mouse.entered, function()
	open_popup("trigger")
end)
gitlab:subscribe(easybar.events.mouse.exited, function()
	schedule_popup_close("trigger")
end)

attach_popup_hover(popup_header)
attach_popup_hover(popup_footer)
for index, row in ipairs(popup_rows) do
	local row_index = index
	attach_popup_hover(row)
	row:subscribe(easybar.events.mouse.clicked, function(event)
		if event.button ~= nil and event.button ~= easybar.events.mouse.left_button then
			return
		end
		local item = state.items[row_index]
		if item ~= nil then
			open_url(item.web_url)
		end
	end)
end

gitlab:subscribe(easybar.events.mouse.clicked, function(event)
	if event.button == nil or event.button == easybar.events.mouse.left_button then
		open_url(GITLAB_URL .. "/dashboard/issues")
	end
end)

gitlab:subscribe(easybar.events.context_menu.clicked, function(event)
	if event.action_id == "refresh" then
		refresh()
	elseif event.action_id == "open" then
		open_url(GITLAB_URL)
	end
end)

gitlab:subscribe({ easybar.events.forced, easybar.events.system_woke }, function()
	refresh()
end)

render()
refresh()
