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

-- ================= CRAPS: PASS LINE or DON'T PASS, with optional free odds behind the point =================
-- Come-out roll: pass wins on 7/11, loses on 2/3/12. Don't pass is the opposite (12 pushes).
-- Any other number becomes the POINT: roll it again before a 7 and pass wins, roll a 7 first and don't pass wins.
-- After the point is set you may add a free odds bet (paid at true odds, no house edge).
GAME.name = "CRAPS"
-- settings: oddsMax = free odds bet allowed behind the point, as a multiple of the line bet (0 = no odds)
local S = loadSettings("craps", {oddsMax = 2, betLimit = 2000})
local BET_LIMIT = S.betLimit
local ODDS_MAX = math.floor(clamp(S.oddsMax, 0, 10))

local WAYS = {[2] = 1, [3] = 2, [4] = 3, [5] = 4, [6] = 5, [7] = 6, [8] = 5, [9] = 4, [10] = 3, [11] = 2, [12] = 1}

-- state after one roll: returns newPoint, outcome ("win"/"lose"/"push" from the line bet's point of view, nil = still rolling)
local function resolve(side, point, total)
    local pass = side == "pass"
    if point == nil then
        if total == 7 or total == 11 then return nil, pass and "win" or "lose" end
        if total == 2 or total == 3 then return nil, pass and "lose" or "win" end
        if total == 12 then return nil, pass and "lose" or "push" end
        return total, nil
    end
    if total == point then return point, pass and "win" or "lose" end
    if total == 7 then return point, pass and "lose" or "win" end
    return point, nil
end

-- chips won on an odds bet of `amount` (true odds; don't pass lays the odds)
local function oddsWin(side, point, amount)
    local strong = point == 4 or point == 10
    local mid = point == 5 or point == 9
    if side == "pass" then
        if strong then return amount * 2 end
        if mid then return math.floor(amount * 3 / 2) end
        return math.floor(amount * 6 / 5)
    end
    if strong then return math.floor(amount / 2) end
    if mid then return math.floor(amount * 2 / 3) end
    return math.floor(amount * 5 / 6)
end

-- net chips once the line bet is decided (point = the point that was set when it ended, nil for a come-out result)
local function settle(side, bet, point, outcome, oddsBet)
    local d = 0
    if outcome == "win" then d = bet elseif outcome == "lose" then d = -bet end
    if oddsBet > 0 and point ~= nil then
        if outcome == "win" then d = d + oddsWin(side, point, oddsBet)
        elseif outcome == "lose" then d = d - oddsBet end
    end
    return d
end

GAME.resolve, GAME.oddsWin, GAME.settle, GAME.ways = resolve, oddsWin, settle, WAYS

local PIPS = {
    [1] = {{2, 2}},
    [2] = {{1, 1}, {3, 3}},
    [3] = {{1, 1}, {2, 2}, {3, 3}},
    [4] = {{1, 1}, {3, 1}, {1, 3}, {3, 3}},
    [5] = {{1, 1}, {3, 1}, {2, 2}, {1, 3}, {3, 3}},
    [6] = {{1, 1}, {3, 1}, {1, 2}, {3, 2}, {1, 3}, {3, 3}},
}
local ROLL_NAMES = {[2] = "snake eyes", [3] = "ace deuce", [7] = "SEVEN", [11] = "yo-leven", [12] = "boxcars"}

local function drawDie(x, y, v)
    fill(x, y, x + 4, y + 2, colors.white)
    for _, p in ipairs(PIPS[v]) do fill(x + p[1], y + p[2] - 1, x + p[1], y + p[2] - 1, colors.black) end
end

local function diceX() return math.floor((W - 13) / 2) + 1 end

local function drawDice(d1, d2)
    drawDie(diceX(), 4, d1)
    drawDie(diceX() + 8, 4, d2)
end

local function pickSide()
    local ox = math.floor((W - 39) / 2)
    clear(colors.black)
    ctext(1, "CRAPS", colors.yellow, colors.black)
    ctext(2, "pick your bet", colors.lightGray, colors.black)
    local passB = button(ox + 2, 5, 17, 3, "PASS LINE", colors.blue)
    local dontB = button(ox + 21, 5, 17, 3, "DON'T PASS", colors.red)
    txt(ox + 2, 9, "wins on 7 or 11", colors.lightGray, colors.black)
    txt(ox + 2, 10, "loses on 2, 3, 12", colors.lightGray, colors.black)
    txt(ox + 21, 9, "wins on 2 or 3", colors.lightGray, colors.black)
    txt(ox + 21, 10, "loses on 7, 11", colors.lightGray, colors.black)
    txt(ox + 21, 11, "12 = push", colors.lightGray, colors.black)
    ctext(13, "any other number = the POINT", colors.white, colors.black)
    ctext(14, "pass wins if the point repeats", colors.gray, colors.black)
    ctext(15, "before a 7 (don't pass: reverse)", colors.gray, colors.black)
    ctext(H, "take your card to leave", colors.gray, colors.black)
    while true do
        local x, y = getTouch(true)
        if x == nil then return nil end
        if hit(passB, x, y) then snd("ui.button.click"); return "pass" end
        if hit(dontB, x, y) then snd("ui.button.click"); return "dont" end
    end
end

function GAME.round(uid, balance)
    local side = pickSide()
    if side == nil then return nil end
    local sideName = side == "pass" and "PASS LINE" or "DON'T PASS"
    local bet = betScreen(balance, BET_LIMIT, 1 + ODDS_MAX, "CRAPS", sideName .. " - free odds up to " .. ODDS_MAX .. "x")
    if bet == nil then return nil end

    local point, oddsBet = nil, 0
    local d1, d2 = 1, 1
    local msg, msgColor = "come out roll!", colors.white
    local total = nil

    local function drawTable()
        clear(colors.green)
        ctext(1, "CRAPS", colors.yellow, colors.green)
        local info = sideName .. "  bet " .. num(bet)
        if oddsBet > 0 then info = info .. "  odds " .. num(oddsBet) end
        ctext(2, info, colors.white, colors.green)
        drawDice(d1, d2)
        if total then
            ctext(8, total .. (ROLL_NAMES[total] and ("  " .. ROLL_NAMES[total]) or ""), colors.yellow, colors.green)
        end
        local puck = point and ("POINT: " .. point) or "come-out"
        local pw = 12
        local px = math.floor((W - pw) / 2) + 1
        fill(px, 10, px + pw - 1, 11, point and colors.white or colors.black)
        txt(px + math.floor((pw - #puck) / 2), 10, puck, point and colors.black or colors.white, point and colors.white or colors.black)
        ctext(13, msg, msgColor, colors.green)
    end

    local rollB, oddsB
    local function drawButtons()
        rollB = button(math.floor((W - 13) / 2) + 1, 15, 13, 3, "ROLL", colors.lime, colors.black)
        oddsB = nil
        if point and oddsBet == 0 and ODDS_MAX > 0 then
            oddsB = button(2, 15, 14, 3, "ODDS +" .. num(bet * ODDS_MAX), colors.blue)
        end
    end

    local function roll(animate)
        local a, b = math.random(1, 6), math.random(1, 6)
        if animate then
            for _ = 1, 7 do
                drawDice(math.random(1, 6), math.random(1, 6))
                snd("block.note_block.hat", 0.5, 0.8 + math.random() * 0.8)
                sleep(0.1)
            end
        end
        return a, b
    end

    local outcome
    while outcome == nil do
        drawTable()
        drawButtons()
        local x, y = getTouchTimeout(90)
        if x == nil then
            -- walked away: finish the hand quickly so the machine is free again
            while outcome == nil do
                d1, d2 = roll(false)
                total = d1 + d2
                point, outcome = resolve(side, point, total)
            end
        elseif oddsB and hit(oddsB, x, y) then
            oddsBet = bet * ODDS_MAX
            snd("ui.button.click")
            msg, msgColor = "odds bet placed", colors.yellow
        elseif hit(rollB, x, y) then
            snd("ui.button.click")
            d1, d2 = roll(true)
            total = d1 + d2
            local newPoint
            newPoint, outcome = resolve(side, point, total)
            if outcome == nil and point == nil then
                msg, msgColor = "point is " .. newPoint .. " - roll it again!", colors.white
                snd("block.note_block.bell")
            elseif outcome == nil then
                msg, msgColor = "roll again", colors.white
            end
            point = newPoint
        end
    end

    drawTable()
    -- odds only count if the line bet was decided in the point phase (point was set before this roll)
    local delta = settle(side, bet, point, outcome, oddsBet)
    if outcome == "win" then
        msg, msgColor = "YOU WIN +" .. num(delta) .. " chips", colors.lime
        snd("block.note_block.pling", 1, 2)
    elseif outcome == "push" then
        msg, msgColor = "push - bet returned", colors.yellow
    else
        msg, msgColor = "you lose " .. num(delta) .. " chips", colors.red
        snd("entity.villager.no", 0.6)
    end
    fill(1, 13, W, 13, colors.green)
    ctext(13, msg, msgColor, colors.green)
    pause(4)
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
