-- Inbox-only assigned GitLab work items. Requires an authenticated `glab` CLI.

local shell = require("shell")
local text = require("text")

local SOURCE = "GitLab"
local POLL_INTERVAL_SECONDS = 300
local work_items = {}
local refreshing = false

local function publish_error(message)
	easybar.inbox.replace(SOURCE, {
		{
			id = "error",
			title = "GitLab work items unavailable",
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
	local issues = "issues?scope=assigned_to_me&state=opened&non_archived=true&order_by=updated_at&sort=desc&per_page=100"
	local merge_requests =
		"merge_requests?scope=assigned_to_me&state=opened&non_archived=true&order_by=updated_at&sort=desc&per_page=100"
	local command = table.concat({
		"set -e",
		"issues=$(GLAB_NO_PROMPT=1 glab api --paginate " .. shell.quote(issues) .. ")",
		"mrs=$(GLAB_NO_PROMPT=1 glab api --paginate " .. shell.quote(merge_requests) .. ")",
		[[printf '{"issues":%s,"merge_requests":%s}\n' "$issues" "$mrs"]],
	}, "; ")
	easybar.exec_async(command, { timeout_seconds = 30, max_output_bytes = 2097152 }, function(output, code)
		refreshing = false
		if code ~= 0 then
			publish_error(text.trim(output) ~= "" and text.trim(output) or "Run 'glab auth login' and check app.env PATH")
			return
		end
		local ok, response = pcall(easybar.json.decode, output)
		if not ok or type(response) ~= "table" then
			publish_error("GitLab returned invalid JSON")
			return
		end
		work_items = {}
		for _, pair in ipairs({ { "issue", response.issues }, { "merge_request", response.merge_requests } }) do
			for _, item in ipairs(type(pair[2]) == "table" and pair[2] or {}) do
				item.kind = pair[1]
				work_items[#work_items + 1] = item
			end
		end
		local items = {}
		for _, item in ipairs(work_items) do
			local id = item.kind .. ":" .. tostring(item.id or item.iid)
			items[#items + 1] = {
				id = id,
				title = text.trim(item.title) ~= "" and item.title or "Untitled work item",
				body = type(item.references) == "table" and item.references.full or nil,
				category = item.kind == "merge_request" and "Merge requests" or "Issues",
				severity = "info",
				unread = true,
				actions = { { id = "open", title = "Open" } },
			}
		end
		easybar.inbox.replace(SOURCE, items)
	end)
end

easybar.inbox.on_action(SOURCE, function(event)
	if event.action_id == "refresh" then
		refresh()
	elseif event.action_id == "open" then
		for _, item in ipairs(work_items) do
			if item.kind .. ":" .. tostring(item.id or item.iid) == event.target_widget_id then
				easybar.exec_async("open " .. shell.quote(item.web_url), nil, function() end)
				break
			end
		end
	end
end)

local timer = easybar.add(easybar.kind.item, "gitlab_inbox_timer", {
	drawing = false,
	interval = POLL_INTERVAL_SECONDS,
	on_interval = refresh,
})
timer:subscribe({ easybar.events.forced, easybar.events.system_woke }, refresh)
refresh()
