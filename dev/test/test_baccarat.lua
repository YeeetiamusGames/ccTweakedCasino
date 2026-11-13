dofile((arg[0]:match("^(.*)/") or ".") .. "/mock.lua")
local GAME = loadGame("baccarat.lua", true)
math.randomseed(11)

local function c(r) return {r = r, s = "S"} end
local function scripted(list)   -- draw function over a fixed list; counts how many cards were used
    local i = 0
    return function() i = i + 1; assert(list[i], "drew more cards than scripted"); return list[i] end, function() return i end
end

-- card values
assert(GAME.cardValue(c(1)) == 1 and GAME.cardValue(c(9)) == 9 and GAME.cardValue(c(10)) == 0 and GAME.cardValue(c(13)) == 0)
assert(GAME.total({c(7), c(8)}) == 5 and GAME.total({c(13), c(12)}) == 0 and GAME.total({c(9), c(9), c(9)}) == 7)

-- banker third-card table, written out independently (rows: banker total 0..7, cols: player third card value 0..9, nil = player stood)
local drawsOn = {
    [0] = "YYYYYYYYYY", [1] = "YYYYYYYYYY", [2] = "YYYYYYYYYY",
    [3] = "YYYYYYYYNY",  -- stands only on 8
    [4] = "NNYYYYYYNN",  -- draws on 2-7
    [5] = "NNNNYYYYNN",  -- draws on 4-7
    [6] = "NNNNNNYYNN",  -- draws on 6-7
    [7] = "NNNNNNNNNN",
}
for bt = 0, 7 do
    for v = 0, 9 do
        assert(GAME.bankerDraws(bt, v) == (drawsOn[bt]:sub(v + 1, v + 1) == "Y"), "banker " .. bt .. " vs third " .. v)
    end
    assert(GAME.bankerDraws(bt, nil) == (bt <= 5), "banker vs standing player " .. bt)
end

-- scripted hands: order of draws is P1, B1, P2, B2, [P3], [B3]
local draw, used = scripted({c(4), c(2), c(5), c(3), c(9)})          -- player 9 natural, banker 5: no more cards
local p, b, out = GAME.playHand(draw)
assert(out == "player" and used() == 4 and #p == 2 and #b == 2)

draw, used = scripted({c(3), c(13), c(2), c(3), c(8)})                -- player 5 draws an 8, banker 3 stands vs 8
p, b, out = GAME.playHand(draw)
assert(used() == 5 and #p == 3 and #b == 2 and GAME.total(p) == 3 and GAME.total(b) == 3 and out == "tie")

draw, used = scripted({c(3), c(13), c(2), c(3), c(7), c(5)})          -- same but third card 7: banker draws a 5
p, b, out = GAME.playHand(draw)
assert(used() == 6 and #b == 3 and GAME.total(b) == 8 and out == "banker")

draw, used = scripted({c(13), c(2), c(6), c(3), c(1)})                -- player stands on 6, banker 5 draws
p, b, out = GAME.playHand(draw)
assert(used() == 5 and #p == 2 and #b == 3)

-- payouts (bet 100): banker wins pay 96 (4% default commission), tie bet pays 8:1, player/banker push on tie
assert(GAME.payout("player", "player", 100) == 100 and GAME.payout("player", "banker", 100) == -100)
assert(GAME.payout("banker", "banker", 100) == 96 and GAME.payout("banker", "player", 100) == -100)
assert(GAME.payout("tie", "tie", 100) == 800 and GAME.payout("tie", "player", 100) == -100)
assert(GAME.payout("player", "tie", 100) == 0 and GAME.payout("banker", "tie", 100) == 0)

-- Monte Carlo with an 8 deck shoe
local shoe = {}
local function drawReal()
    if #shoe < 20 then shoe = GAME.newShoe(8) end
    return table.remove(shoe)
end
local N, cnt = 600000, {player = 0, banker = 0, tie = 0}
local ret = {player = 0, banker = 0, tie = 0}
for _ = 1, N do
    local _, _, o = GAME.playHand(drawReal)
    cnt[o] = cnt[o] + 1
    for side in pairs(ret) do ret[side] = ret[side] + GAME.payout(side, o, 1000) / 1000 end
end
local pp, pb, pt = cnt.player / N, cnt.banker / N, cnt.tie / N
print(string.format("baccarat: player %.4f banker %.4f tie %.4f | return per chip: player %.4f banker %.4f tie %.4f",
    pp, pb, pt, 1 + ret.player / N, 1 + ret.banker / N, 1 + ret.tie / N))
assert(math.abs(pp - 0.4462) < 0.004 and math.abs(pb - 0.4586) < 0.004 and math.abs(pt - 0.0952) < 0.003)
assert(math.abs(1 + ret.player / N - 0.9876) < 0.01 and math.abs(1 + ret.banker / N - 0.9941) < 0.01 and math.abs(1 + ret.tie / N - 0.8564) < 0.03)
print("baccarat asserts ok")
