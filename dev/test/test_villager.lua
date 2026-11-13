dofile((arg[0]:match("^(.*)/") or ".") .. "/mock.lua")
local GAME = loadGame("villagerRaces.lua")
math.randomseed(7)
local ws = {30, 24, 18, 14, 9, 5}
local win, top3 = GAME.placeProbs(ws)
local sw, s3 = 0, 0
for i = 1, 6 do sw = sw + win[i]; s3 = s3 + top3[i] end
assert(math.abs(sw - 1) < 1e-9 and math.abs(s3 - 3) < 1e-9, "probabilities must sum to 1 and 3")

-- Monte Carlo: the draw order must follow the stated probabilities
local N = 300000
local winCount, topCount = {0, 0, 0, 0, 0, 0}, {0, 0, 0, 0, 0, 0}
for _ = 1, N do
    local o = GAME.drawOrder(ws)
    assert(#o == 6)
    winCount[o[1]] = winCount[o[1]] + 1
    for k = 1, 3 do topCount[o[k]] = topCount[o[k]] + 1 end
end
for i = 1, 6 do
    assert(math.abs(winCount[i] / N - win[i]) < 0.006, "win freq off for " .. i)
    assert(math.abs(topCount[i] / N - top3[i]) < 0.006, "top3 freq off for " .. i)
end

-- return per chip for every racer and bet type (exact, including the round-down to 0.01x and a bet of 1000)
local lo, hi = 9, 0
for i = 1, 6 do
    for _, kind in ipairs({"win", "place"}) do
        local p = kind == "win" and win[i] or top3[i]
        local mt = GAME.multCents(p)
        local bet = 1000
        local ret = p * math.floor(bet * mt / 100) / bet
        lo, hi = math.min(lo, ret), math.max(hi, ret)
    end
end
print(string.format("villager races: win-chance %.0f%%..%.0f%%, return per chip %.4f..%.4f", win[6] * 100, win[1] * 100, lo, hi))
assert(lo > 0.93 and hi < 1.0)
print("villager asserts ok")
