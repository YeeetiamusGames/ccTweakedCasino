-- ================= shared casino code (same protocol as the blackjack/roulette machines) =================
-- Needs: monitor (min 4 wide x 3 tall), modem on the casino network, disk drive. Speaker is optional.
local GAME = {name = "game", scale = 1, minW = 39, minH = 19, blocks = "4 x 3"}

local monitor = peripheral.find("monitor")
local speaker = peripheral.find("speaker")
local casinoNetwerk = peripheral.find("modem")
local drive = peripheral.find("drive")

local W, H = 0, 0
local userId = nil

---------------------------------------------------------------- small helpers
local function num(n) return string.format("%d", math.floor((tonumber(n) or 0) + 0.5)) end

local function snd(name, vol, pitch)
    if speaker then pcall(speaker.playSound, name, vol or 1, pitch or 1) end
end

local function clear(bg)
    term.setBackgroundColor(bg or colors.black)
    term.clear()
    term.setCursorPos(1, 1)
end

local function fill(x1, y1, x2, y2, bg)
    term.setBackgroundColor(bg)
    local row = string.rep(" ", math.max(0, x2 - x1 + 1))
    for y = y1, y2 do
        term.setCursorPos(x1, y)
        term.write(row)
    end
end

local function txt(x, y, s, fg, bg)
    if bg then term.setBackgroundColor(bg) end
    if fg then term.setTextColor(fg) end
    term.setCursorPos(x, y)
    term.write(s)
end

local function ctext(y, s, fg, bg)
    txt(math.floor((W - #s) / 2) + 1, y, s, fg, bg)
end

-- a button is just a table; draw it once, test touches with hit()
local function button(x, y, w, h, label, bg, fg)
    fill(x, y, x + w - 1, y + h - 1, bg)
    txt(x + math.floor((w - #label) / 2), y + math.floor((h - 1) / 2), label, fg or colors.white, bg)
    return {x = x, y = y, w = w, h = h, label = label}
end

local function hit(b, x, y)
    return b ~= nil and x ~= nil and x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h
end

---------------------------------------------------------------- card in the drive
local function cardFile()
    local mp = drive.getMountPath()
    if mp then return fs.combine(mp, "id") end
    return nil
end

local function cardPresent()
    local f = cardFile()
    return f ~= nil and fs.exists(f)
end

local function readCard()
    local f = cardFile()
    if f and fs.exists(f) then
        local h = fs.open(f, "r")
        local id = h.readAll()
        h.close()
        return id
    end
    return nil
end

-- waits for a touch on the monitor. If checkCard is true it returns nil when the card is removed.
local function getTouch(checkCard)
    local t = os.startTimer(0.5)
    while true do
        local e, a, b, c = os.pullEvent()
        if e == "monitor_touch" then
            return b, c
        elseif e == "timer" and a == t then
            if checkCard and not cardPresent() then return nil end
            t = os.startTimer(0.5)
        end
    end
end

-- sleeps but keeps swallowing nothing; used for animations
local function wait(s) sleep(s) end

---------------------------------------------------------------- network (talks to the central computer on channel 1)
local function request(command, uid, attributes)
    local myId = os.getComputerID()
    local payload = textutils.serialiseJSON({command = command, userId = uid, attributes = attributes})
    local function sender()
        while true do
            casinoNetwerk.transmit(1, myId, payload)
            sleep(0.5)
        end
    end
    local function firstAck()
        repeat
            local _, _, ch = os.pullEvent("modem_message")
        until ch == myId
    end
    parallel.waitForAny(sender, firstAck)
    local msg
    repeat
        local _, _, ch, _, m = os.pullEvent("modem_message")
        msg = m
        local chan = ch
    until chan == myId
    return msg
end

local function getBalance(uid)
    return tonumber(request("getBal", uid, nil)) or 0
end

local function updateLabel(uid)
    local b = getBalance(uid)
    pcall(drive.setDiskLabel, num(b) .. " chips")
    return b
end

local function changeBalance(amount, uid)
    request("changeBal", uid, amount)
    return updateLabel(uid)
end

---------------------------------------------------------------- bet screen
-- Returns the chosen bet, or nil if the card was removed.
-- exposure = how many times the bet can be lost in one round (so the player can always pay).
local function betScreen(balance, limit, exposure, title, subtitle)
    exposure = exposure or 1
    local maxBet = math.min(limit or 100000, math.floor(balance / exposure))
    if maxBet < 1 then return 0 end
    local bet = math.max(1, math.min(maxBet, math.ceil(maxBet / 2)))

    clear(colors.black)
    ctext(1, title or GAME.name, colors.yellow, colors.black)
    if subtitle then ctext(2, subtitle, colors.lightGray, colors.black) end
    ctext(4, "Balance: " .. num(balance) .. " chips", colors.white, colors.black)

    local bx = math.floor((W - 35) / 2) + 1
    local steps = {{"-100", -100}, {"-10", -10}, {"-1", -1}, {"+1", 1}, {"+10", 10}, {"+100", 100}}
    local btns = {}
    for i, s in ipairs(steps) do
        local col = s[2] < 0 and colors.red or colors.green
        btns[i] = button(bx + (i - 1) * 6, 10, 5, 2, s[1], col)
    end
    local cx = math.floor((W - 31) / 2) + 1
    local minB = button(cx, 14, 8, 3, "MIN", colors.gray)
    local goB = button(cx + 9, 14, 13, 3, "BET", colors.lime, colors.black)
    local maxB = button(cx + 23, 14, 8, 3, "MAX", colors.gray)
    txt(1, H, string.rep(" ", W), nil, colors.black)
    ctext(H, "take your card to leave", colors.gray, colors.black)

    while true do
        fill(1, 6, W, 8, colors.black)
        local label = num(bet) .. " chips"
        local bw = math.max(#label + 4, 17)
        fill(math.floor((W - bw) / 2) + 1, 6, math.floor((W - bw) / 2) + bw, 8, colors.gray)
        ctext(7, label, colors.white, colors.gray)
        if maxBet < (limit or 100000) then
            ctext(9, "max " .. num(maxBet), colors.lightGray, colors.black)
        else
            ctext(9, "table limit " .. num(maxBet), colors.lightGray, colors.black)
        end

        local x, y = getTouch(true)
        if x == nil then return nil end
        for i, s in ipairs(steps) do
            if hit(btns[i], x, y) then bet = bet + s[2]; snd("ui.button.click") end
        end
        if hit(minB, x, y) then bet = 1; snd("ui.button.click") end
        if hit(maxB, x, y) then bet = maxBet; snd("ui.button.click") end
        if hit(goB, x, y) then snd("ui.button.click"); return bet end
        if bet < 1 then bet = 1 end
        if bet > maxBet then bet = maxBet end
    end
end

-- a small result banner at the bottom, then waits a moment (or a touch) before the next round
local function banner(text, fg, bg, seconds)
    local y = H - 2
    fill(1, y, W, y + 1, bg or colors.black)
    ctext(y, text, fg or colors.white, bg or colors.black)
    local timer = os.startTimer(seconds or 4)
    while true do
        local e, a = os.pullEvent()
        if e == "monitor_touch" then return end
        if e == "timer" and a == timer then return end
    end
end

-- waits for a touch for at most `seconds`; returns x,y or nil on timeout (used so an abandoned hand can't block the machine)
local function getTouchTimeout(seconds)
    local t = os.startTimer(seconds)
    while true do
        local e, a, b, c = os.pullEvent()
        if e == "monitor_touch" then return b, c end
        if e == "timer" and a == t then return nil end
    end
end

-- waits a few seconds or until the monitor is touched
local function pause(seconds)
    getTouchTimeout(seconds or 4)
end

-- ---------- settings: every game reads its own section of /casinoSettings.lua (all keys optional)
local function loadSettings(key, defaults)
    local s = {}
    for k, v in pairs(defaults) do s[k] = v end
    if fs.exists("/casinoSettings.lua") then
        local ok, all = pcall(dofile, "/casinoSettings.lua")
        if ok and type(all) == "table" and type(all[key]) == "table" then
            for k, v in pairs(all[key]) do s[k] = v end
        elseif not ok then
            print("[settings] casinoSettings.lua has an error: " .. tostring(all))
        end
    end
    return s
end

local function warn(msg) print("[settings] " .. msg) end
local function clamp(v, lo, hi) return math.max(lo, math.min(hi, tonumber(v) or lo)) end
-- ================= cards (used by the card games) =================
-- a card is {r = 1..13, s = "S"|"H"|"D"|"C"}; 1 = ace, 11/12/13 = jack/queen/king
local SUITS = {"S", "H", "D", "C"}
local RANK_NAMES = {"A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"}

local function newShoe(decks)
    local shoe = {}
    for _ = 1, decks or 1 do
        for _, s in ipairs(SUITS) do
            for r = 1, 13 do shoe[#shoe + 1] = {r = r, s = s} end
        end
    end
    for i = #shoe, 2, -1 do   -- fisher-yates shuffle
        local j = math.random(1, i)
        shoe[i], shoe[j] = shoe[j], shoe[i]
    end
    return shoe
end

local function isRed(card) return card.s == "H" or card.s == "D" end

-- draws a 6x5 card with its top left corner at x,y
local function drawCard(x, y, card, faceDown)
    if faceDown or card == nil then
        fill(x, y, x + 5, y + 4, colors.blue)
        for i = 0, 4 do txt(x + 1 + (i % 2), y + i, "# # ", colors.lightBlue, colors.blue) end
        return
    end
    local fg = isRed(card) and colors.red or colors.black
    fill(x, y, x + 5, y + 4, colors.white)
    local name = RANK_NAMES[card.r]
    txt(x + 1, y, name, fg, colors.white)
    txt(x + 2, y + 2, card.s, fg, colors.white)
    txt(x + 5 - #name, y + 4, name, fg, colors.white)
end

-- draws a row of cards centered on the monitor; hidden[i] = true shows card i face down
local function drawHand(y, hand, hidden, gap)
    gap = gap or 1
    local total = #hand * 6 + (#hand - 1) * gap
    local x = math.floor((W - total) / 2) + 1
    for i, c in ipairs(hand) do
        drawCard(x + (i - 1) * (6 + gap), y, c, hidden and hidden[i])
    end
end

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

-- ================= main loop (shared) =================
local function idleScreen()
    local blink = true
    while true do
        if cardPresent() then
            local id = readCard()
            if id and id ~= "" then
                userId = id
                return
            end
        end
        clear(colors.green)
        ctext(math.floor(H / 2) - 2, GAME.name, colors.yellow, colors.green)
        ctext(math.floor(H / 2), "casino fortuna", colors.white, colors.green)
        if GAME.idle then GAME.idle(blink) end
        ctext(H - 2, blink and "insert your casino card" or "                       ", colors.black, colors.green)
        blink = not blink
        local timer = os.startTimer(1.5)
        while true do
            local e, a = os.pullEvent()
            if e == "timer" and a == timer then break end
            if cardPresent() then
                local id = readCard()
                if id and id ~= "" then
                    userId = id
                    return
                end
            end
            if e == "disk" then break end
        end
    end
end

local function notEnough()
    clear(colors.black)
    ctext(math.floor(H / 2), "not enough chips", colors.yellow, colors.black)
    ctext(math.floor(H / 2) + 2, "take your card to leave", colors.gray, colors.black)
    while cardPresent() do sleep(0.5) end
end

local function main()
    assert(monitor ~= nil, "no monitor connected =[")
    assert(casinoNetwerk ~= nil, "no modem connected =[")
    assert(drive ~= nil, "no disk drive connected =[")
    casinoNetwerk.open(os.getComputerID())
    monitor.setTextScale(GAME.scale)
    term.redirect(monitor)
    W, H = term.getSize()
    if W < GAME.minW or H < GAME.minH then
        term.redirect(term.native())
        error("Monitor is " .. W .. "x" .. H .. " characters, needs at least " .. GAME.minW .. "x" .. GAME.minH
            .. " (about " .. GAME.blocks .. " blocks wide x tall). Build it bigger =]")
    end
    math.randomseed(os.epoch("utc") % 2147483647)
    for _ = 1, 5 do math.random() end

    while true do
        idleScreen()
        snd("entity.villager.yes")
        while cardPresent() do
            local balance = updateLabel(userId)
            if balance < 1 then
                notEnough()
                break
            end
            local delta = GAME.round(userId, balance)
            if delta == nil then break end   -- card was taken before the round started
            if delta ~= 0 then changeBalance(delta, userId) end
        end
        userId = nil
    end
end

main()
