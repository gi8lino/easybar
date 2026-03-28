-- Editor-support example for LuaLS.
-- Copy this file into ~/.config/easybar/widgets/init.lua and open that folder
-- as your editor workspace to get autocomplete and hover docs for `easybar`.
--
-- EasyBar installs a bundled `easybar_api.lua` into ~/.local/share/easybar/
-- at startup. This file loads that shipped stub and stays side-effect free.

local home = os.getenv("HOME") or "~"
local stub = home .. "/.local/share/easybar/easybar_api.lua"
local chunk = loadfile(stub, "t", _ENV)

if chunk then
  return chunk()
end

return easybar
