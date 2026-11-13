-- minimal ComputerCraft mock so the pure game logic can be loaded and tested with plain Lua
local noop = function() end
colors = setmetatable({}, {__index = function(t, k) return k end})
peripheral = {find = function() return nil end}
term = setmetatable({}, {__index = function() return noop end})
fs = {combine = function(a, b) return a .. "/" .. b end, exists = function() return false end}
os.pullEvent = function() error("pullEvent not mocked") end
os.startTimer = function() return 1 end
os.getComputerID = function() return 1 end
parallel = {waitForAny = noop}
textutils = {serialiseJSON = function() return "{}" end}
sleep = noop
disk = {}

-- loads common + optional cards + game (without the footer) and returns the GAME table
function loadGame(gameFile, withCards)
    local function slurp(p) local f = assert(io.open(p, "rb")); local s = f:read("a"); f:close(); return s end
    local dir = (arg and arg[0] or ""):match("^(.*)/test/") or "."
    local src = slurp(dir .. "/common.lua")
    if withCards then src = src .. "\n" .. slurp(dir .. "/cards.lua") end
    src = src .. "\n" .. slurp(dir .. "/games/" .. gameFile) .. "\nreturn GAME\n"
    return assert(load(src, "=" .. gameFile))()
end
