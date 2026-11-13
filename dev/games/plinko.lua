
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
