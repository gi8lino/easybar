-- network.lua
-- Shows current WiFi network

local handle = io.popen(
	"/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I | awk '/ SSID/ {print $2}'"
)
local ssid = handle:read("*a")
handle:close()

ssid = ssid:gsub("\n", "")

if ssid == "" then
	ssid = "offline"
end

print(string.format('{"text":"📶 %s"}', ssid))
