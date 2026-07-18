-- Publishes representative test data for the native inbox.

local SOURCE = "Inbox demo"
local items = {
	{
		id = "welcome",
		title = "Welcome to the EasyBar inbox",
		body = "This body supports **inline Markdown**, `code`, and links.",
		format = "markdown",
		timestamp = os.time(),
		category = "Examples",
		severity = "info",
		unread = true,
		actions = { { id = "dismiss", title = "Dismiss" } },
	},
	{
		id = "success",
		title = "Build completed",
		body = "All checks passed.",
		timestamp = os.time() - 60,
		category = "CI",
		severity = "success",
		unread = true,
	},
	{
		id = "warning",
		title = "Dependency update available",
		body = "Review the changelog before upgrading.",
		timestamp = os.time() - 120,
		category = "Updates",
		severity = "warning",
		unread = false,
	},
	{
		id = "error",
		title = "Example service unavailable",
		body = "This is test data; no real service failed.",
		timestamp = os.time() - 180,
		category = "Services",
		severity = "error",
		unread = true,
		actions = { { id = "dismiss", title = "Dismiss" } },
	},
}

local function publish()
	easybar.inbox.replace(SOURCE, items)
end

easybar.inbox.on_action(SOURCE, function(event)
	if event.action_id ~= "dismiss" then
		return
	end

	for index = #items, 1, -1 do
		if items[index].id == event.target_widget_id then
			table.remove(items, index)
			break
		end
	end
	publish()
end)

publish()
