
-- ================= SLOTS: 3 reels, center line pays (return multiples include the stake) =================
-- The result is picked first from a table built from your settings, then reels that show it are drawn:
--   rtp             long-run return per chip (0.97 = 97%)
--   hitFrequency    share of spins that win MORE than the bet back
--   pushFrequency   share of spins that give the bet back (shown as one cherry)
-- Everything else loses. See casinoSettings.lua.
GAME.name = "SLOTS"
local S = loadSettings("slots", {rtp = 0.97, hitFrequency = 0.35, pushFrequency = 0.10, betLimit = 5000})
local BET_LIMIT = S.betLimit

local SYM = {
    {name = "DIAMOND", pay = 150, bg = colors.cyan,   fg = colors.white},
    {name = "SEVEN",   pay = 60,  bg = colors.white,  fg = colors.red},
    {name = "BAR",     pay = 25,  bg = colors.gray,   fg = colors.white},
    {name = "BELL",    pay = 12,  bg = colors.yellow, fg = colors.black},
    {name = "ORANGE",  pay = 8,   bg = colors.orange, fg = colors.white},
    {name = "LEMON",   pay = 5,   bg = colors.lime,   fg = colors.black},
    {name = "CHERRY",  pay = 4,   bg = colors.red,    fg = colors.white},
}
local CHERRY = 7
local WIN_RETURNS = {2, 4, 5, 8, 12, 25, 60, 150}                 -- 2 = two cherries, the rest = three of a symbol
-- the three big prizes keep fixed odds so they stay reachable at any setting; the small wins are fitted around them
local BIG_PRIZES = {{ret = 150, p = 1 / 50000}, {ret = 60, p = 1 / 10000}, {ret = 25, p = 1 / 1500}}
local SMALL_RETURNS = {2, 4, 5, 8, 12}
local WIN_SYMBOL = {[4] = 7, [5] = 6, [8] = 5, [12] = 4, [25] = 3, [60] = 2, [150] = 1}

-- total returned multiple of the bet for a center line a,b,c (0 = lose, 1 = bet back)
function GAME.eval(a, b, c)
    if a == b and b == c then return SYM[a].pay end
    local n = 0
    for _, s in ipairs({a, b, c}) do if s == CHERRY then n = n + 1 end end
    if n == 2 then return 2 elseif n == 1 then return 1 end
    return 0
end

-- outcome table {ret, p}: the small wins use weights ~ ret^-k with k found by bisection so the mean win matches the settings
local function slotTable(rtp, hit, push)
    local notes = {}
    rtp = clamp(rtp, 0.5, 1.2)
    push = clamp(push, 0, 0.3)
    local net = rtp - push
    if net < 0.2 then
        push = math.max(0, rtp - 0.2); net = rtp - push
        notes[#notes + 1] = "slots: pushFrequency lowered to " .. string.format("%.2f", push) .. " to fit the return"
    end
    local bigP, bigRet = 0, 0
    for _, b in ipairs(BIG_PRIZES) do bigP = bigP + b.p; bigRet = bigRet + b.p * b.ret end
    local net2 = net - bigRet
    local h = clamp(hit, bigP + net2 / 11, bigP + net2 / 2.05)
    if math.abs(h - hit) > 1e-9 then
        notes[#notes + 1] = string.format("slots: hitFrequency %.3f is not possible with rtp %.2f, using %.3f", hit, rtp, h)
    end
    local M = net2 / (h - bigP)
    local function mean(k)
        local z, m = 0, 0
        for _, r in ipairs(SMALL_RETURNS) do local w = r ^ -k; z = z + w; m = m + w * r end
        return m / z
    end
    local lo, hi = -4, 40
    for _ = 1, 100 do
        local mid = (lo + hi) / 2
        if mean(mid) > M then lo = mid else hi = mid end
    end
    local k = (lo + hi) / 2
    local z = 0
    for _, r in ipairs(SMALL_RETURNS) do z = z + r ^ -k end
    local t = {notes = notes, hit = h, push = push, rtp = rtp, list = {}}
    for _, r in ipairs(SMALL_RETURNS) do t.list[#t.list + 1] = {ret = r, p = (h - bigP) * r ^ -k / z} end
    for _, b in ipairs(BIG_PRIZES) do t.list[#t.list + 1] = {ret = b.ret, p = b.p} end
    t.list[#t.list + 1] = {ret = 1, p = push}
    t.list[#t.list + 1] = {ret = 0, p = 1 - h - push}
    return t
end

local function pickOutcome(t)
    local r, acc = math.random(), 0
    for _, o in ipairs(t.list) do
        acc = acc + o.p
        if r <= acc then return o.ret end
    end
    return 0
end

-- three center symbols that show exactly `ret`
local function makeTriple(ret)
    local function plain() return math.random(1, 6) end   -- any symbol but the cherry
    if ret == 0 then
        while true do
            local a, b, c = plain(), plain(), plain()
            if not (a == b and b == c) then return a, b, c end
        end
    elseif ret == 1 then
        local t = {plain(), plain(), plain()}
        t[math.random(1, 3)] = CHERRY
        return t[1], t[2], t[3]
    elseif ret == 2 then
        local t = {CHERRY, CHERRY, CHERRY}
        t[math.random(1, 3)] = plain()
        return t[1], t[2], t[3]
    end
    local s = WIN_SYMBOL[ret]
    return s, s, s
end

local TABLE = slotTable(S.rtp, S.hitFrequency, S.pushFrequency)
for _, n in ipairs(TABLE.notes) do warn(n) end

GAME.slotTable, GAME.pickOutcome, GAME.makeTriple, GAME.TABLE = slotTable, pickOutcome, makeTriple, TABLE

local CELL_W, STRIDE, TOP = 9, 3, 3

local function reelX() return math.floor((W - (3 * CELL_W + 2)) / 2) + 1 end

local function drawReel(i, syms)
    local x = reelX() + (i - 1) * (CELL_W + 1)
    for r = 1, 3 do
        local s = SYM[syms[r]]
        local y = TOP + (r - 1) * STRIDE
        fill(x, y, x + CELL_W - 1, y + 1, s.bg)
        txt(x + math.floor((CELL_W - #s.name) / 2), y, s.name, s.fg, s.bg)
        fill(x, y + 2, x + CELL_W - 1, y + 2, colors.black)
    end
end

local function drawMachine(reels)
    clear(colors.black)
    for i = 1, 3 do drawReel(i, reels[i]) end
    local cy = TOP + STRIDE
    txt(reelX() - 2, cy, ">", colors.yellow, colors.black)
    txt(reelX() + 3 * CELL_W + 2, cy, "<", colors.yellow, colors.black)
end

local function showPays()
    clear(colors.black)
    ctext(1, "PAYTABLE (x your bet back)", colors.yellow, colors.black)
    local y = 3
    for i = 1, #SYM do
        local s = SYM[i]
        txt(math.floor(W / 2) - 12, y, "3x " .. s.name, s.bg == colors.gray and colors.lightGray or s.bg, colors.black)
        txt(math.floor(W / 2) + 6, y, "x" .. s.pay, colors.white, colors.black)
        y = y + 1
    end
    txt(math.floor(W / 2) - 12, y, "2 cherries", colors.red, colors.black)
    txt(math.floor(W / 2) + 6, y, "x2", colors.white, colors.black)
    txt(math.floor(W / 2) - 12, y + 1, "1 cherry", colors.red, colors.black)
    txt(math.floor(W / 2) + 6, y + 1, "bet back", colors.white, colors.black)
    ctext(H - 1, "touch to close", colors.gray, colors.black)
    getTouch(false)
end

local function spin(reels, mid)
    local stopAt = {12, 20, 28}
    local final = {}
    for i = 1, 3 do final[i] = {math.random(1, 7), mid[i], math.random(1, 7)} end
    for step = 1, stopAt[3] do
        for i = 1, 3 do
            if step <= stopAt[i] then
                if step == stopAt[i] then
                    reels[i] = final[i]
                    snd("block.dispenser.launch", 0.6, 1.2)
                else
                    reels[i] = {math.random(1, 7), reels[i][1], reels[i][2]}
                end
                drawReel(i, reels[i])
            end
        end
        if step % 2 == 0 then snd("block.note_block.hat", 0.4, 1 + step / 40) end
        sleep(0.1 + math.max(0, step - 20) * 0.01)
    end
end

function GAME.round(uid, balance)
    local bet = betScreen(balance, BET_LIMIT, 1, "SLOTS", "center line pays - 3 of a kind or cherries")
    if bet == nil then return nil end
    local function rnd() return math.random(1, 7) end
    local reels = {{rnd(), rnd(), rnd()}, {rnd(), rnd(), rnd()}, {rnd(), rnd(), rnd()}}
    local msg, msgColor = "good luck!", colors.white
    local spinB, betB, paysB
    local bal = balance

    while true do
        if bal < bet then return 0 end
        drawMachine(reels)
        ctext(2, "bet " .. num(bet) .. "   balance " .. num(bal), colors.lightGray, colors.black)
        ctext(13, msg, msgColor, colors.black)
        betB = button(2, 15, 8, 3, "BET", colors.gray)
        spinB = button(math.floor((W - 13) / 2) + 1, 15, 13, 3, "SPIN", colors.lime, colors.black)
        paysB = button(W - 9, 15, 8, 3, "PAYS", colors.gray)

        local x, y = getTouch(true)
        if x == nil then return 0 end
        if hit(betB, x, y) then
            return 0
        elseif hit(paysB, x, y) then
            showPays()
        elseif hit(spinB, x, y) then
            snd("ui.button.click")
            local r = pickOutcome(TABLE)
            local a, b, c = makeTriple(r)
            spin(reels, {a, b, c})
            local delta = bet * (r - 1)
            bal = changeBalance(delta, uid)
            if r > 1 then
                msg = "WIN! +" .. num(delta) .. " chips"
                msgColor = colors.lime
                snd(r >= 12 and "entity.player.levelup" or "block.note_block.pling", 1, r >= 12 and 1 or 2)
            elseif r == 1 then
                msg, msgColor = "cherry - bet back", colors.yellow
                snd("entity.experience_orb.pickup")
            else
                msg, msgColor = "no luck  -" .. num(bet), colors.red
                snd("entity.villager.no", 0.6)
            end
        end
    end
end
