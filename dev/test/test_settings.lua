dofile((arg[0]:match("^(.*)/") or ".") .. "/mock.lua")
local dir = (arg[0]:match("^(.*)/test/") or ".")
local realDofile, realPrint = dofile, print
local games = {slots = "slots.lua", plinko = "plinko.lua", villagerRaces = "villagerRaces.lua", baccarat = "baccarat.lua", craps = "craps.lua", texasHoldem = "texasHoldem.lua"}
local cards = {texasHoldem = true, baccarat = true}

local function withSettings(tbl, fn)
    local printed = {}
    fs.exists = function(p) return p == "/casinoSettings.lua" end
    dofile = function(p) assert(p == "/casinoSettings.lua"); if type(tbl) == "string" then return realDofile(tbl) end return tbl end
    print = function(s) printed[#printed + 1] = s end
    local ok, err = pcall(fn, printed)
    fs.exists, dofile, print = function() return false end, realDofile, realPrint
    assert(ok, err)
    return printed
end

-- 1. the shipped file loads and every game runs on it without a single warning
local file = dir .. "/casinoSettings.lua"
assert(loadfile(file), "casinoSettings.lua must parse")
for key, f in pairs(games) do
    local printed = withSettings(file, function() loadGame(f, cards[key]) end)
    assert(#printed == 0, key .. " warned: " .. tostring(printed[1]))
end

-- 2. custom values actually change the games
local custom = {slots = {rtp = 0.90, hitFrequency = 0.25, pushFrequency = 0.05},
                plinko = {rtp = 0.95, hitFrequency = 0.50},
                baccarat = {bankerCommission = 0, tiePays = 9},
                texasHoldem = {blindPayScale = 2}}
withSettings(custom, function()
    local g = loadGame("slots.lua")
    assert(math.abs(g.TABLE.hit - 0.25) < 1e-9 and math.abs(g.TABLE.rtp - 0.90) < 1e-9 and math.abs(g.TABLE.push - 0.05) < 1e-9)
    g = loadGame("plinko.lua")
    assert(math.abs(g.PLANS.low.hit - 0.50) < 1e-9 and math.abs(g.PLANS.high.rtp - 0.95) < 0.006)
    g = loadGame("baccarat.lua", true)
    assert(g.payout("banker", "banker", 100) == 100 and g.payout("tie", "tie", 100) == 900)
    g = loadGame("texasHoldem.lua", true)
    local function hand(s) local o = {} for tok in s:gmatch("%S+") do local m = {A = 1, J = 11, Q = 12, K = 13}; o[#o + 1] = {r = m[tok:sub(1, -2)] or tonumber(tok:sub(1, -2)), s = tok:sub(-1)} end return o end
    local flush, pair = g.bestHand(hand("2C 9C JC 4C 7C")), g.bestHand(hand("KC KD 3H 4S 9D"))
    assert(g.settle(10, 40, flush, pair) == 40 + 10 + 30)   -- blind 10 x 1.5 x scale 2
end)

-- 3. bad values warn and fall back instead of breaking
local printed = withSettings({villagerRaces = {weights = {1, 2, 3}}, slots = {hitFrequency = 0.9}}, function()
    local g = loadGame("villagerRaces.lua")
    loadGame("slots.lua")
end)
assert(#printed >= 2, "expected warnings for the bad weights and the impossible hit frequency")
print("settings asserts ok (" .. #printed .. " warnings seen for bad values)")
