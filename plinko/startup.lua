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

-- ================= PLINKO: drop a ball through 8 rows of pegs into a multiplier bin =================
-- The bin is picked first (binomial, like a real board) and the animation follows a random path ending there.
GAME.name = "PLINKO"
-- settings: rtp = long-run return, hitFrequency = share of balls that pay 1x or more (0.289 = a real unweighted board)
local S = loadSettings("plinko", {rtp = 0.97, hitFrequency = 0.40, betLimit = 2000})
local BET_LIMIT = S.betLimit
local ROWS = 8

-- base multipliers for bins 0..8 (symmetric); the winning bins are scaled to hit your settings
local BASE = {
    low    = {5.6, 2.1, 1.1, 0.9, 0.5, 0.9, 1.1, 2.1, 5.6},
    medium = {13, 3, 1.3, 0.7, 0.4, 0.7, 1.3, 3, 13},
    high   = {29, 4, 1.5, 0.3, 0.2, 0.3, 1.5, 4, 29},
}
local RISKS = {
    {id = "low", label = "LOW", bg = colors.green},
    {id = "medium", label = "MEDIUM", bg = colors.blue},
    {id = "high", label = "HIGH", bg = colors.red},
}

local function binomProbs(n)
    local p, total = {}, 2 ^ n
    for j = 0, n do
        local c = 1
        for k = 1, j do c = c * (n - k + 1) / k end
        p[j + 1] = c / total
    end
    return p
end
local BIN = binomProbs(ROWS)

-- plan for one risk level: probability of each bin and payout (in hundredths of the bet) for each bin.
-- "winning" bins (base above 1.05x) share probability `hit`, the rest share 1-hit, both in proportion to a real board.
local function buildPlan(risk, rtp, hit)
    local notes = {}
    rtp = clamp(rtp, 0.5, 1.2)
    local base = BASE[risk]
    local win, bw, bl = {}, 0, 0
    for j = 1, ROWS + 1 do
        win[j] = base[j] > 1.05
        if win[j] then bw = bw + BIN[j] else bl = bl + BIN[j] end
    end
    local h = clamp(hit, 0.05, 0.85)
    if math.abs(h - hit) > 1e-9 then notes[#notes + 1] = string.format("plinko: hitFrequency %.2f out of range, using %.2f", hit, h) end
    local p = {}
    for j = 1, ROWS + 1 do p[j] = win[j] and BIN[j] * h / bw or BIN[j] * (1 - h) / bl end
    local wBase, lBase, minW = 0, 0, 1e9
    for j = 1, ROWS + 1 do
        if win[j] then wBase = wBase + p[j] * base[j]; minW = math.min(minW, base[j]) else lBase = lBase + p[j] * base[j] end
    end
    -- winning bins are scaled by s, or (when that would push them under 1x) flattened to base^g, then the losing bins shrink if still needed
    local s, g, t = (rtp - lBase) / wBase, 1, 1
    if s * minW >= 1 then
        g = 1
    else
        s = 1
        local target = rtp - lBase
        if target >= h then                       -- flatten the win bins: find g in [0,1] with sum(p * base^g) = target
            local lo, hi = 0, 1
            for _ = 1, 60 do
                local mid, sum = (lo + hi) / 2, 0
                for j = 1, ROWS + 1 do if win[j] then sum = sum + p[j] * base[j] ^ mid end end
                if sum > target then hi = mid else lo = mid end
            end
            g = (lo + hi) / 2
        else                                      -- all winning bins at exactly 1x, shrink the losing bins
            g = 0
            t = math.max(0, (rtp - h) / lBase)
        end
    end
    local cents, got = {}, 0
    for j = 1, ROWS + 1 do
        cents[j] = math.floor((win[j] and s * base[j] ^ g or t * base[j]) * 100 + 0.5)
        got = got + p[j] * cents[j] / 100
    end
    if math.abs(got - rtp) > 0.01 then
        notes[#notes + 1] = string.format("plinko %s: rtp %.2f not reachable with hitFrequency %.2f, using %.3f", risk, rtp, h, got)
    end
    return {cents = cents, probs = p, hit = h, rtp = got, notes = notes}
end

local PLANS = {}
for _, r in ipairs(RISKS) do
    PLANS[r.id] = buildPlan(r.id, S.rtp, S.hitFrequency)
    for _, n in ipairs(PLANS[r.id].notes) do warn(n) end
end

local function pickBin(probs)
    local r, acc = math.random(), 0
    for j = 1, ROWS + 1 do
        acc = acc + probs[j]
        if r <= acc then return j - 1 end
    end
    return ROWS
end

-- list of ROWS steps (1 = right, 0 = left) with exactly `bin` rights in random order
local function makePath(bin)
    local path = {}
    for i = 1, ROWS do path[i] = i <= bin and 1 or 0 end
    for i = ROWS, 2, -1 do
        local j = math.random(1, i)
        path[i], path[j] = path[j], path[i]
    end
    return path
end

GAME.buildPlan, GAME.pickBin, GAME.makePath, GAME.PLANS, GAME.binProbs, GAME.rows = buildPlan, pickBin, makePath, PLANS, BIN, ROWS

local PY0 = 4   -- y of the first peg row

local function cx() return math.floor(W / 2) + 1 end
local function binX(j) return cx() + (2 * j - ROWS) * 2 end

local function binLabel(c)
    local m = c / 100
    if m >= 10 then return string.format("%d", math.floor(m)) end
    return string.format("%.1f", m)
end

local function binColor(c)
    if c < 100 then return colors.gray, colors.white end
    if c < 200 then return colors.yellow, colors.black end
    if c < 500 then return colors.orange, colors.black end
    return colors.red, colors.white
end

local function drawBin(cents, j, flash)
    local c = cents[j + 1]
    local bg, fg = binColor(c)
    if flash then bg, fg = colors.white, colors.black end
    local x, y = binX(j), PY0 + ROWS + 1
    fill(x - 1, y, x + 1, y + 1, bg)
    txt(x - 1, y, binLabel(c), fg, bg)
end

local function drawBoard(cents)
    clear(colors.black)
    for i = 1, ROWS do
        for k = 0, i - 1 do
            txt(cx() + (2 * k - (i - 1)) * 2, PY0 + i - 1, ".", colors.lightGray, colors.black)
        end
    end
    for j = 0, ROWS do drawBin(cents, j) end
end

local function dropBall(cents, bin)
    local path = makePath(bin)
    local function ball(x, y) fill(x, y, x, y, colors.yellow) end
    ball(cx(), PY0 - 1)
    sleep(0.2)
    txt(cx(), PY0 - 1, " ", colors.white, colors.black)
    local j = 0
    for i = 1, ROWS do
        local x, y = cx() + (2 * j - (i - 1)) * 2, PY0 + i - 1
        ball(x, y)
        snd("block.note_block.hat", 0.5, 0.8 + 0.5 * math.random())
        sleep(0.2)
        txt(x, y, ".", colors.lightGray, colors.black)
        j = j + path[i]
    end
    ball(binX(j), PY0 + ROWS)
    for _ = 1, 3 do
        drawBin(cents, j, true); sleep(0.15)
        drawBin(cents, j, false); sleep(0.15)
    end
    txt(binX(j), PY0 + ROWS, " ", colors.white, colors.black)
    return j
end

local function pickRisk()
    local ox = math.floor((W - 39) / 2)
    clear(colors.black)
    ctext(1, "PLINKO", colors.yellow, colors.black)
    ctext(2, "pick a risk level", colors.lightGray, colors.black)
    local btns = {}
    for i, r in ipairs(RISKS) do
        local y = 4 + (i - 1) * 4
        btns[i] = button(ox + 2, y, 13, 3, r.label, r.bg)
        local plan = PLANS[r.id]
        local top = 0
        for _, c in ipairs(plan.cents) do top = math.max(top, c) end
        txt(ox + 17, y, string.format("top prize x%.1f", top / 100), colors.white, colors.black)
        txt(ox + 17, y + 1, string.format("%d%% of balls pay 1x+", math.floor(plan.hit * 100 + 0.5)), colors.lightGray, colors.black)
    end
    ctext(H, "take your card to leave", colors.gray, colors.black)
    while true do
        local x, y = getTouch(true)
        if x == nil then return nil end
        for i, r in ipairs(RISKS) do
            if hit(btns[i], x, y) then snd("ui.button.click"); return r end
        end
    end
end

local lastRisk, lastUser = nil, nil

function GAME.round(uid, balance)
    if lastUser ~= uid then lastUser, lastRisk = uid, nil end
    if lastRisk == nil then
        lastRisk = pickRisk()
        if lastRisk == nil then return nil end
    end
    local bet = betScreen(balance, BET_LIMIT, 1, "PLINKO", lastRisk.label .. " risk")
    if bet == nil then return nil end

    local plan = PLANS[lastRisk.id]
    local cents = plan.cents
    local bal = balance
    local msg, msgColor = "drop the ball!", colors.white
    while true do
        if bal < bet then return 0 end
        drawBoard(cents)
        ctext(2, "bet " .. num(bet) .. "  " .. lastRisk.label .. "  balance " .. num(bal), colors.lightGray, colors.black)
        ctext(15, msg, msgColor, colors.black)
        local betB = button(2, 16, 8, 3, "BET", colors.gray)
        local dropB = button(math.floor((W - 13) / 2) + 1, 16, 13, 3, "DROP", colors.lime, colors.black)
        local riskB = button(W - 9, 16, 8, 3, "RISK", colors.gray)

        local x, y = getTouch(true)
        if x == nil then lastRisk = nil return 0 end
        if hit(betB, x, y) then
            return 0
        elseif hit(riskB, x, y) then
            lastRisk = nil
            return 0
        elseif hit(dropB, x, y) then
            snd("ui.button.click")
            local bin = pickBin(plan.probs)
            dropBall(cents, bin)
            local m = cents[bin + 1]
            local delta = math.floor(bet * m / 100) - bet
            bal = changeBalance(delta, uid)
            msg = string.format("x%.2f  %s%d chips", m / 100, delta >= 0 and "+" or "", delta)
            if delta > 0 then
                msgColor = colors.lime
                snd(m >= 500 and "entity.player.levelup" or "block.note_block.pling", 1, 2)
            elseif delta == 0 then
                msgColor = colors.yellow
            else
                msgColor = colors.red
                snd("entity.villager.no", 0.5)
            end
        end
    end
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
