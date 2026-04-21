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

---@alias EasyBarMouseButton
---| '"left"'
---| '"right"'
---| '"middle"'

---@alias EasyBarScrollDirection
---| '"up"'
---| '"down"'
---| '"left"'
---| '"right"'

---@alias EasyBarBoolLike boolean
---| '"on"'
---| '"off"'

---@alias EasyBarRootPosition
---| '"left"'
---| '"center"'
---| '"right"'

---@alias EasyBarPosition string

---@class (exact) EasyBarFontProps
---@field size? number Font size in points.

---@class (exact) EasyBarLabelProps
---@field string? string Label text.
---@field color? string Hex color override for the label.
---@field font? EasyBarFontProps Label font overrides.

---@class (exact) EasyBarIconProps
---@field string? string Icon glyph text.
---@field color? string Hex color override for the icon.
---@field font? EasyBarFontProps Icon font overrides.
---@field image? string Image path to render instead of icon text.
---@field image_size? number Image size in points.
---@field image_corner_radius? number Image corner radius in points.
---@field padding_right? number Additional spacing between icon and label.

---@class (exact) EasyBarImageProps
---@field path? string Image path.
---@field size? number Image size in points.
---@field corner_radius? number Image corner radius in points.

---@class (exact) EasyBarBackgroundProps
---@field color? string Background fill color.
---@field border_color? string Border stroke color.
---@field border_width? number Border width in points.
---@field corner_radius? number Corner radius in points.
---@field padding_left? number Left padding in points.
---@field padding_right? number Right padding in points.
---@field padding_top? number Top padding in points.
---@field padding_bottom? number Bottom padding in points.

---@class (exact) EasyBarMarginProps
---@field margin_left? number Left margin in points.
---@field margin_right? number Right margin in points.
---@field margin_top? number Top margin in points.
---@field margin_bottom? number Bottom margin in points.

---@class (exact) EasyBarPopupProps
---@field drawing? EasyBarBoolLike Whether popup content is shown.
---@field background? EasyBarBackgroundProps Popup background styling.
---@field spacing? number Child spacing inside the popup container.
---@field width? number Popup width in points.
---@field height? number Popup height in points.
---@field opacity? number Popup opacity from `0` to `1`.
---@field y_offset? number Vertical offset in points.
---@field padding_x? number Horizontal popup padding shorthand.
---@field padding_y? number Vertical popup padding shorthand.
---@field paddingX? number Horizontal popup padding shorthand.
---@field paddingY? number Vertical popup padding shorthand.
---@field padding_left? number Left popup padding in points.
---@field padding_right? number Right popup padding in points.
---@field padding_top? number Top popup padding in points.
---@field padding_bottom? number Bottom popup padding in points.
---@field margin_x? number Horizontal popup margin shorthand.
---@field margin_y? number Vertical popup margin shorthand.
---@field marginX? number Horizontal popup margin shorthand.
---@field marginY? number Vertical popup margin shorthand.
---@field margin_left? number Left popup margin in points.
---@field margin_right? number Right popup margin in points.
---@field margin_top? number Top popup margin in points.
---@field margin_bottom? number Bottom popup margin in points.
---@field backgroundColor? string Legacy direct background color alias.
---@field borderColor? string Legacy direct border color alias.
---@field borderWidth? number Legacy direct border width alias.
---@field cornerRadius? number Legacy direct corner radius alias.

---@alias EasyBarLabelLike string|number|boolean|EasyBarLabelProps
---@alias EasyBarIconLike string|number|boolean|EasyBarIconProps

---@class (exact) EasyBarNodeProps
---@field position? EasyBarPosition Root nodes use `left`, `center`, or `right`; popup children use `popup.<id>`.
---@field order? integer Render order within one bar position.
---@field drawing? EasyBarBoolLike Whether the node is visible.
---@field parent? string Parent node id for nested layout.
---@field width? number Width in points.
---@field height? number Height in points.
---@field opacity? number Opacity from `0` to `1`.
---@field y_offset? number Vertical offset in points.
---@field interval? number Polling interval in seconds.
---@field on_interval? fun() Interval callback executed on the configured cadence.
---@field color? string Primary foreground color.
---@field icon? EasyBarIconLike Icon table or shorthand value.
---@field label? EasyBarLabelLike Label table or shorthand value.
---@field image? EasyBarImageProps Standalone image content.
---@field background? EasyBarBackgroundProps Background and padding styling.
---@field margin? EasyBarMarginProps Margin overrides for individual edges.
---@field popup? EasyBarPopupProps Popup container properties.
---@field spacing? number Child spacing for rows, groups, and popup content.
---@field value? number Current scalar value for progress/slider nodes.
---@field min? number Minimum value for progress/slider nodes.
---@field max? number Maximum value for progress/slider nodes.
---@field step? number Slider step size.
---@field values? number[] Sparkline sample values.
---@field line_width? number Sparkline stroke width.
---@field lineWidth? number Legacy sparkline stroke width alias.
---@field padding_x? number Horizontal padding shorthand.
---@field padding_y? number Vertical padding shorthand.
---@field paddingX? number Horizontal padding shorthand.
---@field paddingY? number Vertical padding shorthand.
---@field margin_x? number Horizontal margin shorthand.
---@field margin_y? number Vertical margin shorthand.
---@field marginX? number Horizontal margin shorthand.
---@field marginY? number Vertical margin shorthand.
---@field margin_left? number Left margin in points.
---@field margin_right? number Right margin in points.
---@field margin_top? number Top margin in points.
---@field margin_bottom? number Bottom margin in points.
---@field backgroundColor? string Legacy direct background color alias.
---@field borderColor? string Legacy direct border color alias.
---@field borderWidth? number Legacy direct border width alias.
---@field cornerRadius? number Legacy direct corner radius alias.

---@alias EasyBarEventName
---| '"interval"'
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
---@field button? EasyBarMouseButton|string The mouse button name, usually `left`, `right`, or `middle`.
---@field direction? EasyBarScrollDirection|string The scroll direction, usually `up`, `down`, `left`, or `right`.
---@field value? number|string|boolean The event value for slider and driver updates.
---@field delta_x? number Horizontal scroll delta.
---@field delta_y? number Vertical scroll delta.
---@field network? EasyBarNetworkEventData Structured network event data.
---@field power? EasyBarPowerEventData Structured power event data.
---@field audio? EasyBarAudioEventData Structured audio event data.

---@alias EasyBarEventHandler fun(event: EasyBarEvent)

---@class EasyBarEventToken
---@field name EasyBarEventName The canonical runtime event name sent by EasyBar.

---@class EasyBarMouseButtons
---@field left EasyBarMouseButton
---@field right EasyBarMouseButton
---@field middle EasyBarMouseButton

---@class EasyBarScrollDirections
---@field up EasyBarScrollDirection
---@field down EasyBarScrollDirection
---@field left EasyBarScrollDirection
---@field right EasyBarScrollDirection

---@class EasyBarMouseEvents
---@field entered? EasyBarEventToken Fired when the pointer enters the subscribed node frame.
---@field exited? EasyBarEventToken Fired when the pointer leaves the subscribed node frame.
---@field clicked? EasyBarEventToken Fired when the subscribed node is clicked.
---@field down? EasyBarEventToken Fired on mouse button press over the subscribed node.
---@field up? EasyBarEventToken Fired on mouse button release over the subscribed node.
---@field scrolled? EasyBarEventToken Fired when the pointer scrolls over the subscribed node.
---@field left_button EasyBarMouseButton Constant for `event.button == "left"`.
---@field right_button EasyBarMouseButton Constant for `event.button == "right"`.
---@field middle_button EasyBarMouseButton Constant for `event.button == "middle"`.
---@field up_scroll EasyBarScrollDirection Constant for `event.direction == "up"`.
---@field down_scroll EasyBarScrollDirection Constant for `event.direction == "down"`.
---@field left_scroll EasyBarScrollDirection Constant for `event.direction == "left"`.
---@field right_scroll EasyBarScrollDirection Constant for `event.direction == "right"`.
---@field buttons EasyBarMouseButtons Nested mouse-button constants.
---@field directions EasyBarScrollDirections Nested scroll-direction constants.

---@class EasyBarSliderEvents
---@field preview? EasyBarEventToken Fired while a slider is being previewed or dragged.
---@field changed? EasyBarEventToken Fired when a slider value is committed.

---@class EasyBarEvents
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
---@field mouse? EasyBarMouseEvents Mouse interaction event tokens and constants.
---@field slider? EasyBarSliderEvents Slider interaction event tokens.

---@class EasyBarLevels
---@field trace EasyBarLevel
---@field debug EasyBarLevel
---@field info EasyBarLevel
---@field warn EasyBarLevel
---@field error EasyBarLevel

---@class EasyBarKinds
---@field item EasyBarKind
---@field row EasyBarKind
---@field column EasyBarKind
---@field group EasyBarKind
---@field popup EasyBarKind
---@field slider EasyBarKind
---@field progress EasyBarKind
---@field progress_slider EasyBarKind
---@field sparkline EasyBarKind
---@field spaces EasyBarKind

---Widget-scoped EasyBar API injected into every widget file.
---Use it to create nodes, update props, subscribe to events, and write widget logs.
---@class EasyBar
---@field add fun(kind: EasyBarKind, id: string, props?: EasyBarNodeProps) Creates one node in the widget registry.
---@field clear_defaults fun() Clears widget-local defaults previously set with `easybar.default(...)`.
---@field default fun(props: EasyBarNodeProps) Sets widget-local default props for future `easybar.add(...)` calls.
---@field events EasyBarEvents Event token namespace used by `easybar.subscribe(...)`, plus mouse constants.
---@field exec fun(command: string, callback?: fun(output: string): any): any Runs one shell command and optionally receives trimmed output.
---@field get fun(id: string): EasyBarNodeProps Returns a copy of the current props for one node.
---@field kind EasyBarKinds Kind constants used by `easybar.add(...)`.
---@field level EasyBarLevels Log level namespace used by `easybar.log(...)`.
---@field log fun(level: EasyBarLevel|string, ...: any) Writes one widget-scoped log line to the EasyBar host logger.
---@field remove fun(id: string) Removes one node and all descendants.
---@field set fun(id: string, props: EasyBarNodeProps) Merges props into one existing node.
---@field subscribe fun(id: string, events: EasyBarEventToken|EasyBarEventToken[], handler: EasyBarEventHandler) Subscribes one node to runtime or interaction events.
local EasyBar = {}

---Sets per-widget default properties for future `easybar.add(...)` calls.
---Defaults apply only within the current widget file.
---@param props EasyBarNodeProps
function EasyBar.default(props) end

---Clears previously configured widget defaults.
function EasyBar.clear_defaults() end

---Creates one EasyBar node.
---Use `easybar.kind.item` for simple widgets, `easybar.kind.group` for shared containers,
---and `easybar.kind.row` / `easybar.kind.column` for layout wrappers around child nodes.
---When `interval` and `on_interval` are provided, EasyBar runs `on_interval`
---on the configured cadence without requiring an event subscription.
---@param kind EasyBarKind
---@param id string
---@param props? EasyBarNodeProps
function EasyBar.add(kind, id, props) end

---Merges properties into one existing node.
---@param id string
---@param props EasyBarNodeProps
function EasyBar.set(id, props) end

---Returns a copy of the current property table for one node.
---@param id string
---@return EasyBarNodeProps
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

---All supported EasyBar event tokens and mouse constants.
---@type EasyBarEvents
EasyBar.events = {}

---All supported EasyBar log levels.
---@type EasyBarLevels
EasyBar.level = {}

---All supported EasyBar kind constants.
---@type EasyBarKinds
EasyBar.kind = {}

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
