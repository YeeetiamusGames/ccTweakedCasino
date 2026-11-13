
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
