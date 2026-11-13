
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
