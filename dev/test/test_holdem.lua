dofile((arg[0]:match("^(.*)/") or ".") .. "/mock.lua")
local GAME = loadGame("texasHoldem.lua", true)

local function hand(s) -- "AS KS QS JS 10S" style
    local out = {}
    for tok in s:gmatch("%S+") do
        local suit = tok:sub(-1)
        local rk = tok:sub(1, -2)
        local map = {A = 1, J = 11, Q = 12, K = 13}
        out[#out + 1] = {r = map[rk] or tonumber(rk), s = suit}
    end
    return out
end
local function cat(s) return GAME.bestHand(hand(s))[1] end
local function name(s) return GAME.handName(GAME.bestHand(hand(s))) end

assert(name("AS KS QS JS 10S") == "Royal flush")
assert(name("9H 8H 7H 6H 5H") == "Straight flush")
assert(name("AH 2H 3H 4H 5H") == "Straight flush")          -- steel wheel
assert(name("KC KD KH KS 2C") == "Four of a kind")
assert(name("KC KD KH 2S 2C") == "Full house")
assert(name("2C 9C JC 4C 7C") == "Flush")
assert(name("AH 2D 3C 4S 5H") == "Straight")                -- wheel
assert(name("10H JD QC KS AH") == "Straight")               -- broadway
assert(name("QH KD AC 2S 3H") == "High card")               -- no wrap-around straight
assert(name("KC KD KH 2S 3C") == "Three of a kind")
assert(name("KC KD 3H 3S 9C") == "Two pair")
assert(name("KC KD 3H 4S 9C") == "Pair")
-- 7 card selection
assert(name("AS KS QS JS 10S 2D 2C") == "Royal flush")
assert(name("2S 2D 2C 9H 9D 9C 9S") == "Four of a kind")    -- quads beat full house
assert(name("2S 2D 2C 3H 3D 5C 5S") == "Full house")        -- trips + best pair
assert(name("AH KH 2H 3H 4H 5C 9D") == "Flush" or name("AH KH 2H 3H 4H 5C 9D") == "Straight flush")

-- comparisons
local function cmp(a, b) return GAME.compare(GAME.bestHand(hand(a)), GAME.bestHand(hand(b))) end
assert(cmp("AH 2D 3C 4S 5H", "2H 3D 4C 5S 6H") == -1)       -- wheel loses to 6-high straight
assert(cmp("KC KD 3H 4S 9C", "KH KS 3D 4C 8C") == 1)        -- kicker
assert(cmp("AC KD 3H 4S 9C", "AH KS 3D 4C 9S") == 0)        -- identical ranks tie
assert(cmp("2C 9C JC 4C 7C", "KC KD KH KS 2D") == -1)       -- quads > flush
assert(cmp("KC KD 3H 3S 9C", "QH QS JD JC AH") == 1)

-- settlement (ante 10, play 40)
local S = function(a, p, x, y) return GAME.settle(a, p, x, y, 1) end   -- standard blind table
local function sc(s) return GAME.bestHand(hand(s)) end
local pFlush, dPair = sc("2C 9C JC 4C 7C"), sc("KC KD 3H 4S 9D")
assert(S(10, 40, pFlush, dPair) == 40 + 10 + 15)            -- play + ante + blind 3:2
local pHigh, dNoQ = sc("AC KD 3H 4S 9C"), sc("QC 2D 3H 4S 8C")
assert(S(10, 40, pHigh, dNoQ) == 40)                        -- dealer doesn't qualify: ante pushes, blind pushes
local lose = S(10, 40, sc("2C 4D 9H JS KC"), dPair)
assert(lose == -40 - 10 - 10)                               -- play + blind + ante
local loseNQ = S(10, 40, sc("2C 4D 9H JS KC"), sc("AC 2D 7H 8S 10C"))
assert(loseNQ == -40 - 10)                                  -- dealer didn't qualify so ante pushes
assert(S(10, 40, sc("AC KD 3H 4S 9C"), sc("AH KS 3D 4C 9S")) == 0)
assert(S(10, 40, sc("AS KS QS JS 10S"), dPair) == 40 + 10 + 5000)

-- simulate "always raise 4x preflop" for a sanity check of the whole pipeline
math.randomseed(42)
local newShoe = (function() -- reuse the game's shoe code
    local SUITS = {"S", "H", "D", "C"}
    return function()
        local shoe = {}
        for _, s in ipairs(SUITS) do for r = 1, 13 do shoe[#shoe + 1] = {r = r, s = s} end end
        for i = #shoe, 2, -1 do local j = math.random(1, i); shoe[i], shoe[j] = shoe[j], shoe[i] end
        return shoe
    end
end)()
local N, total = 200000, 0
for _ = 1, N do
    local sh = newShoe()
    local function d() return table.remove(sh) end
    local p, dl, b = {d(), d()}, {d(), d()}, {d(), d(), d(), d(), d()}
    local P = {p[1], p[2], b[1], b[2], b[3], b[4], b[5]}
    local D = {dl[1], dl[2], b[1], b[2], b[3], b[4], b[5]}
    total = total + S(1, 4, GAME.bestHand(P), GAME.bestHand(D))
end
print(string.format("always-raise-4x: average result %.4f per 1 ante over %d hands (total at risk is 6 per hand)", total / N, N))
print("holdem asserts ok")
