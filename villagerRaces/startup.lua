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

-- ================= VILLAGER RACES: six villagers race, bet on one to WIN or finish in the TOP 3 =================
-- Every race the villagers get a random "form" (win chance). Payout = RTP / chance, so long shots pay big.
GAME.name = "VILLAGER RACES"
-- settings: rtp = long-run return, weights = relative win chance of the six form slots (more even = fewer long shots)
local DEFAULT_WEIGHTS = {30, 24, 18, 14, 9, 5}
local S = loadSettings("villagerRaces", {rtp = 0.97, betLimit = 2000, weights = DEFAULT_WEIGHTS})
local BET_LIMIT = S.betLimit
local RTP = clamp(S.rtp, 0.5, 1.2)
local WEIGHTS = S.weights
local weightsOk = type(WEIGHTS) == "table" and #WEIGHTS == 6
if weightsOk then for _, w in ipairs(WEIGHTS) do if type(w) ~= "number" or w <= 0 then weightsOk = false end end end
if not weightsOk then
    warn("villagerRaces: weights needs exactly 6 positive numbers, using the defaults")
    WEIGHTS = DEFAULT_WEIGHTS
end

local VILLAGERS = {
    {name = "Farmer",    color = colors.brown,     fg = colors.white},
    {name = "Librarian", color = colors.white,     fg = colors.black},
    {name = "Cleric",    color = colors.purple,    fg = colors.white},
    {name = "Butcher",   color = colors.red,       fg = colors.white},
    {name = "Shepherd",  color = colors.lime,      fg = colors.black},
    {name = "Mason",     color = colors.lightBlue, fg = colors.black},
}
local ORDINAL = {"1st", "2nd", "3rd", "4th", "5th", "6th"}

-- chance of finishing 1st and of finishing in the top 3 for each weight (Plackett-Luce ordering)
local function placeProbs(ws)
    local S = 0
    for _, w in ipairs(ws) do S = S + w end
    local win, top3 = {}, {}
    for i = 1, #ws do win[i] = ws[i] / S; top3[i] = 0 end
    for a = 1, #ws do
        local pa = ws[a] / S
        for b = 1, #ws do
            if b ~= a then
                local pb = pa * ws[b] / (S - ws[a])
                for c = 1, #ws do
                    if c ~= a and c ~= b then
                        local pc = pb * ws[c] / (S - ws[a] - ws[b])
                        top3[a] = top3[a] + pc; top3[b] = top3[b] + pc; top3[c] = top3[c] + pc
                    end
                end
            end
        end
    end
    return win, top3
end

-- full finishing order (list of racer indexes, winner first), each pick weighted by speed
local function drawOrder(ws)
    local left, order = {}, {}
    for i = 1, #ws do left[i] = i end
    while #left > 0 do
        local total = 0
        for _, i in ipairs(left) do total = total + ws[i] end
        local r = math.random() * total
        local pickPos = #left
        for pos, i in ipairs(left) do
            r = r - ws[i]
            if r <= 0 then pickPos = pos break end
        end
        order[#order + 1] = table.remove(left, pickPos)
    end
    return order
end

-- total return multiple in hundredths (324 = 3.24x), never below 1.05x
local function multCents(p) return math.max(105, math.floor(RTP / p * 100)) end
local function fmtM(t) return string.format("%d.%02d", math.floor(t / 100), t % 100) end

GAME.placeProbs, GAME.drawOrder, GAME.multCents = placeProbs, drawOrder, multCents

local function newRace()
    local ws = {}
    for i, w in ipairs(WEIGHTS) do ws[i] = w end
    for i = #ws, 2, -1 do local j = math.random(1, i); ws[i], ws[j] = ws[j], ws[i] end
    local win, top3 = placeProbs(ws)
    local racers = {}
    for i, v in ipairs(VILLAGERS) do
        racers[i] = {name = v.name, color = v.color, fg = v.fg, w = ws[i], winP = win[i], top3P = top3[i],
                     winM = multCents(win[i]), placeM = multCents(top3[i])}
    end
    return racers
end

local function pickRacer(racers)
    local ox = math.floor((W - 39) / 2)
    clear(colors.black)
    ctext(1, "VILLAGER RACES", colors.yellow, colors.black)
    ctext(2, "pick a racer and a bet", colors.lightGray, colors.black)
    local boxes = {}
    for i, r in ipairs(racers) do
        local y = 3 + (i - 1) * 2
        fill(ox + 2, y, ox + 4, y + 1, r.color)
        txt(ox + 3, y, r.name:sub(1, 1), r.fg, r.color)
        txt(ox + 6, y, r.name, colors.white, colors.black)
        txt(ox + 6, y + 1, string.format("%d%% to win", math.floor(r.winP * 100 + 0.5)), colors.gray, colors.black)
        local wb = button(ox + 17, y, 10, 1, "WIN x" .. fmtM(r.winM), colors.green)
        local pb = button(ox + 28, y, 10, 1, "TOP3 x" .. fmtM(r.placeM), colors.blue)
        boxes[i] = {win = {x = wb.x, y = y, w = wb.w, h = 2}, place = {x = pb.x, y = y, w = pb.w, h = 2}}
    end
    ctext(15, "WIN: finish 1st   TOP3: top three", colors.gray, colors.black)
    ctext(H, "take your card to leave", colors.gray, colors.black)
    while true do
        local x, y = getTouch(true)
        if x == nil then return nil end
        for i = 1, #racers do
            if hit(boxes[i].win, x, y) then snd("ui.button.click"); return i, "win" end
            if hit(boxes[i].place, x, y) then snd("ui.button.click"); return i, "place" end
        end
    end
end

local function runRace(racers, order, pick)
    local ox = math.floor((W - 39) / 2)
    local trackX1, finishX = ox + 11, ox + 38
    local range = finishX - 3 - trackX1
    local function laneBg(i) return i % 2 == 1 and colors.gray or colors.black end
    local function laneY(i) return 3 + (i - 1) * 2 end

    clear(colors.black)
    ctext(1, "VILLAGER RACES", colors.yellow, colors.black)
    for i, r in ipairs(racers) do
        local y = laneY(i)
        fill(trackX1, y, finishX - 1, y + 1, laneBg(i))
        for row = 0, 1 do
            term.setBackgroundColor((i + row) % 2 == 0 and colors.white or colors.black)
            term.setCursorPos(finishX, y + row)
            term.write(" ")
        end
        txt(ox + 1, y, i == pick and ">" or " ", colors.yellow, colors.black)
        txt(ox + 2, y, r.name, colors.white, colors.black)
    end
    local function sprite(i, x)
        local r, y = racers[i], laneY(i)
        fill(x, y, x + 2, y + 1, r.color)
        txt(x + 1, y, r.name:sub(1, 1), r.fg, r.color)
    end
    local lastX = {}
    for i = 1, #racers do lastX[i] = trackX1; sprite(i, trackX1) end

    for _, c in ipairs({"3", "2", "1", "GO!"}) do
        fill(1, 16, W, 16, colors.black)
        ctext(16, c, colors.yellow, colors.black)
        snd("block.note_block.hat", 1, c == "GO!" and 2 or 1)
        sleep(0.6)
    end
    fill(1, 16, W, 16, colors.black)

    -- the finishing order is already decided; each racer's finish frame follows it, with wobbling speed in between
    local finish, t = {}, 40 + math.random(0, 6)
    for k = 1, #order do
        finish[order[k]] = t
        t = t + math.random(15, 35) / 10
    end
    local maxF = math.ceil(t)
    local freq, phase, lastProg = {}, {}, {}
    for i = 1, #racers do freq[i] = math.random(20, 40) / 10; phase[i] = math.random() * 6.28; lastProg[i] = 0 end

    for f = 1, maxF do
        for i = 1, #racers do
            local prog
            if f >= finish[i] then
                prog = 1
            else
                local u = f / finish[i]
                prog = u + 0.07 * math.sin(freq[i] * math.pi * u + phase[i]) * math.sin(math.pi * u)
            end
            prog = math.max(lastProg[i], math.min(1, prog))
            lastProg[i] = prog
            local x = trackX1 + math.floor(prog * range)   -- only reaches the last column when the racer has finished
            if x ~= lastX[i] then
                fill(lastX[i], laneY(i), lastX[i] + 2, laneY(i) + 1, laneBg(i))
                sprite(i, x)
                lastX[i] = x
            end
        end
        if f % 5 == 0 then snd("entity.villager.ambient", 0.5, 0.8 + math.random() * 0.8) end
        sleep(0.12)
    end
    for k, idx in ipairs(order) do
        txt(ox + 1, laneY(idx), tostring(k), k == 1 and colors.yellow or colors.lightGray, colors.black)
    end
end

function GAME.round(uid, balance)
    local racers = newRace()
    local pick, kind = pickRacer(racers)
    if pick == nil then return nil end
    local r = racers[pick]
    local mt = kind == "win" and r.winM or r.placeM
    local bet = betScreen(balance, BET_LIMIT, 1, "VILLAGER RACES",
        r.name .. (kind == "win" and " to WIN" or " in TOP 3") .. " - pays x" .. fmtM(mt))
    if bet == nil then return nil end

    local ws = {}
    for i, rc in ipairs(racers) do ws[i] = rc.w end
    local order = drawOrder(ws)
    runRace(racers, order, pick)

    local place = 0
    for k, idx in ipairs(order) do if idx == pick then place = k end end
    local won = (kind == "win" and place == 1) or (kind == "place" and place <= 3)
    local delta = won and (math.floor(bet * mt / 100) - bet) or -bet

    ctext(15, racers[order[1]].name .. " wins!", colors.yellow, colors.black)
    ctext(16, "your " .. r.name .. " finished " .. ORDINAL[place], colors.white, colors.black)
    if won then
        ctext(17, "YOU WIN +" .. num(delta) .. " chips", colors.lime, colors.black)
        snd("entity.villager.yes"); snd("block.note_block.pling", 1, 2)
    else
        ctext(17, "you lose -" .. num(bet) .. " chips", colors.red, colors.black)
        snd("entity.villager.no")
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
