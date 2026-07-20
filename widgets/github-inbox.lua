-- Inbox-only GitHub notifications. Requires an authenticated `gh` CLI.

local retry = require("retry")
local text = require("text")

local SOURCE = "GitHub"
local POLL_INTERVAL_SECONDS = 300
local WAKE_REFRESH_DELAY_SECONDS = 3
local REFRESH_BACKOFF_SECONDS = { 2, 5 }
local notifications = {}
local refreshing = false
local pending_wake_refresh = nil

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

local function publish_notifications(output)
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
end

local function refresh()
	if refreshing then
		return
	end

	if pending_wake_refresh ~= nil then
		pending_wake_refresh:cancel()
		pending_wake_refresh = nil
	end

	refreshing = true

	retry.run(easybar, {
		delays = REFRESH_BACKOFF_SECONDS,
		attempt = function(done)
			return easybar.spawn_async({
				"gh",
				"api",
				"--paginate",
				"--slurp",
				"-H",
				"Accept: application/vnd.github+json",
				"notifications?all=false&per_page=100",
			}, { timeout_seconds = 20, max_output_bytes = 1048576 }, done)
		end,
		should_retry = retry.is_transient_network_error,
		on_complete = function(output, code)
			refreshing = false
			if code ~= 0 then
				publish_error(text.trim(output) ~= "" and text.trim(output) or "Run 'gh auth login' and check app.env PATH")
				return
			end

			publish_notifications(output)
		end,
	})
end

local function schedule_wake_refresh()
	if pending_wake_refresh ~= nil then
		pending_wake_refresh:cancel()
	end

	pending_wake_refresh = easybar.after(WAKE_REFRESH_DELAY_SECONDS, function()
		pending_wake_refresh = nil
		refresh()
	end)
end

easybar.inbox.on_action(SOURCE, function(event)
	if event.action_id == "refresh" then
		refresh()
	elseif event.action_id == "mark_read" then
		local thread_id = tostring(event.target_widget_id or "")
		if thread_id ~= "" then
			easybar.spawn_async({ "gh", "api", "--method", "PATCH", "notifications/threads/" .. thread_id }, {
				timeout_seconds = 20,
			}, function(output, code)
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
				easybar.spawn_async({ "open", notification_url(notification) }, nil, function() end)
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

timer:subscribe(easybar.events.forced, refresh)
timer:subscribe(easybar.events.system_woke, schedule_wake_refresh)

refresh()
