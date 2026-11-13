-- estimate of the return for a decent (not perfect) player at different blindPayScale values
dofile((arg[0]:match("^(.*)/") or ".") .. "/mock.lua")
local GAME = loadGame("texasHoldem.lua", true)
math.randomseed(tonumber(arg[2]) or 21)
local N = tonumber(arg[1]) or 20000
local scales = {1, 1.5, 2, 3}

local function r14(c) return c.r == 1 and 14 or c.r end
local function newShoe()
    local shoe = {}
    for _, s in ipairs({"S", "H", "D", "C"}) do for r = 1, 13 do shoe[#shoe + 1] = {r = r, s = s} end end
    for i = #shoe, 2, -1 do local j = math.random(1, i); shoe[i], shoe[j] = shoe[j], shoe[i] end
    return shoe
end
local function preflopRaise(h1, h2)
    local a, b = r14(h1), r14(h2)
    local hi, lo, suited = math.max(a, b), math.min(a, b), h1.s == h2.s
    if a == b or hi == 14 then return true end
    if hi == 13 and (suited or lo >= 10) then return true end
    if hi == 12 and suited and lo >= 10 then return true end
    return false
end
local function flopRaise(h, board3)
    local cards = {h[1], h[2], board3[1], board3[2], board3[3]}
    local sc = GAME.bestHand(cards)
    if sc[1] >= 3 then return true end
    if sc[1] == 2 and (sc[2] == r14(h[1]) or sc[2] == r14(h[2])) then return true end
    for _, suit in ipairs({"S", "H", "D", "C"}) do
        local n = 0
        for _, c in ipairs(cards) do if c.s == suit then n = n + 1 end end
        if n >= 4 and (h[1].s == suit or h[2].s == suit) then return true end
    end
    return false
end
local function riverRaise(h, score)
    if score[1] >= 3 then return true end
    return score[1] == 2 and (score[2] == r14(h[1]) or score[2] == r14(h[2]))
end

local wagered = 0
local tot, blindOnly, raises = {}, {}, {pre = 0, flop = 0, river = 0, fold = 0}
for _, s in ipairs(scales) do tot[s] = 0 end
local t0 = os.clock()
for _ = 1, N do
    local sh = newShoe()
    local function d() return table.remove(sh) end
    local h, dl, b = {d(), d()}, {d(), d()}, {d(), d(), d(), d(), d()}
    local mult
    if preflopRaise(h[1], h[2]) then mult = 4; raises.pre = raises.pre + 1
    elseif flopRaise(h, {b[1], b[2], b[3]}) then mult = 2; raises.flop = raises.flop + 1
    else
        local ps = GAME.bestHand({h[1], h[2], b[1], b[2], b[3], b[4], b[5]})
        if riverRaise(h, ps) then mult = 1; raises.river = raises.river + 1 end
    end
    wagered = wagered + 2 + (mult or 0)
    if mult == nil then
        raises.fold = raises.fold + 1
        for _, s in ipairs(scales) do tot[s] = tot[s] - 2 end
    else
        local ps = GAME.bestHand({h[1], h[2], b[1], b[2], b[3], b[4], b[5]})
        local ds = GAME.bestHand({dl[1], dl[2], b[1], b[2], b[3], b[4], b[5]})
        for _, s in ipairs(scales) do tot[s] = tot[s] + GAME.settle(100, 100 * mult, ps, ds, s) / 100 end
    end
end
print(string.format("%d hands in %.0fs | preflop raise %.0f%%, flop %.0f%%, river %.0f%%, fold %.0f%%", N, os.clock() - t0,
    raises.pre / N * 100, raises.flop / N * 100, raises.river / N * 100, raises.fold / N * 100))
for _, s in ipairs(scales) do
    print(string.format("blindPayScale %.1f: net %+.4f per ante | return per chip wagered %.1f%%", s, tot[s] / N, (1 + tot[s] / wagered) * 100))
end
