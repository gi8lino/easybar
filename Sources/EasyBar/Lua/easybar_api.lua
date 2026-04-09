-- EasyBar Lua API stub version: dev
---@meta

---@alias EasyBarLevel
---| '"trace"'
---| '"debug"'
---| '"info"'
---| '"warn"'
---| '"error"'

---@alias EasyBarKind
---| '"item"'
---| '"row"'
---| '"column"'
---| '"group"'
---| '"popup"'
---| '"slider"'
---| '"progress"'
---| '"progress_slider"'
---| '"sparkline"'
---| '"spaces"'

---@alias EasyBarEventName
---| '"routine"'
---| '"forced"'
---| '"system_woke"'
---| '"sleep"'
---| '"space_change"'
---| '"app_switch"'
---| '"display_change"'
---| '"minute_tick"'
---| '"second_tick"'
---| '"wifi_change"'
---| '"network_change"'
---| '"volume_change"'
---| '"mute_change"'
---| '"calendar_change"'
---| '"power_source_change"'
---| '"charging_state_change"'
---| '"workspace_change"'
---| '"focus_change"'
---| '"space_mode_change"'
---| '"mouse.entered"'
---| '"mouse.exited"'
---| '"mouse.clicked"'
---| '"mouse.down"'
---| '"mouse.up"'
---| '"mouse.scrolled"'
---| '"slider.preview"'
---| '"slider.changed"'

---@class EasyBarNetworkEventData
---@field primary_interface_is_tunnel? boolean Whether the current primary network interface is a tunnel.
---@field interface_name? string The network interface name when provided.

---@class EasyBarPowerEventData
---@field charging? boolean Whether the current power source is charging.

---@class EasyBarAudioEventData
---@field muted? boolean Whether the current audio output is muted.
---@field value? number The current audio-related value when provided.

---@class EasyBarEvent
---@field name string The dispatched event name.
---@field widget_id? string The subscribed widget id receiving the event.
---@field target_widget_id? string The concrete node id that received the interaction.
---@field app_name? string The focused app name for app-switch style events.
---@field button? string The mouse button name, usually `left` or `right`.
---@field direction? string The scroll direction, usually `up` or `down`.
---@field value? number|string|boolean The event value for slider and driver updates.
---@field delta_x? number Horizontal scroll delta.
---@field delta_y? number Vertical scroll delta.
---@field network? EasyBarNetworkEventData Structured network event data.
---@field power? EasyBarPowerEventData Structured power event data.
---@field audio? EasyBarAudioEventData Structured audio event data.

---@alias EasyBarEventHandler fun(event: EasyBarEvent)

---@class EasyBarEventToken
---@field name EasyBarEventName The canonical runtime event name sent by EasyBar.

---@class EasyBarMouseEvents
---@field entered? EasyBarEventToken Fired when the pointer enters the subscribed node frame.
---@field exited? EasyBarEventToken Fired when the pointer leaves the subscribed node frame.
---@field clicked? EasyBarEventToken Fired when the subscribed node is clicked.
---@field down? EasyBarEventToken Fired on mouse button press over the subscribed node.
---@field up? EasyBarEventToken Fired on mouse button release over the subscribed node.
---@field scrolled? EasyBarEventToken Fired when the pointer scrolls over the subscribed node.

---@class EasyBarSliderEvents
---@field preview? EasyBarEventToken Fired while a slider is being previewed or dragged.
---@field changed? EasyBarEventToken Fired when a slider value is committed.

---@class EasyBarEvents
---@field routine? EasyBarEventToken Fired from `update_freq` polling on subscribed widgets.
---@field forced? EasyBarEventToken Fired when EasyBar or `easybar` triggers a manual refresh.
---@field system_woke? EasyBarEventToken Fired after the system wakes from sleep.
---@field sleep? EasyBarEventToken Fired before the system goes to sleep.
---@field space_change? EasyBarEventToken Fired when the active macOS space changes.
---@field app_switch? EasyBarEventToken Fired when the frontmost app changes.
---@field display_change? EasyBarEventToken Fired when attached displays change.
---@field power_source_change? EasyBarEventToken Fired when the power source changes.
---@field charging_state_change? EasyBarEventToken Fired when charging starts or stops.
---@field wifi_change? EasyBarEventToken Fired when Wi-Fi state or SSID changes.
---@field network_change? EasyBarEventToken Fired when network routing or tunnel state changes.
---@field volume_change? EasyBarEventToken Fired when output volume changes.
---@field mute_change? EasyBarEventToken Fired when mute state changes.
---@field minute_tick? EasyBarEventToken Fired once per minute.
---@field second_tick? EasyBarEventToken Fired once per second.
---@field calendar_change? EasyBarEventToken Fired when the calendar snapshot updates.
---@field focus_change? EasyBarEventToken Fired when workspace focus changes.
---@field workspace_change? EasyBarEventToken Fired when workspace layout or selection changes.
---@field space_mode_change? EasyBarEventToken Fired when the AeroSpace layout mode changes.
---@field mouse? EasyBarMouseEvents Mouse interaction event tokens.
---@field slider? EasyBarSliderEvents Slider interaction event tokens.

---@class EasyBarLevels
---@field trace EasyBarLevel
---@field debug EasyBarLevel
---@field info EasyBarLevel
---@field warn EasyBarLevel
---@field error EasyBarLevel

---@class EasyBar
local EasyBar = {}

---Sets per-widget default properties for future `easybar.add(...)` calls.
---Defaults apply only within the current widget file.
---@param props table
function EasyBar.default(props) end

---Clears previously configured widget defaults.
function EasyBar.clear_defaults() end

---Creates one EasyBar node.
---Use `item` for simple widgets, `group` for shared containers, and `row`/`column`
---for layout wrappers around child nodes.
---@param kind EasyBarKind
---@param id string
---@param props? table
function EasyBar.add(kind, id, props) end

---Merges properties into one existing node.
---@param id string
---@param props table
function EasyBar.set(id, props) end

---Returns a copy of the current property table for one node.
---@param id string
---@return table
function EasyBar.get(id) end

---Removes one node and all of its descendants.
---@param id string
function EasyBar.remove(id) end

---Runs one shell command.
---When a callback is provided, the trimmed command output is passed to it.
---@param command string
---@param callback? fun(output: string): any
---@return any
function EasyBar.exec(command, callback) end

---All supported EasyBar event tokens.
---@type EasyBarEvents
EasyBar.events = {}

---All supported EasyBar log levels.
---@type EasyBarLevels
EasyBar.level = {}

---Subscribes one node to one or more event tokens.
---Interaction belongs to the subscribed node frame.
---@param id string
---@param events EasyBarEventToken|EasyBarEventToken[]
---@param handler EasyBarEventHandler
function EasyBar.subscribe(id, events, handler) end

---Writes one widget-scoped log line to the EasyBar host logger.
---Supported levels are `trace`, `debug`, `info`, `warn`, and `error`.
---Which messages are actually emitted depends on the host logging level.
---@param level EasyBarLevel|string
---@param ... any
function EasyBar.log(level, ...) end

---@type EasyBar
easybar = easybar

return easybar
