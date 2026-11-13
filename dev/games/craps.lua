
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
