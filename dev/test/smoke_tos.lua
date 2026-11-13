-- drives main() with fake peripherals and scripted events
TOS_TEST = true
local dir = (arg[0]:match("^(.*)/test/") or ".")
local files, rs, sent, screen = {}, {}, {}, {}
fs = {exists = function(p) return files[p] ~= nil end,
      open = function(p, m)
        if m == "r" then local d = files[p]; return {readAll = function() return d end, close = function() end} end
        local buf = (m == "a" and files[p]) or ""
        return {write = function(s) buf = buf .. s end, writeLine = function(s) buf = buf .. s .. "\n" end, close = function() files[p] = buf end}
      end}
textutils = {serialise = function(t) local o = {} for k, r in pairs(t) do o[#o+1] = k .. "," .. r.t .. "," .. r.v end return table.concat(o, ";") end,
  unserialise = function(s) local t = {} for k, a, b in s:gmatch("([^,;]+),([^,;]+),([^,;]+)") do t[k] = {t = tonumber(a), v = tonumber(b)} end return t end}
colors = setmetatable({}, {__index = function(_, k) return k end})
redstone = {setOutput = function(side, on) rs[side] = on end}
local players = {}
local mon = {isColor = function() return true end, setTextScale = function() end, getSize = function() return 39, 19 end,
  setBackgroundColor = function() end, setTextColor = function() end, clear = function() screen = {} end,
  setCursorPos = function() end, write = function(s) screen[#screen + 1] = s end}
local pd = {getPlayersInRange = function(r) local o = {} for n, d in pairs(players) do if d <= r then o[#o + 1] = n end end table.sort(o) return o end}
local chat = {sendMessageToPlayer = function(m, n) sent[#sent + 1] = n .. ": " .. m end, sendToastToPlayer = function(m, t, n) sent[#sent + 1] = n .. " toast" end}
peripheral = {find = function(t) return ({monitor = mon, playerDetector = pd, chatBox = chat})[t] end}
local t = 0
os.epoch = function() return t * 1000 end
os.startTimer = function() return 7 end
local script = {}
os.pullEvent = function() local e = table.remove(script, 1); if not e then error("END") end; if e[1] == "timer" then t = t + 1 end return table.unpack(e) end
os.date = os.date
-- keep real loadfile of the file; grab main via a copy that exposes it
local src = io.open(dir .. "/tos.lua"):read("a"):gsub("\nif not TOS_TEST then.*$", "\nreturn main\n")
local main = assert(load(src, "=tos"))()
local function run(events) script = events; local ok, err = pcall(main); assert(not ok and tostring(err):find("END"), err) end

players = {Newbie = 3}
run({{"timer", 7}, {"timer", 7}})
assert(not rs.back, "door closed for unknown player")
assert(sent[1] and sent[1]:find("Newbie: ") , "greeted newcomer")
sent = {}
run({{"timer", 7}, {"chat", "Newbie", "!agree", "u", false}, {"timer", 7}})
assert(rs.back == true, "door opens after !agree")
assert(files["/tos_log.txt"]:find("AGREED Newbie via chat"), "logged")
-- far-away violator escalates to alarm; admin config absent
players = {Newbie = 3, Creeper = 20}
files["/tos_accepted.lua"] = nil
local ev = {}
for i = 1, 60 do ev[#ev + 1] = {"timer", 7} end
run(ev)
assert(rs.left == true, "alarm on for unagreed player inside")
assert(files["/tos_log.txt"]:find("WARNED Creeper"), "warnings logged")
-- monitor touch: single player near agrees on last page, then next/back work
players = {Solo = 2}
sent = {}
local touches = {{"monitor_touch", "m", 20, 18}}   -- AGREE before the last page does nothing
for i = 1, 10 do touches[#touches + 1] = {"monitor_touch", "m", 32, 18} end   -- NEXT until the last page
touches[#touches + 1] = {"monitor_touch", "m", 20, 18}                        -- AGREE
touches[#touches + 1] = {"timer", 7}
files["/tos_log.txt"] = nil
run(touches)
assert(files["/tos_log.txt"]:find("AGREED Solo via monitor"), "monitor agree works on the last page")
players = {A = 1, B = 1}; files["/tos_log.txt"] = nil
run({{"monitor_touch", "m", 32, 18}, {"monitor_touch", "m", 32, 18}, {"monitor_touch", "m", 32, 18}, {"monitor_touch", "m", 32, 18},
     {"monitor_touch", "m", 32, 18}, {"monitor_touch", "m", 32, 18}, {"monitor_touch", "m", 32, 18}, {"monitor_touch", "m", 20, 18}})
assert(not (files["/tos_log.txt"] or ""):find("AGREED"), "two players near: monitor touch refuses")
run({{"playerClick", "A", "d"}, {"playerClick", "A", "d"}})
assert(files["/tos_log.txt"]:find("AGREED A via detector"), "double click on detector agrees")
run({{"chat", "Boss", "!tos revoke a", "u", false}})
assert(sent[#sent]:find("only") or sent[#sent]:find("admins"), "non admin refused")
print("tos smoke ok; log:\n" .. files["/tos_log.txt"]:sub(1, 600))
