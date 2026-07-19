-- Inbox-only GitHub notifications. Requires an authenticated `gh` CLI.

local shell = require("shell")
local text = require("text")

local SOURCE = "GitHub"
local POLL_INTERVAL_SECONDS = 300
local notifications = {}
local refreshing = false

easybar.inbox.configure(SOURCE, {
	actions = { { id = "refresh", title = "Refresh" } },
})

local function notification_url(notification)
	local repository = type(notification.repository) == "table" and text.trim(notification.repository.html_url) or ""
	local subject = type(notification.subject) == "table" and notification.subject or {}
	local api_url = text.trim(subject.url)
	local number = api_url:match("/(%d+)$")
	if repository ~= "" and number ~= nil then
		if subject.type == "PullRequest" then
			return repository .. "/pull/" .. number
		elseif subject.type == "Issue" then
			return repository .. "/issues/" .. number
		elseif subject.type == "Discussion" then
			return repository .. "/discussions/" .. number
		end
	end
	return "https://github.com/notifications"
end

local function publish_error(message)
	easybar.inbox.replace(SOURCE, {
		{
			id = "error",
			title = "GitHub notifications unavailable",
			body = message,
			severity = "error",
			actions = { { id = "refresh", title = "Refresh" } },
		},
	})
end

local function refresh()
	if refreshing then
		return
	end
	refreshing = true
	local command = table.concat({
		"gh api --paginate --slurp -H",
		shell.quote("Accept: application/vnd.github+json"),
		shell.quote("notifications?all=false&per_page=100"),
	}, " ")
	easybar.exec_async(command, { timeout_seconds = 20, max_output_bytes = 1048576 }, function(output, code)
		refreshing = false
		if code ~= 0 then
			publish_error(text.trim(output) ~= "" and text.trim(output) or "Run 'gh auth login' and check app.env PATH")
			return
		end
		local ok, pages = pcall(easybar.json.decode, output)
		if not ok or type(pages) ~= "table" then
			publish_error("GitHub returned invalid JSON")
			return
		end
		notifications = {}
		for _, page in ipairs(pages) do
			for _, notification in ipairs(type(page) == "table" and page or {}) do
				notifications[#notifications + 1] = notification
			end
		end
		local items = {}
		for _, notification in ipairs(notifications) do
			local repository = type(notification.repository) == "table" and notification.repository.full_name or "GitHub"
			local subject = type(notification.subject) == "table" and notification.subject or {}
			items[#items + 1] = {
				id = tostring(notification.id or repository .. ":" .. tostring(subject.title)),
				title = text.trim(subject.title) ~= "" and subject.title or "Untitled notification",
				body = repository .. (text.trim(notification.reason) ~= "" and " · " .. notification.reason or ""),
				category = text.trim(subject.type) ~= "" and subject.type or "Notification",
				severity = "info",
				unread = true,
				actions = {
					{ id = "mark_read", title = "Mark as read" },
					{ id = "open", title = "Open" },
				},
			}
		end
		easybar.inbox.replace(SOURCE, items)
	end)
end

easybar.inbox.on_action(SOURCE, function(event)
	if event.action_id == "refresh" then
		refresh()
	elseif event.action_id == "mark_read" then
		local thread_id = tostring(event.target_widget_id or "")
		if thread_id ~= "" then
			local command = "gh api --method PATCH " .. shell.quote("notifications/threads/" .. thread_id)
			easybar.exec_async(command, { timeout_seconds = 20 }, function(output, code)
				if code == 0 then
					refresh()
				else
					easybar.log(
						easybar.level.error,
						"failed to mark GitHub notification as read: "
							.. (text.trim(output) ~= "" and text.trim(output) or "exit " .. tostring(code))
					)
				end
			end)
		end
	elseif event.action_id == "open" then
		for _, notification in ipairs(notifications) do
			if tostring(notification.id) == event.target_widget_id then
				easybar.exec_async("open " .. shell.quote(notification_url(notification)), nil, function() end)
				break
			end
		end
	end
end)

easybar.inbox.on_context_action(SOURCE, function(event)
	if event.action_id == "refresh" then
		refresh()
	end
end)

local timer = easybar.add(easybar.kind.item, "github_inbox_timer", {
	drawing = false,
	interval = POLL_INTERVAL_SECONDS,
	on_interval = refresh,
})
timer:subscribe({ easybar.events.forced, easybar.events.system_woke }, refresh)
refresh()
