-- Publishes representative test data for the native inbox.

local SOURCE = "Inbox demo"
local NOW = os.time()

local GITHUB = {
	name = "GitHub",
	icon = easybar.asset("assets/github.svg"),
	color = "#A371F7",
}
local GITLAB = {
	name = "GitLab",
	icon = easybar.asset("assets/gitlab.svg"),
	color = "#FC6D26",
}
local HOMEBREW = {
	name = "Homebrew",
	icon = "🍺",
	color = "#FBB040",
}

local items = {
	{
		id = "github-review",
		title = "Review requested on pull request #482",
		body = "The macOS checks passed and the change is ready for review.",
		timestamp = NOW,
		category = "Pull requests",
		severity = "success",
		unread = true,
		source = GITHUB,
		actions = { { id = "dismiss", title = "Dismiss" } },
	},
	{
		id = "github-security",
		title = "Dependabot found a critical vulnerability",
		body = "`swift-nio` should be upgraded before the next release.",
		format = "markdown",
		timestamp = NOW - 90,
		category = "Security",
		severity = "error",
		unread = true,
		source = GITHUB,
	},
	{
		id = "github-mention",
		title = "You were mentioned in issue #917",
		body = "A question is waiting for your input.",
		timestamp = NOW - 180,
		category = "Issues",
		severity = "info",
		unread = false,
		source = GITHUB,
	},
	{
		id = "gitlab-pipeline",
		title = "Pipeline requires attention",
		body = "The deploy job is waiting for manual approval.",
		timestamp = NOW - 270,
		category = "Pipelines",
		severity = "warning",
		unread = true,
		source = GITLAB,
	},
	{
		id = "gitlab-merge-request",
		title = "Merge request !128 is ready",
		body = "All discussions are resolved and the pipeline passed.",
		timestamp = NOW - 360,
		category = "Merge requests",
		severity = "success",
		unread = true,
		source = GITLAB,
		actions = { { id = "dismiss", title = "Dismiss" } },
	},
	{
		id = "gitlab-issue",
		title = "Issue #73 was assigned to you",
		body = "Investigate the intermittent authentication timeout.",
		timestamp = NOW - 450,
		category = "Issues",
		severity = "info",
		unread = false,
		source = GITLAB,
	},
	{
		id = "brew-outdated",
		title = "Three packages can be upgraded",
		body = "formulae: lua, swiftformat · casks: visual-studio-code",
		timestamp = NOW - 540,
		category = "Packages",
		severity = "info",
		unread = false,
		source = HOMEBREW,
		actions = { { id = "dismiss", title = "Dismiss" } },
	},
	{
		id = "brew-pinned",
		title = "Pinned formula was not upgraded",
		body = "postgresql@16 remains on 16.3.",
		timestamp = NOW - 630,
		category = "Formulae",
		severity = "warning",
		unread = true,
		source = HOMEBREW,
	},
	{
		id = "brew-error",
		title = "Could not refresh package metadata",
		body = "Homebrew could not reach the package registry.",
		timestamp = NOW - 720,
		category = "Updates",
		severity = "error",
		unread = true,
		source = HOMEBREW,
	},
}

local function publish()
	easybar.inbox.replace(SOURCE, items)
end

local function handle_action(event)
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
end

easybar.inbox.on_action(SOURCE, handle_action)

publish()
