-- StorageHunter_Loader.lua
-- Put BOTH files in your Delta workspace folder, then execute this file.
-- It reads StorageHunter.lua from disk and runs it (no copy-pasting needed).
local ok, src = pcall(readfile, "StorageHunter.lua")
if not ok or type(src) ~= "string" then
	warn("StorageHunter.lua not found in the Delta workspace folder")
	return
end
local fn, err = loadstring(src)
if not fn then
	warn("StorageHunter.lua compile error: " .. tostring(err))
	return
end
fn()
