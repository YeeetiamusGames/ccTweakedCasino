
-- ================= TEXAS HOLD'EM (you vs the house, "Ultimate" style) =================
-- Ante + Blind (equal). You get 2 hole cards, the dealer gets 2, 5 community cards.
--   preflop: check or raise 4x ante | flop: check or raise 2x | river: raise 1x or fold
-- Dealer qualifies with a pair or better. Win: Play pays 1:1, Ante pays 1:1 only if the dealer qualified.
-- Blind pays only when you win with a straight or better (table below), otherwise it pushes. Tie = push.
GAME.name = "TEXAS HOLD'EM"
-- settings: blindPayScale multiplies the blind bonus table (1 = standard: straight 1:1, flush 3:2, full house 3:1,
-- quads 10:1, straight flush 50:1, royal 500:1). betLimit = max ante (you can be at risk for 6x).
local S = loadSettings("texasHoldem", {blindPayScale = 1.25, betLimit = 1000})
local BET_LIMIT = S.betLimit
local BLIND_SCALE = clamp(S.blindPayScale, 0, 10)

local HAND_NAMES = {"High card", "Pair", "Two pair", "Three of a kind", "Straight", "Flush", "Full house", "Four of a kind", "Straight flush"}

local function rank14(c) return c.r == 1 and 14 or c.r end

-- score of exactly 5 cards: {category, tiebreakers...}  (category 9 = straight flush, 1 = high card)
local function eval5(cards)
    local counts, flush = {}, true
    for _, c in ipairs(cards) do
        local r = rank14(c)
        counts[r] = (counts[r] or 0) + 1
        if c.s ~= cards[1].s then flush = false end
    end
    local g = {}
    for r, n in pairs(counts) do g[#g + 1] = {r = r, n = n} end
    table.sort(g, function(a, b) if a.n ~= b.n then return a.n > b.n end return a.r > b.r end)
    local straightHigh
    if #g == 5 then
        if g[1].r - g[5].r == 4 then
            straightHigh = g[1].r
        elseif g[1].r == 14 and g[2].r == 5 and g[3].r == 4 and g[4].r == 3 and g[5].r == 2 then
            straightHigh = 5   -- the wheel A-2-3-4-5
        end
    end
    if straightHigh and flush then return {9, straightHigh} end
    if g[1].n == 4 then return {8, g[1].r, g[2].r} end
    if g[1].n == 3 and g[2].n == 2 then return {7, g[1].r, g[2].r} end
    if flush then return {6, g[1].r, g[2].r, g[3].r, g[4].r, g[5].r} end
    if straightHigh then return {5, straightHigh} end
    if g[1].n == 3 then return {4, g[1].r, g[2].r, g[3].r} end
    if g[1].n == 2 and g[2].n == 2 then return {3, g[1].r, g[2].r, g[3].r} end
    if g[1].n == 2 then return {2, g[1].r, g[2].r, g[3].r, g[4].r} end
    return {1, g[1].r, g[2].r, g[3].r, g[4].r, g[5].r}
end

-- 1 if a beats b, -1 if b beats a, 0 for a tie
local function compareScores(a, b)
    for i = 1, math.max(#a, #b) do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x > y and 1 or -1 end
    end
    return 0
end

-- best 5 card hand out of 5..7 cards
local function bestHand(cards)
    local best
    local pick = {}
    local function rec(start, n)
        if n == 5 then
            local s = eval5(pick)
            if best == nil or compareScores(s, best) > 0 then best = s end
            return
        end
        for i = start, #cards do
            pick[n + 1] = cards[i]
            rec(i + 1, n + 1)
        end
        pick[n + 1] = nil
    end
    rec(1, 0)
    return best
end

local function handName(score)
    if score[1] == 9 and score[2] == 14 then return "Royal flush" end
    return HAND_NAMES[score[1]]
end

local function blindPay(score, blind, scale)
    local c, units = score[1], 0
    if c == 9 then units = score[2] == 14 and 500 or 50
    elseif c == 8 then units = 10
    elseif c == 7 then units = 3
    elseif c == 6 then units = 1.5
    elseif c == 5 then units = 1 end
    return math.floor(blind * units * (scale or BLIND_SCALE) + 1e-9)
end

-- net chips for the player after a showdown
local function settle(ante, play, pScore, dScore, scale)
    local qualifies = dScore[1] >= 2
    local cmp = compareScores(pScore, dScore)
    if cmp == 0 then return 0, "push", qualifies end
    if cmp > 0 then
        return play + (qualifies and ante or 0) + blindPay(pScore, ante, scale), "win", qualifies
    end
    return -play - ante - (qualifies and ante or 0), "lose", qualifies
end

GAME.eval5, GAME.bestHand, GAME.compare, GAME.settle, GAME.handName = eval5, bestHand, compareScores, settle, handName

local STAGES = {
    {reveal = 0, mult = 4, raise = "RAISE 4x", pass = "CHECK"},
    {reveal = 3, mult = 2, raise = "RAISE 2x", pass = "CHECK"},
    {reveal = 5, mult = 1, raise = "RAISE 1x", pass = "FOLD", last = true},
}

function GAME.round(uid, balance)
    local ante = betScreen(balance, BET_LIMIT, 6, "TEXAS HOLD'EM", "ante + blind - up to 6x at risk")
    if ante == nil then return nil end

    local shoe = newShoe(1)
    local function draw() return table.remove(shoe) end
    local pCards = {draw(), draw()}
    local dCards = {draw(), draw()}
    local board = {draw(), draw(), draw(), draw(), draw()}
    local play = 0
    local oy = math.max(0, math.floor((H - 19) / 2))
    local rightX = W - 21

    local function visible(n)
        local t = {pCards[1], pCards[2]}
        for i = 1, n do t[#t + 1] = board[i] end
        return t
    end

    local function drawTable(shown, showDealer)
        clear(colors.green)
        ctext(oy + 1, "ante " .. num(ante) .. "  blind " .. num(ante) .. "  play " .. num(play), colors.white, colors.green)
        local hiddenD = showDealer and {} or {true, true}
        drawHand(oy + 2, dCards, hiddenD)
        txt(2, oy + 4, "DEALER", colors.white, colors.green)
        local hiddenB = {}
        for i = 1, 5 do hiddenB[i] = i > shown end
        drawHand(oy + 8, board, hiddenB)
        drawCard(2, oy + 14, pCards[1])
        drawCard(9, oy + 14, pCards[2])
        local label = "YOU"
        if shown >= 3 then label = "YOU: " .. handName(bestHand(visible(shown))) end
        txt(2, oy + 13, label, colors.yellow, colors.green)
    end

    local folded = false
    for _, st in ipairs(STAGES) do
        drawTable(st.reveal, false)
        if st.reveal > 0 then snd("block.dispenser.launch", 0.7) end
        local raiseB = button(rightX, oy + 14, 21, 2, st.raise .. " (" .. num(st.mult * ante) .. ")", colors.lime, colors.black)
        local passB = button(rightX, oy + 17, 21, 2, st.pass, st.last and colors.red or colors.gray)
        local choice
        while choice == nil do
            local x, y = getTouchTimeout(60)
            if x == nil then choice = "fold"            -- walking away forfeits ante + blind
            elseif hit(raiseB, x, y) then choice = "raise"
            elseif hit(passB, x, y) then choice = "pass" end
        end
        snd("ui.button.click")
        if choice == "raise" then
            play = st.mult * ante
            break
        elseif choice == "fold" or st.last then
            folded = true
            break
        end
        -- otherwise: check, on to the next street
    end

    local delta, text, color
    if folded then
        drawTable(3, false)
        delta = -2 * ante
        text, color = "folded  " .. num(delta), colors.red
        fill(rightX - 1, oy + 14, W, oy + 18, colors.green)
        txt(rightX, oy + 15, "you folded", colors.white, colors.green)
        txt(rightX, oy + 16, text, color, colors.green)
    else
        drawTable(5, true)
        local pScore, dScore = bestHand(visible(5)), bestHand({dCards[1], dCards[2], board[1], board[2], board[3], board[4], board[5]})
        local outcome, qualifies
        delta, outcome, qualifies = settle(ante, play, pScore, dScore)
        txt(2, oy + 7, "DEALER: " .. handName(dScore) .. (qualifies and "" or " (no qualify)"), colors.white, colors.green)
        txt(2, oy + 13, "YOU: " .. handName(pScore) .. "          ", colors.yellow, colors.green)
        fill(rightX - 1, oy + 14, W, oy + 18, colors.green)
        if outcome == "win" then
            color, text = colors.lime, "YOU WIN +" .. num(delta)
            snd("block.note_block.pling", 1, 2)
        elseif outcome == "push" then
            color, text = colors.yellow, "PUSH"
        else
            color, text = colors.red, "YOU LOSE " .. num(delta)
            snd("entity.villager.no", 0.6)
        end
        txt(rightX, oy + 15, text, color, colors.green)
    end
    pause(6)
    return delta
end
