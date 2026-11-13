dofile((arg[0]:match("^(.*)/") or ".") .. "/mock.lua")
local GAME = loadGame("craps.lua")
math.randomseed(3)

-- come-out table
local function co(side, t) local p, o = GAME.resolve(side, nil, t); return p, o end
for _, t in ipairs({7, 11}) do assert(select(2, co("pass", t)) == "win" and select(2, co("dont", t)) == "lose") end
for _, t in ipairs({2, 3}) do assert(select(2, co("pass", t)) == "lose" and select(2, co("dont", t)) == "win") end
assert(select(2, co("pass", 12)) == "lose" and select(2, co("dont", 12)) == "push")
for _, t in ipairs({4, 5, 6, 8, 9, 10}) do local p, o = co("pass", t); assert(p == t and o == nil) end
-- point phase
assert(select(2, GAME.resolve("pass", 6, 6)) == "win" and select(2, GAME.resolve("pass", 6, 7)) == "lose")
assert(select(2, GAME.resolve("dont", 6, 6)) == "lose" and select(2, GAME.resolve("dont", 6, 7)) == "win")
assert(select(2, GAME.resolve("pass", 6, 11)) == nil and select(2, GAME.resolve("dont", 6, 2)) == nil)

-- true odds payouts
assert(GAME.oddsWin("pass", 4, 60) == 120 and GAME.oddsWin("pass", 10, 60) == 120)
assert(GAME.oddsWin("pass", 5, 60) == 90 and GAME.oddsWin("pass", 9, 60) == 90)
assert(GAME.oddsWin("pass", 6, 60) == 72 and GAME.oddsWin("pass", 8, 60) == 72)
assert(GAME.oddsWin("dont", 4, 60) == 30 and GAME.oddsWin("dont", 5, 60) == 40 and GAME.oddsWin("dont", 6, 60) == 50)

-- exact expected net chips per round, by enumeration
local W = GAME.ways
local function expected(side, bet, odds)
    local e = 0
    for total = 2, 12 do
        local p = W[total] / 36
        local point, outcome = GAME.resolve(side, nil, total)
        if outcome then
            e = e + p * GAME.settle(side, bet, nil, outcome, 0)
        else
            local pMade = W[total] / (W[total] + 6)
            local _, oMade = GAME.resolve(side, point, point)
            local _, oSeven = GAME.resolve(side, point, 7)
            e = e + p * (pMade * GAME.settle(side, bet, point, oMade, odds) + (1 - pMade) * GAME.settle(side, bet, point, oSeven, odds))
        end
    end
    return e
end
local passRet, dontRet = 1 + expected("pass", 60, 0) / 60, 1 + expected("dont", 60, 0) / 60
print(string.format("craps: pass line return %.5f, don't pass return %.5f (no odds)", passRet, dontRet))
assert(math.abs(passRet - (1 - 7 / 495)) < 1e-9, "pass line edge is 1.414%")
assert(math.abs(dontRet - (1 - 27 / 1980)) < 1e-9, "don't pass edge is 1.364%")
-- the odds bet itself must be fair (60 divides evenly by every payout ratio)
for _, side in ipairs({"pass", "dont"}) do
    assert(math.abs(expected(side, 60, 60) - expected(side, 60, 0)) < 1e-9, side .. " odds not fair")
end
-- return per chip risked when always taking 1x odds
for _, side in ipairs({"pass", "dont"}) do
    local e = expected(side, 60, 60)
    -- average amount at risk per round = line bet + odds only when a point was set (27/36 of come-outs... compute exactly)
    local risk = 0
    for total = 2, 12 do
        local p = W[total] / 36
        local point, outcome = GAME.resolve(side, nil, total)
        risk = risk + p * (outcome and 60 or 120)
    end
    print(string.format("  %s with 1x odds: net %.5f per round, %.5f of chips risked", side, e / 60, e / risk))
end

-- Monte Carlo of full rounds through the same functions (always takes odds)
local function simulate(side, rounds)
    local sum = 0
    for _ = 1, rounds do
        local point, outcome, odds = nil, nil, 0
        while outcome == nil do
            if point and odds == 0 then odds = 60 end
            local total = math.random(1, 6) + math.random(1, 6)
            point, outcome = GAME.resolve(side, point, total)
        end
        sum = sum + GAME.settle(side, 60, point, outcome, odds)
    end
    return sum / rounds / 60
end
local mcPass, mcDont = simulate("pass", 600000), simulate("dont", 600000)
print(string.format("  Monte Carlo net per round: pass %.4f (exact %.4f), don't %.4f (exact %.4f)",
    mcPass, expected("pass", 60, 60) / 60, mcDont, expected("dont", 60, 60) / 60))
assert(math.abs(mcPass - expected("pass", 60, 60) / 60) < 0.01 and math.abs(mcDont - expected("dont", 60, 60) / 60) < 0.01)
print("craps asserts ok")
