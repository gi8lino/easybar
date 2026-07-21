--- Module contract:
--- Owns synchronous and asynchronous command request state and callbacks.
local M = {}

local MAX_PENDING_ASYNC_COMMANDS = 4096
local MAX_PENDING_SYNC_COMMANDS = 16

local function normalize_output(output, options)
	local value = type(output) == "string" and output or tostring(output or "")
	if options and options.raw_output == true then
		return value
	end
	return (value:gsub("[\r\n]+$", ""))
end

local function count_entries(values)
	local count = 0
	for _ in pairs(values) do
		count = count + 1
	end
	return count
end

function M.new(state, hooks)
	local broker = {}
	local request_sync_command = hooks.request_sync_command
	local request_async_command = hooks.request_async_command
	local request_async_process = hooks.request_async_process
	local request_cancel_async = hooks.request_cancel_async
	local before_exec_callback = hooks.before_exec_callback
	local before_async_callback = hooks.before_async_callback
	local on_async_job_started = hooks.on_async_job_started
	local on_async_job_completed = hooks.on_async_job_completed
	local on_async_callback_error = hooks.on_async_callback_error
	local on_protocol_warning = hooks.on_protocol_warning
	local normalize_command_options = hooks.normalize_command_options
	local normalize_process_arguments = hooks.normalize_process_arguments
	local fallback_token = hooks.fallback_token

	function broker.required_driver_events()
		return {}
	end

	function broker.expect_sync_response(token, options)
		assert(type(token) == "string" and token ~= "", "sync command response requires token")
		assert(state.pending_sync_commands[token] == nil, "duplicate synchronous easybar command token: " .. token)
		assert(
			count_entries(state.pending_sync_commands) < MAX_PENDING_SYNC_COMMANDS,
			"too many pending synchronous easybar commands"
		)
		state.pending_sync_commands[token] = { options = options }
	end

	function broker.handle_command_response(token, output, code)
		assert(type(token) == "string" and token ~= "", "command response requires token")
		local raw_output = type(output) == "string" and output or tostring(output or "")
		local normalized_code = tonumber(code) or 1
		local pending = state.pending_async_commands[token]

		if pending ~= nil then
			state.pending_async_commands[token] = nil
			on_async_job_completed(token, normalized_code)
			before_async_callback()
			local ok, err = pcall(pending.callback, normalize_output(raw_output, pending.options), normalized_code)
			if not ok then
				on_async_callback_error(pending.command, err)
			end
			return true
		end

		local synchronous = state.pending_sync_commands[token]
		if synchronous then
			state.pending_command_responses[token] = {
				output = normalize_output(raw_output, synchronous.options),
				code = normalized_code,
			}
			return true
		end

		on_protocol_warning("ignored unknown command response token=" .. tostring(token))
		return false
	end

	function broker.take_pending_command_response(token)
		local response = state.pending_command_responses[token]
		if response ~= nil then
			state.pending_command_responses[token] = nil
			state.pending_sync_commands[token] = nil
		end
		return response
	end

	function broker.abandon_sync_response(token)
		local existed = state.pending_sync_commands[token] ~= nil or state.pending_command_responses[token] ~= nil
		state.pending_sync_commands[token] = nil
		state.pending_command_responses[token] = nil
		return existed
	end

	local function add_async(token, command, callback, options)
		assert(
			count_entries(state.pending_async_commands) < MAX_PENDING_ASYNC_COMMANDS,
			"too many pending asynchronous easybar commands"
		)
		assert(state.pending_async_commands[token] == nil, "duplicate easybar async token: " .. tostring(token))
		state.pending_async_commands[token] = {
			command = command,
			callback = callback,
			options = options,
		}
		on_async_job_started(token, command)
		return token
	end

	function broker.spawn_async(arguments, options, callback, ...)
		local signature = "easybar.spawn_async(arguments, options, callback)"
		assert(select("#", ...) == 0, signature .. " does not accept extra arguments")
		assert(type(callback) == "function", signature .. " requires callback")
		assert(type(request_async_process) == "function", "easybar.spawn_async unavailable without host runner")
		local normalized_arguments = normalize_process_arguments(arguments, signature)
		local normalized_options = normalize_command_options(options, signature)
		local token = request_async_process(normalized_arguments, normalized_options) or fallback_token("command")
		return add_async(token, table.concat(normalized_arguments, " "), callback, normalized_options)
	end

	function broker.exec_async(command, options, callback, ...)
		local signature = "easybar.exec_async(command, options, callback)"
		assert(type(command) == "string" and command ~= "", signature .. " requires command")
		assert(not command:find("%z"), signature .. " rejects NUL bytes")
		assert(select("#", ...) == 0, signature .. " does not accept extra arguments")
		assert(type(callback) == "function", signature .. " requires callback")
		assert(type(request_async_command) == "function", "easybar.exec_async unavailable without host runner")
		local normalized_options = normalize_command_options(options, signature)
		local token = request_async_command(command, normalized_options) or fallback_token("command")
		return add_async(token, command, callback, normalized_options)
	end

	function broker.cancel_async(token, ...)
		assert(type(token) == "string" and token ~= "", "easybar.cancel_async(token) requires token")
		assert(select("#", ...) == 0, "easybar.cancel_async(token) does not accept extra arguments")
		assert(type(request_cancel_async) == "function", "easybar.cancel_async unavailable without host runner")
		if state.pending_async_commands[token] == nil then
			return false
		end
		request_cancel_async(token)
		return true
	end

	function broker.exec(command, options, ...)
		local signature = "easybar.exec(command, options)"
		assert(type(command) == "string" and command ~= "", signature .. " requires command")
		assert(not command:find("%z"), signature .. " rejects NUL bytes")
		assert(select("#", ...) == 0, signature .. " does not accept a callback")
		assert(type(request_sync_command) == "function", "easybar.exec unavailable without host runner")
		local normalized_options = normalize_command_options(options, signature)
		before_exec_callback()
		local output, code = request_sync_command(command, normalized_options)
		return normalize_output(output, normalized_options), tonumber(code) or 1
	end

	return broker
end

return M
