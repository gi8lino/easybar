-- EasyBar Lua API stub version: __EASYBAR_VERSION__
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
-- GENERATED SECTION: easybar.events

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
-- Regenerate with: scripts/generate/artifacts.py theme-tokens
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

---Options for `easybar.log.with_file(...)`.
---@class EasyBarLogFileOptions
---@field prefix? string Optional prefix added to host log lines and file-backed logger lines.

---Callable widget logger returned by `easybar.log.with_prefix(...)`.
---@class EasyBarPrefixedLogger
---@operator call(EasyBarLevel|string, ...: any)

---File-backed widget logger returned by `easybar.log.with_file(...)`.
---@class EasyBarFileLogger
---@operator call(EasyBarLevel|string, ...: any): boolean, string?
---@field append fun(text: any): boolean, string? Appends raw text to the widget log file and adds a trailing newline when missing.
---@field line fun(text: any): boolean, string? Appends one line to the widget log file.
---@field tail fun(limit: integer): string Returns the newest log lines as one newline-delimited string.
---@field trim fun(limit: integer): boolean, string? Keeps only the newest log lines in the widget log file.

---Callable widget logger exposed as `easybar.log`.
---@class EasyBarLogFunction
---@operator call(EasyBarLevel|string, ...: any)
---@field with_prefix fun(prefix: string): EasyBarPrefixedLogger Creates a widget logger that prepends a stable prefix to normal EasyBar host logs.
---@field with_file fun(file_name: string, options?: EasyBarLogFileOptions): EasyBarFileLogger Creates a widget logger that writes normal EasyBar logs and appends to a file in `easybar.log_dir`.

---Widget-scoped EasyBar API injected into every widget file.
---Use it to create nodes, run commands, and write widget logs.
---@class EasyBar
---@field DEFAULT_EXEC_OPTIONS EasyBarCommandOptions Read-only table exposing the current host default command limits.
---@field version string EasyBar application version (`__EASYBAR_VERSION__`).
---@field add fun(kind: EasyBarKind, id: string, props?: EasyBarNodeProps): EasyBarNodeHandle Creates one node and returns its handle.
---@field clear_defaults fun() Clears widget-local defaults previously set with `easybar.default(...)`.
---@field default fun(props: EasyBarNodeProps) Sets widget-local default props for future `easybar.add(...)` calls.
---@field events EasyBarEvents Event token namespace used by `node:subscribe(...)`, plus mouse constants.
---@field exec fun(command: string, options?: EasyBarCommandOptions): string, integer Runs one shell command and returns trimmed output plus exit code.
---@field exec_async fun(command: string, options: EasyBarCommandOptions|nil, callback: fun(output: string, code: integer): any): string Runs one shell command in the background and calls back later with trimmed output and exit code.
---@field get fun(id: string): EasyBarNodeProps Returns a copy of one node's props by id.
---@field json EasyBarJson JSON helper namespace for widget-side encoding and decoding.
---@field kind EasyBarKinds Kind constants used by `easybar.add(...)`.
---@field level EasyBarLevels Log level namespace used by `easybar.log(...)`.
---@field log EasyBarLogFunction Callable widget logger. Use `easybar.log(level, ...)` for host logs, `easybar.log.with_prefix(...)` for prefixed host logs, or `easybar.log.with_file(...)` for file-backed widget logs.
---@field log_dir string Configured EasyBar logging directory from `[logging].directory`.
---@field remove fun(id: string) Removes one node and all descendants by id.
---@field set fun(id: string, props: EasyBarNodeProps) Merges props into one node by id.
---@field unset fun(id: string, paths: string|string[]) Removes one or more nested property paths from one node by id.
---@field subscribe fun(id: string, events: EasyBarEventToken|EasyBarEventToken[], handler: EasyBarEventHandler) Subscribes one node by id to runtime or interaction events.
---@field theme EasyBarTheme Active resolved theme.
local EasyBar = {}

---@class EasyBarFileLogger
local EasyBarFileLogger = {}

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
---Returns trimmed command output and exit code.
---@param command string
---@param options? EasyBarCommandOptions
---@return string
---@return integer
function EasyBar.exec(command, options) end

---Runs one shell command in the background.
---The callback receives trimmed output and the command exit code when the job finishes.
---@param command string
---@param options EasyBarCommandOptions|nil
---@param callback fun(output: string, code: integer): any
---@return string
function EasyBar.exec_async(command, options, callback) end

---EasyBar application version (`__EASYBAR_VERSION__`).
---@type string
EasyBar.version = "__EASYBAR_VERSION__"

---Read-only table exposing the current host default command limits.
---@type EasyBarCommandOptions
EasyBar.DEFAULT_EXEC_OPTIONS = {}

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

---Configured EasyBar logging directory from `[logging].directory`.
---@type string
EasyBar.log_dir = ""

---Active resolved EasyBar theme.
---@type EasyBarTheme
EasyBar.theme = {}

---Writes one widget-scoped log line to the EasyBar host logger.
---Supported levels are `trace`, `debug`, `info`, `warn`, and `error`.
---Which messages are actually emitted depends on the host logging level.
---@param level EasyBarLevel|string
---@param ... any
function EasyBar.log(level, ...) end

---Creates a widget logger that prepends a stable prefix to normal EasyBar host logs.
---@param prefix string
---@return EasyBarPrefixedLogger
function EasyBar.log.with_prefix(prefix) end

---Creates a widget logger that writes normal EasyBar logs and appends to a file in `easybar.log_dir`.
---The file name must be a plain file name, not a path.
---@param file_name string
---@param options? EasyBarLogFileOptions
---@return EasyBarFileLogger
function EasyBar.log.with_file(file_name, options) end

---Appends raw text to the widget log file and adds a trailing newline when missing.
---@param text any
---@return boolean
---@return string?
function EasyBarFileLogger.append(text) end

---Appends one line to the widget log file.
---@param text any
---@return boolean
---@return string?
function EasyBarFileLogger.line(text) end

---Returns the newest log lines as one newline-delimited string.
---@param limit integer
---@return string
function EasyBarFileLogger.tail(limit) end

---Keeps only the newest log lines in the widget log file.
---@param limit integer
---@return boolean
---@return string?
function EasyBarFileLogger.trim(limit) end

---@type EasyBar
easybar = easybar

return easybar
