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
