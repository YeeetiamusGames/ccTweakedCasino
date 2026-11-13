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

-- ================= BACCARAT: bet on PLAYER, BANKER or TIE (8 decks, standard third card rules) =================
-- Card values: ace 1, 2-9 face value, 10/J/Q/K 0; hand = total mod 10. Natural (8 or 9) ends the hand.
GAME.name = "BACCARAT"
-- settings: bankerCommission = percent taken from banker wins (casinos: 5), tiePays = tie bet pays N:1 (casinos: 8)
local S = loadSettings("baccarat", {bankerCommission = 4, tiePays = 8, betLimit = 5000})
local BET_LIMIT = S.betLimit
local DECKS = 8
local BANKER_COMMISSION = clamp(S.bankerCommission, 0, 50)
local TIE_PAYS = clamp(S.tiePays, 1, 50)
local shoe = {}

local function cardValue(c) return c.r >= 10 and 0 or c.r end

local function total(hand)
    local t = 0
    for _, c in ipairs(hand) do t = t + cardValue(c) end
    return t % 10
end

-- does the banker take a third card? pThird = value of the player's third card, nil if the player stood
local function bankerDraws(bt, pThird)
    if pThird == nil then return bt <= 5 end
    if bt <= 2 then return true end
    if bt == 3 then return pThird ~= 8 end
    if bt == 4 then return pThird >= 2 and pThird <= 7 end
    if bt == 5 then return pThird >= 4 and pThird <= 7 end
    if bt == 6 then return pThird == 6 or pThird == 7 end
    return false
end

-- plays one full hand. draw() returns the next card, onCard(who, hand) is called after every card dealt.
local function playHand(draw, onCard)
    local p, b = {}, {}
    local function give(hand, who)
        hand[#hand + 1] = draw()
        if onCard then onCard(who, hand) end
        return hand[#hand]
    end
    give(p, "player"); give(b, "banker"); give(p, "player"); give(b, "banker")
    if total(p) < 8 and total(b) < 8 then
        local pThird
        if total(p) <= 5 then pThird = cardValue(give(p, "player")) end
        if bankerDraws(total(b), pThird) then give(b, "banker") end
    end
    local pt, bt = total(p), total(b)
    return p, b, (pt > bt and "player") or (bt > pt and "banker") or "tie"
end

-- net chips for a bet on `side` when the hand ends in `outcome`
local function payout(side, outcome, bet)
    if outcome == "tie" then
        return side == "tie" and bet * TIE_PAYS or 0   -- player/banker bets push on a tie
    end
    if side == outcome then
        if side == "banker" then return math.floor(bet * (100 - BANKER_COMMISSION) / 100) end
        return bet
    end
    return -bet
end

GAME.cardValue, GAME.total, GAME.bankerDraws, GAME.playHand, GAME.payout, GAME.newShoe = cardValue, total, bankerDraws, playHand, payout, newShoe

local function draw()
    if #shoe < 20 then shoe = newShoe(DECKS) end
    return table.remove(shoe)
end

local function pickSide()
    local ox = math.floor((W - 39) / 2)
    clear(colors.black)
    ctext(1, "BACCARAT", colors.yellow, colors.black)
    ctext(2, "pick a side", colors.lightGray, colors.black)
    local sides = {
        {id = "player", label = "PLAYER", pays = "1:1", bg = colors.blue},
        {id = "banker", label = "BANKER", pays = string.format("%g:1", (100 - BANKER_COMMISSION) / 100), bg = colors.red},
        {id = "tie", label = "TIE", pays = TIE_PAYS .. ":1", bg = colors.green},
    }
    for i, s in ipairs(sides) do
        s.btn = button(ox + 2 + (i - 1) * 13, 6, 11, 3, s.label, s.bg)
        ctext(10, "", colors.black, colors.black)
        txt(s.btn.x + math.floor((11 - #s.pays - 6) / 2), 10, "pays " .. s.pays, colors.lightGray, colors.black)
    end
    ctext(13, "tie returns player/banker bets", colors.gray, colors.black)
    ctext(H, "take your card to leave", colors.gray, colors.black)
    while true do
        local x, y = getTouch(true)
        if x == nil then return nil end
        for _, s in ipairs(sides) do
            if hit(s.btn, x, y) then snd("ui.button.click"); return s end
        end
    end
end

local function drawHands(p, b, side)
    local function row(y, hand, name, who)
        fill(1, y, W, y + 4, colors.green)
        for i, c in ipairs(hand) do drawCard(2 + (i - 1) * 7, y, c) end
        txt(24, y + 1, name .. (side == who and " *" or ""), colors.white, colors.green)
        if #hand > 0 then txt(24, y + 3, "total " .. total(hand), colors.yellow, colors.green) end
    end
    row(2, p, "PLAYER", "player")
    row(9, b, "BANKER", "banker")
end

function GAME.round(uid, balance)
    local s = pickSide()
    if s == nil then return nil end
    local bet = betScreen(balance, BET_LIMIT, 1, "BACCARAT", "bet on " .. s.label .. " - pays " .. s.pays)
    if bet == nil then return nil end

    clear(colors.green)
    ctext(1, "bet " .. num(bet) .. " on " .. s.label, colors.white, colors.green)
    local emptyP, emptyB = {}, {}
    drawHands(emptyP, emptyB, s.id)
    local ph, bh
    local function onCard(who, hand)
        snd("block.dispenser.launch", 0.7)
        if who == "player" then ph = hand else bh = hand end
        drawHands(ph or emptyP, bh or emptyB, s.id)
        sleep(0.8)
    end
    local p, b, outcome = playHand(draw, onCard)

    local delta = payout(s.id, outcome, bet)
    local pt, bt = total(p), total(b)
    local head = outcome == "tie" and ("TIE  " .. pt .. " - " .. bt) or (outcome:upper() .. " WINS  " .. math.max(pt, bt) .. " - " .. math.min(pt, bt))
    fill(1, 15, W, 18, colors.black)
    ctext(15, head, colors.yellow, colors.black)
    if delta > 0 then
        ctext(16, "YOU WIN +" .. num(delta) .. " chips", colors.lime, colors.black)
        snd("block.note_block.pling", 1, 2)
    elseif delta == 0 then
        ctext(16, "bet returned", colors.lightGray, colors.black)
    else
        ctext(16, "you lose -" .. num(bet) .. " chips", colors.red, colors.black)
        snd("entity.villager.no", 0.6)
    end
    pause(5)
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
