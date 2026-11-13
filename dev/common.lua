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
