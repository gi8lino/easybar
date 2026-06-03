-- EasyBar Lua API stub version: dev
---@meta

---Logging levels accepted by `easybar.log(...)`.
---@alias EasyBarLevel
---Verbose diagnostic logging intended for deep debugging.
---| '"trace"'
---Useful development-time logging with lower volume than `trace`.
---| '"debug"'
---Normal informational logging.
---| '"info"'
---Warnings about unexpected but recoverable conditions.
---| '"warn"'
---Errors that indicate a widget or runtime problem.
---| '"error"'

---Literal node kinds accepted by `easybar.add(...)`.
---In normal widget code, prefer the `easybar.kind.*` constants over raw strings.
---@alias EasyBarKind
---Basic widget node for most text, icon, and interaction cases.
---| '"item"'
---Horizontal layout container for child nodes.
---| '"row"'
---Vertical layout container for child nodes.
---| '"column"'
---Shared container that lets multiple child nodes look and behave like one widget.
---| '"group"'
---Popup container node used for richer attached surfaces.
---| '"popup"'
---Interactive scalar control that emits slider events.
---| '"slider"'
---Read-only scalar meter for current numeric values.
---| '"progress"'
---Combined progress-style display with slider interaction.
---| '"progress_slider"'
---Compact line-chart style node for a list of samples.
---| '"sparkline"'
---Specialized workspace or space indicator style node.
---| '"spaces"'

---Mouse button names that may appear in event payloads.
---@alias EasyBarMouseButton
---Primary mouse button.
---| '"left"'
---Secondary mouse button.
---| '"right"'
---Middle mouse button.
---| '"middle"'

---Scroll directions that may appear in event payloads.
---@alias EasyBarScrollDirection
---Upward scrolling.
---| '"up"'
---Downward scrolling.
---| '"down"'
---Leftward scrolling.
---| '"left"'
---Rightward scrolling.
---| '"right"'

---Boolean-like values accepted by some properties.
---EasyBar accepts both native Lua booleans and the string forms `"on"` and `"off"`.
---@alias EasyBarBoolLike boolean
---String form treated as enabled or visible.
---| '"on"'
---String form treated as disabled or hidden.
---| '"off"'

---Root-level bar positions used by top-level nodes.
---@alias EasyBarRootPosition
---Left bar region.
---| '"left"'
---Center bar region.
---| '"center"'
---Right bar region.
---| '"right"'

---Placement string for a node.
---At the root level this is usually `left`, `center`, or `right`; popup children use `popup.<parent-id>`.
---@alias EasyBarPosition string

---Font override fields used by label and icon content.
---@class (exact) EasyBarFontProps
---@field size? number Font size in points.

---Detailed label configuration used when a plain label value is not enough.
---@class (exact) EasyBarLabelProps
---@field string? string Label text.
---@field color? string Hex color override for the label.
---@field font? EasyBarFontProps Label font overrides.

---Detailed icon configuration used when a plain icon value is not enough.
---@class (exact) EasyBarIconProps
---@field string? string Icon glyph text.
---@field color? string Hex color override for the icon.
---@field font? EasyBarFontProps Icon font overrides.
---@field image? string Image path to render instead of icon text.
---@field image_size? number Image size in points.
---@field image_corner_radius? number Image corner radius in points.
---@field padding_right? number Additional layout spacing between the icon and following inline content.
---@field offset_x? number Horizontal visual icon offset in points without changing layout spacing.
---@field offset_y? number Vertical visual icon offset in points without changing layout spacing.

---Standalone image configuration for nodes that render an image instead of text.
---@class (exact) EasyBarImageProps
---@field path? string Image path.
---@field size? number Image size in points.
---@field corner_radius? number Image corner radius in points.

---Shared surface styling fields used by nodes and popups.
---@class (exact) EasyBarBackgroundProps
---@field color? string Background fill color.
---@field border_color? string Border stroke color.
---@field border_width? number Border width in points.
---@field corner_radius? number Corner radius in points.
---@field padding_left? number Left padding in points.
---@field padding_right? number Right padding in points.
---@field padding_top? number Top padding in points.
---@field padding_bottom? number Bottom padding in points.

---Outer spacing fields that push a node away from surrounding content.
---@class (exact) EasyBarMarginProps
---@field margin_left? number Left margin in points.
---@field margin_right? number Right margin in points.
---@field margin_top? number Top margin in points.
---@field margin_bottom? number Bottom margin in points.

---Container-level popup properties for visibility, layout, and surface styling.
---@class (exact) EasyBarPopupProps
---@field drawing? EasyBarBoolLike Whether popup content is shown.
---@field background? EasyBarBackgroundProps Popup background styling.
---@field spacing? number Child spacing inside the popup container.
---@field width? number Popup width in points.
---@field height? number Popup height in points.
---@field opacity? number Opacity from `0` to `1`.
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

---Accepted shorthand forms for label content.
---@alias EasyBarLabelLike string|number|boolean|EasyBarLabelProps

---Accepted shorthand forms for icon content.
---@alias EasyBarIconLike string|number|boolean|EasyBarIconProps

---The main property table accepted by `easybar.add(...)` and `node:set(...)`.
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
---@field on_interval? fun() Interval callback executed on this widget's own interval schedule.
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

-- Generated event annotations are inserted below when producing `easybar_api.lua`.
-- The standalone generated source lives in `easybar_api.events.lua`.
-- EasyBar generated event stub. Do not edit by hand.
-- Source of truth: Sources/EasyBarApp/Events/event_catalog.json
-- Regenerate with: scripts/generate_event_catalog.py
---Canonical runtime event-name strings carried inside `EasyBarEventToken.name`.
---In normal widget code, prefer `easybar.events.*` tokens over comparing raw strings.
---@alias EasyBarEventName
---Internal timer callback name delivered to the widget whose own `interval` schedule elapsed.
---| '"interval"'
---Fired when EasyBar or `easybar` triggers a manual refresh.
---| '"forced"'
---Fired after the system wakes from sleep.
---| '"system_woke"'
---Fired when the macOS user session becomes active.
---| '"session_active"'
---Fired when the macOS user session resigns active status.
---| '"session_inactive"'
---Fired before the system goes to sleep.
---| '"sleep"'
---Fired when the active macOS space changes.
---| '"space_change"'
---Fired when the frontmost app changes.
---| '"app_switch"'
---Fired when attached displays change.
---| '"display_change"'
---Fired when the power source changes.
---| '"power_source_change"'
---Fired when charging starts or stops.
---| '"charging_state_change"'
---Fired when Wi-Fi state or SSID changes.
---| '"wifi_change"'
---Fired when network routing or tunnel state changes.
---| '"network_change"'
---Fired when output volume changes.
---| '"volume_change"'
---Fired when mute state changes.
---| '"mute_change"'
---Fired once per minute.
---| '"minute_tick"'
---Fired once per second.
---| '"second_tick"'
---Fired when the calendar snapshot updates.
---| '"calendar_change"'
---Fired when workspace focus changes.
---| '"focus_change"'
---Fired when workspace layout or selection changes.
---| '"workspace_change"'
---Fired when the AeroSpace layout mode changes.
---| '"space_mode_change"'
---Fired when the pointer enters the subscribed node frame.
---| '"mouse.entered"'
---Fired when the pointer leaves the subscribed node frame.
---| '"mouse.exited"'
---Fired when the subscribed node is clicked.
---| '"mouse.clicked"'
---Fired on mouse button press over the subscribed node.
---| '"mouse.down"'
---Fired on mouse button release over the subscribed node.
---| '"mouse.up"'
---Fired when the pointer scrolls over the subscribed node.
---| '"mouse.scrolled"'
---Fired while a slider is being previewed or dragged.
---| '"slider.preview"'
---Fired when a slider value is committed.
---| '"slider.changed"'

---Structured network-specific fields that may be present on network-related events.
---@class EasyBarNetworkEventData
---@field primary_interface_is_tunnel? boolean Whether the current primary network interface is a tunnel.
---@field interface_name? string The network interface name when provided.

---Structured power-specific fields that may be present on charging or power-source events.
---@class EasyBarPowerEventData
---@field charging? boolean Whether the current power source is charging.

---Structured audio-specific fields that may be present on mute or volume events.
---@class EasyBarAudioEventData
---@field muted? boolean Whether the current audio output is muted.
---@field value? number The current audio-related value when provided.

---The event payload object delivered to event handlers.
---Different event families populate different optional fields.
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

---The callback signature used by `node:subscribe(...)` and `easybar.subscribe(...)`.
---@alias EasyBarEventHandler fun(event: EasyBarEvent)

---Opaque subscribe token object passed through from `easybar.events.*`.
---@class EasyBarEventToken
---@field name EasyBarEventName The canonical runtime event name sent by EasyBar.

---Convenience constants mirrored under `easybar.events.mouse.buttons`.
---@class EasyBarMouseButtons
---@field left EasyBarMouseButton Matches the primary mouse button.
---@field right EasyBarMouseButton Matches the secondary mouse button.
---@field middle EasyBarMouseButton Matches the middle mouse button.

---Convenience constants mirrored under `easybar.events.mouse.directions`.
---@class EasyBarScrollDirections
---@field up EasyBarScrollDirection Matches upward scrolling.
---@field down EasyBarScrollDirection Matches downward scrolling.
---@field left EasyBarScrollDirection Matches leftward scrolling.
---@field right EasyBarScrollDirection Matches rightward scrolling.

---Mouse-specific interaction tokens and convenience constants nested under `easybar.events.mouse`.
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

---Slider-specific interaction tokens nested under `easybar.events.slider`.
---@class EasyBarSliderEvents
---@field preview? EasyBarEventToken Fired while a slider is being previewed or dragged.
---@field changed? EasyBarEventToken Fired when a slider value is committed.

---Namespace object exposed as `easybar.events`.
---Use these tokens when subscribing widgets instead of hard-coding event-name strings.
---@class EasyBarEvents
---@field forced? EasyBarEventToken Fired when EasyBar or `easybar` triggers a manual refresh.
---@field system_woke? EasyBarEventToken Fired after the system wakes from sleep.
---@field session_active? EasyBarEventToken Fired when the macOS user session becomes active.
---@field session_inactive? EasyBarEventToken Fired when the macOS user session resigns active status.
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


---Namespace object exposed as `easybar.level`.
---@class EasyBarLevels
---@field trace EasyBarLevel
---@field debug EasyBarLevel
---@field info EasyBarLevel
---@field warn EasyBarLevel
---@field error EasyBarLevel

---Namespace object exposed as `easybar.kind`.
---These fields are the ergonomic way to pass node kinds to `easybar.add(...)`.
---@class EasyBarKinds
---@field item EasyBarKind Use for most ordinary widgets with icon, label, and interaction support.
---@field row EasyBarKind Use when several child nodes should be laid out horizontally.
---@field column EasyBarKind Use when several child nodes should be laid out vertically.
---@field group EasyBarKind Use when multiple child nodes should share one styled container.
---@field popup EasyBarKind Use for explicit popup container composition.
---@field slider EasyBarKind Use for interactive scalar controls.
---@field progress EasyBarKind Use for read-only scalar meters.
---@field progress_slider EasyBarKind Use when you want slider interaction with progress-style presentation.
---@field sparkline EasyBarKind Use for compact numeric trend lines.
---@field spaces EasyBarKind Use for workspace or space indicator style nodes.

---@class EasyBarNodeHandle
---@field id string Node id.
---@field name string Alias for `id`, useful when assigning parents.
---@field set fun(self: EasyBarNodeHandle, props: EasyBarNodeProps) Merges props into this node.
---@field get fun(self: EasyBarNodeHandle): EasyBarNodeProps Returns a copy of this node's props.
---@field remove fun(self: EasyBarNodeHandle) Removes this node and all descendants.
---@field subscribe fun(self: EasyBarNodeHandle, events: EasyBarEventToken|EasyBarEventToken[], handler: EasyBarEventHandler) Subscribes this node to runtime or interaction events.

---@class EasyBarJson
---@field encode fun(value: any): string Encodes one Lua value tree into a JSON string.
---@field decode fun(text: string): any Decodes one JSON string into Lua values.

-- GENERATED SECTION: easybar.themes
-- EasyBar generated theme stub. Do not edit by hand.
-- Source of truth: Sources/EasyBarApp/Theme/theme_tokens.json
-- Regenerate with: scripts/generate_theme_tokens.py
---Resolved active theme colors.
---@class EasyBarThemeColors
---@field background string Main bar and popup background color.
---@field surface string Normal widget or inactive surface color.
---@field surface_elevated string Focused, active, or raised surface color.
---@field surface_hover string Hover or highlighted surface color.
---@field text string Primary text color.
---@field text_secondary string Secondary body or label text color.
---@field text_tertiary string Tertiary text color for quieter labels.
---@field muted string Secondary, inactive, or unavailable text color.
---@field muted_secondary string Secondary muted tone for softer supporting content.
---@field outside_month string Calendar text color for days outside the active month.
---@field accent string Accent color.
---@field accent_secondary string Secondary accent color for supporting highlights.
---@field accent_soft string Softer accent color for subtle emphasis.
---@field success string Positive or healthy status color.
---@field success_secondary string Secondary positive color for supporting signals.
---@field warning string Warning status color.
---@field orange string Orange status color for low or degraded states.
---@field error string Error or critical status color.
---@field danger string Strong danger color for urgent attention.
---@field border string Normal border color.
---@field border_strong string Emphasized border color.
---@field border_subtle string Subtle or transparent border color.
---@field selection_text string Text color drawn on top of selected surfaces.
---@field selection_background string Background color used for selected surfaces.
---@field transparent string Fully transparent color.
---@field overlay_outline string Overlay outline color with alpha.
---@field overlay_text string High-contrast overlay glyph or text color.
---@field today_button_border string Border color used by the calendar today button.

---Theme reference strings accepted by color fields.
---These always mirror the active `EasyBarThemeColors` keys.
---@class EasyBarThemeRefs
---@field background string Reference string for `theme.background`.
---@field surface string Reference string for `theme.surface`.
---@field surface_elevated string Reference string for `theme.surface_elevated`.
---@field surface_hover string Reference string for `theme.surface_hover`.
---@field text string Reference string for `theme.text`.
---@field text_secondary string Reference string for `theme.text_secondary`.
---@field text_tertiary string Reference string for `theme.text_tertiary`.
---@field muted string Reference string for `theme.muted`.
---@field muted_secondary string Reference string for `theme.muted_secondary`.
---@field outside_month string Reference string for `theme.outside_month`.
---@field accent string Reference string for `theme.accent`.
---@field accent_secondary string Reference string for `theme.accent_secondary`.
---@field accent_soft string Reference string for `theme.accent_soft`.
---@field success string Reference string for `theme.success`.
---@field success_secondary string Reference string for `theme.success_secondary`.
---@field warning string Reference string for `theme.warning`.
---@field orange string Reference string for `theme.orange`.
---@field error string Reference string for `theme.error`.
---@field danger string Reference string for `theme.danger`.
---@field border string Reference string for `theme.border`.
---@field border_strong string Reference string for `theme.border_strong`.
---@field border_subtle string Reference string for `theme.border_subtle`.
---@field selection_text string Reference string for `theme.selection_text`.
---@field selection_background string Reference string for `theme.selection_background`.
---@field transparent string Reference string for `theme.transparent`.
---@field overlay_outline string Reference string for `theme.overlay_outline`.
---@field overlay_text string Reference string for `theme.overlay_text`.
---@field today_button_border string Reference string for `theme.today_button_border`.

---Active resolved theme exposed to Lua widgets.
---Use `theme.colors.<token>` for resolved hex colors and `theme.ref.<token>` when you want to keep a node color bound to the active theme.
---@class EasyBarTheme
---@field name string Active theme name from `[theme].name`.
---@field colors EasyBarThemeColors Resolved theme colors.
---@field ref EasyBarThemeRefs Theme reference strings such as `theme.text`.
-- END GENERATED SECTION: easybar.themes

---Widget-scoped EasyBar API injected into every widget file.
---Use it to create nodes, run commands, and write widget logs.
---@class EasyBarCommandOptions
---@field timeout_seconds? number Optional per-command timeout override in seconds.
---@field max_output_bytes? integer Optional per-command combined stdout+stderr capture limit.

---Widget-scoped EasyBar API injected into every widget file.
---Use it to create nodes, run commands, and write widget logs.
---@class EasyBar
---@field version string EasyBar application version (`dev`).
---@field add fun(kind: EasyBarKind, id: string, props?: EasyBarNodeProps): EasyBarNodeHandle Creates one node and returns its handle.
---@field clear_defaults fun() Clears widget-local defaults previously set with `easybar.default(...)`.
---@field default fun(props: EasyBarNodeProps) Sets widget-local default props for future `easybar.add(...)` calls.
---@field events EasyBarEvents Event token namespace used by `node:subscribe(...)`, plus mouse constants.
---@field exec fun(command: string, options?: EasyBarCommandOptions, callback?: fun(output: string, code: integer): any): any Runs one shell command and optionally receives trimmed output and exit code.
---@field exec_async fun(command: string, options: EasyBarCommandOptions|nil, callback: fun(output: string, code: integer): any): string Runs one shell command in the background and calls back later with trimmed output and exit code.
---@field get fun(id: string): EasyBarNodeProps Returns a copy of one node's props by id.
---@field json EasyBarJson JSON helper namespace for widget-side encoding and decoding.
---@field kind EasyBarKinds Kind constants used by `easybar.add(...)`.
---@field level EasyBarLevels Log level namespace used by `easybar.log(...)`.
---@field log fun(level: EasyBarLevel|string, ...: any) Writes one widget-scoped log line to the EasyBar host logger.
---@field remove fun(id: string) Removes one node and all descendants by id.
---@field set fun(id: string, props: EasyBarNodeProps) Merges props into one node by id.
---@field unset fun(id: string, paths: string|string[]) Removes one or more nested property paths from one node by id.
---@field subscribe fun(id: string, events: EasyBarEventToken|EasyBarEventToken[], handler: EasyBarEventHandler) Subscribes one node by id to runtime or interaction events.
---@field theme EasyBarTheme Active resolved theme.
local EasyBar = {}

---@class EasyBarNodeHandle
local EasyBarNodeHandle = {}

---Merges properties into this node.
---@param props EasyBarNodeProps
function EasyBarNodeHandle:set(props) end

---Returns a copy of this node's current property table.
---@return EasyBarNodeProps
function EasyBarNodeHandle:get() end

---Removes this node and all of its descendants.
function EasyBarNodeHandle:remove() end

---Removes one or more nested properties from this node.
---@param paths string|string[]
function EasyBarNodeHandle:unset(paths) end

---Subscribes this node to one or more event tokens.
---Interaction belongs to this node frame.
---@param events EasyBarEventToken|EasyBarEventToken[]
---@param handler EasyBarEventHandler
function EasyBarNodeHandle:subscribe(events, handler) end

---Sets per-widget default properties for future `easybar.add(...)` calls.
---Defaults apply only within the current widget file.
---@param props EasyBarNodeProps
function EasyBar.default(props) end

---Clears previously configured widget defaults.
function EasyBar.clear_defaults() end

---Merges properties into one existing node by id.
---@param id string
---@param props EasyBarNodeProps
function EasyBar.set(id, props) end

---Removes one or more nested properties from one existing node by id.
---@param id string
---@param paths string|string[]
function EasyBar.unset(id, paths) end

---Returns a copy of one existing node's current property table.
---@param id string
---@return EasyBarNodeProps
function EasyBar.get(id) end

---Removes one existing node and all of its descendants by id.
---@param id string
function EasyBar.remove(id) end

---Subscribes one existing node to one or more event tokens by id.
---@param id string
---@param events EasyBarEventToken|EasyBarEventToken[]
---@param handler EasyBarEventHandler
function EasyBar.subscribe(id, events, handler) end

---Creates one EasyBar node and returns its handle.
---Use `easybar.kind.item` for simple widgets, `easybar.kind.group` for shared containers,
---and `easybar.kind.row` / `easybar.kind.column` for layout wrappers around child nodes.
---When `interval` and `on_interval` are provided, EasyBar runs `on_interval`
---on this widget's own repeating schedule without requiring an event subscription.
---@param kind EasyBarKind
---@param id string
---@param props? EasyBarNodeProps
---@return EasyBarNodeHandle
function EasyBar.add(kind, id, props) end

---Runs one shell command.
---When a callback is provided, the trimmed command output and exit code are passed to it.
---@param command string
---@param options? EasyBarCommandOptions
---@param callback? fun(output: string, code: integer): any
---@return any
function EasyBar.exec(command, options, callback) end

---Runs one shell command in the background.
---The callback receives trimmed output and the command exit code when the job finishes.
---@param command string
---@param options EasyBarCommandOptions|nil
---@param callback fun(output: string, code: integer): any
---@return string
function EasyBar.exec_async(command, options, callback) end

---EasyBar application version (`dev`).
---@type string
EasyBar.version = "dev"

---Encodes and decodes JSON values from Lua widgets.
---@type EasyBarJson
EasyBar.json = {}

---All supported EasyBar event tokens and mouse constants.
---@type EasyBarEvents
EasyBar.events = {}

---All supported EasyBar log levels.
---@type EasyBarLevels
EasyBar.level = {}

---All supported EasyBar kind constants.
---@type EasyBarKinds
EasyBar.kind = {}

---Active resolved EasyBar theme.
---@type EasyBarTheme
EasyBar.theme = {}

---Writes one widget-scoped log line to the EasyBar host logger.
---Supported levels are `trace`, `debug`, `info`, `warn`, and `error`.
---Which messages are actually emitted depends on the host logging level.
---@param level EasyBarLevel|string
---@param ... any
function EasyBar.log(level, ...) end

---@type EasyBar
easybar = easybar

return easybar
